use anyhow::anyhow;
use async_std::future;
use async_std::task::block_on;
use chrono::Local;
use godot::prelude::*;
use keys::ssh_key::private::{Ed25519Keypair, KeypairData, RsaKeypair};
use keys::ssh_key::rand_core::OsRng;
use keys::{PrivateKey, PrivateKeyWithHashAlg};
use russh::client::Handle;
use russh::*;
use std::io;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

// TODO make blocking an option
// because right now we just log the received data,
// however in the future something may depend on that data
// so to allow something to parse that, we should add an option to block the client
// but that means for every command there needs to be a SSHClient spawned
// or we could implement session management and allow opening multiple sessions per SSHClient

#[derive(thiserror::Error, Debug)]
#[non_exhaustive]
pub enum SSHError {
    #[error("Server check failed")]
    ServerCheckFailed,
    #[error("SSH error occurred: {0}")]
    SshError(#[from] russh::Error),
    #[error("Send error")]
    SendError(#[from] russh::SendError),
    #[error("Agent auth error")]
    AgentAuthError(#[from] russh::AgentAuthError),
    #[error("I/O error")]
    IoError(#[from] io::Error),
}

#[derive(Clone)]
#[allow(dead_code)]
pub enum ServerCheckMethod {
    NoCheck,
    /// base64 encoded key without the type prefix or hostname suffix (type is already encoded)
    DefaultKnownHostsFile,
    PublicKey(String),
    PublicKeyFile(String),
    KnownHostsFile(String),
}

#[derive(Clone, PartialEq)]
#[allow(dead_code)]
enum AuthMethod {
    None,
    Password(String),
    PrivateKey {
        /// entire contents of private key file
        key_data: String,
        key_pass: Option<String>,
    },
    PrivateKeyFile {
        key_file_path: PathBuf,
        key_pass: Option<String>,
    },
    PublicKeyFile {
        key_file_path: PathBuf,
    },
}

struct Client {
    debug: bool,
    ip: String,
    port: u16,
    server_check: ServerCheckMethod,
}

impl client::Handler for Client {
    type Error = SSHError;

    async fn check_server_key(
        &mut self,
        server_public_key: &russh::keys::PublicKey,
    ) -> Result<bool, Self::Error> {
        match &self.server_check {
            ServerCheckMethod::NoCheck => Ok(true),
            ServerCheckMethod::PublicKey(key) => {
                let pk = russh::keys::parse_public_key_base64(key)
                    .map_err(|_| SSHError::ServerCheckFailed)?;

                Ok(pk == *server_public_key)
            }
            ServerCheckMethod::PublicKeyFile(key_file_name) => {
                let pk = russh::keys::load_public_key(key_file_name)
                    .map_err(|_| SSHError::ServerCheckFailed)?;

                Ok(pk == *server_public_key)
            }
            ServerCheckMethod::KnownHostsFile(known_hosts_path) => {
                let result = russh::keys::check_known_hosts_path(
                    &self.ip,
                    self.port,
                    server_public_key,
                    known_hosts_path,
                )
                .map_err(|_| SSHError::ServerCheckFailed)?;

                Ok(result)
            }
            ServerCheckMethod::DefaultKnownHostsFile => {
                let result = russh::keys::check_known_hosts(&self.ip, self.port, server_public_key)
                    .map_err(|_| SSHError::ServerCheckFailed)?;

                Ok(result)
            }
        }
    }

    async fn data(
        &mut self,
        channel: ChannelId,
        data: &[u8],
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        if self.debug {
            godot_print!(
                "{}: SSH STDOUT on {}:{}:{:?}: {}",
                Local::now().format("%Y-%m-%dT%H:%M:%S"),
                self.ip,
                self.port,
                channel,
                String::from_utf8_lossy(data)
            );
        }
        Ok(())
    }

    async fn extended_data(
        &mut self,
        channel: ChannelId,
        ext: u32,
        data: &[u8],
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        if ext == 1 && self.debug {
            godot_print_rich!(
                "[color=yellow]{}: SSH STDERR on {}:{}:{:?}: {}[color=white][/color]",
                Local::now().format("%Y-%m-%dT%H:%M:%S"),
                self.ip,
                self.port,
                channel,
                String::from_utf8_lossy(data)
            );
        }
        Ok(())
    }

    async fn exit_status(
        &mut self,
        channel: ChannelId,
        exit_status: u32,
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        if self.debug {
            let color = if exit_status != 0 { "red" } else { "white" };
            godot_print_rich!(
                "[color={}]{}: SSH on {}:{}:{:?}: exited with code {}[color=white][/color]",
                color,
                Local::now().format("%Y-%m-%dT%H:%M:%S"),
                self.ip,
                self.port,
                channel,
                exit_status
            );
        }
        Ok(())
    }
}

struct InternalSSHClient {
    debug: bool,
    session: Option<Handle<Client>>,
    auth_method: AuthMethod,
    server_check: ServerCheckMethod,
}

impl InternalSSHClient {
    fn add_key_to_server(
        &mut self,
        password: String,
        ip: &String,
        user: &String,
        port: u16,
    ) -> anyhow::Result<()> {
        let passphrase: Option<String>;

        let mut private_key = match self.auth_method.clone() {
            AuthMethod::PrivateKeyFile {
                key_file_path,
                key_pass,
            } => {
                passphrase = key_pass;
                match PrivateKey::read_openssh_file(&key_file_path) {
                    Ok(key_data) => key_data,
                    Err(e) => {
                        anyhow::bail!("Failed to read key at {}: {}", key_file_path.display(), e)
                    }
                }
            }
            AuthMethod::PrivateKey { key_data, key_pass } => {
                passphrase = key_pass;
                match PrivateKey::from_openssh(key_data) {
                    Ok(private_key) => private_key,
                    Err(e) => anyhow::bail!("Failed to parse private key: {}", e),
                }
            }
            // Is only possible if self.auth_method is of type private key
            _ => anyhow::bail!("Wrong auth method set"),
        };
        if private_key.is_encrypted() {
            private_key = if let Some(passphrase) = passphrase {
                match private_key.decrypt(passphrase) {
                    Ok(private_key) => private_key,
                    Err(e) => anyhow::bail!("Failed to decrypt private key: {}", e),
                }
            } else {
                anyhow::bail!("Key is encrypted but no password provided.");
            };
        }

        let pub_key = match private_key.public_key().to_openssh() {
            Ok(pub_key) => pub_key,
            Err(e) => anyhow::bail!("Failed to serialize public key: {}", e),
        };

        // Temporarily set auth method to password to allow login
        let auth_method_store = self.auth_method.clone();
        self.auth_method = AuthMethod::Password(password);

        if self.debug {
            godot_print!("Copying public key to SSH server");
        }

        // Adding the key via a ssh command
        block_on(self.exec_ssh(
            format!("echo \"{}\" >> $HOME/.ssh/authorized_keys", pub_key),
            ip,
            user,
            port,
        ))?;

        // Change back auth_method
        self.auth_method = auth_method_store;

        // A session may have been opened by the _exec_ssh call
        block_on(self.disconnect_session())?;

        Ok(())
    }

    async fn exec_ssh(
        &mut self,
        cmd: String,
        ip: &String,
        user: &String,
        port: u16,
    ) -> anyhow::Result<()> {
        if self.session.is_none() {
            if self.debug {
                godot_print!("No session open at exec call, trying to open one")
            }
            if let Err(e) = block_on(self.open_session(ip, user, port)) {
                anyhow::bail!("Failed to open ssh session: {}", e);
            }
        }
        // Check if session is closed
        if self.session.as_ref().unwrap().is_closed() {
            // Try reopening session once
            if let Err(e) = self.open_session(ip, user, port).await {
                anyhow::bail!("Failed to open ssh session: {}", e);
            }
        }

        // open channel
        // TODO maybe make this configurable
        let dur = Duration::new(1, 0);
        let channel =
            match future::timeout(dur, self.session.as_ref().unwrap().channel_open_session()).await
            {
                Ok(channel) => channel,
                Err(_) => {
                    self.session = None;
                    anyhow::bail!("Timed out when trying to open channel");
                }
            };
        let channel = match channel {
            Ok(channel) => channel,
            Err(error) => anyhow::bail!("Couldn't open channel: {}", error),
        };

        // run cmd
        if let Err(error) = channel.exec(false, cmd.clone()).await {
            anyhow::bail!(
                "Couldn't execute command: \"{}\" on {:?}: {}",
                cmd,
                channel.id(),
                error
            );
        } else if self.debug {
            godot_print!("Executing command: \"{}\" on {:?}", cmd, channel.id());
        }

        Ok(())
    }

    /// Open a new session
    async fn open_session(&mut self, ip: &String, user: &String, port: u16) -> anyhow::Result<()> {
        // If a session is currently active this will disconnect it
        self.disconnect_session().await?;

        if self.auth_method == AuthMethod::None {
            anyhow::bail!("No authentication method set");
        }

        let config = russh::client::Config {
            // TODO make this configurable
            keepalive_interval: Some(Duration::new(300, 0)),
            ..Default::default()
        };
        let config = Arc::new(config);
        let sh = Client {
            ip: ip.to_string(),
            port,
            server_check: self.server_check.clone(),
            debug: self.debug,
        };

        if self.debug {
            godot_print!("Trying to connect to {}:{}", ip, port);
        }

        // TODO maybe make this configurable
        let dur = Duration::new(1, 0);
        self.session = Some(match future::timeout(
            dur,
            russh::client::connect(config, (ip.clone(), port), sh),
        )
        .await
        {
            Ok(channel) => channel,
            Err(_) => {
                anyhow::bail!("Timed out when trying to open channel");
            }
        }?);

        self.authenticate(user).await?;

        if self.debug {
            godot_print!("Successfully connected to {}:{}", ip, port);
        }

        Ok(())
    }

    /// Disconnects current session
    async fn disconnect_session(&mut self) -> Result<(), russh::Error> {
        if let Some(session) = &self.session {
            if !session.is_closed() {
                session
                    .disconnect(russh::Disconnect::ByApplication, "", "")
                    .await?;
            }
            self.session = None;
        }
        Ok(())
    }

    /// This takes a handle and performs authentication with the given method.
    async fn authenticate(&mut self, user: &String) -> Result<(), anyhow::Error> {
        let session = match &mut self.session {
            Some(session) => session,
            None => anyhow::bail!("No session active"),
        };
        match &self.auth_method {
            AuthMethod::Password(password) => {
                if session.authenticate_password(user, password).await.is_ok() {
                    return Ok(());
                };
                Err(anyhow!("Wrong Password"))
            }
            AuthMethod::PrivateKey { key_data, key_pass } => {
                let mut private_key = match PrivateKey::from_openssh(key_data) {
                    Ok(kp) => kp,
                    Err(e) => return Err(anyhow!(e)),
                };
                if private_key.is_encrypted() {
                    private_key = if let Some(key_pass) = key_pass {
                        match private_key.decrypt(key_pass) {
                            Ok(private_key) => private_key,
                            Err(e) => anyhow::bail!("Failed to decrypt private key: {}", e),
                        }
                    } else {
                        anyhow::bail!("Key is encrypted but no password provided.");
                    };
                }

                let result = session
                    .authenticate_publickey(
                        user,
                        PrivateKeyWithHashAlg::new(
                            Arc::new(private_key),
                            session.best_supported_rsa_hash().await?.flatten(),
                        ),
                    )
                    .await?;
                match result {
                    client::AuthResult::Success => Ok(()),
                    _ => Err(anyhow!("Private key auth failed")),
                }
            }
            AuthMethod::PrivateKeyFile {
                key_file_path,
                key_pass,
            } => {
                let cprivk = match russh::keys::load_secret_key(key_file_path, key_pass.as_deref())
                {
                    Ok(kp) => kp,
                    Err(e) => return Err(anyhow!(e)),
                };

                let result = session
                    .authenticate_publickey(
                        user,
                        PrivateKeyWithHashAlg::new(
                            Arc::new(cprivk),
                            session.best_supported_rsa_hash().await?.flatten(),
                        ),
                    )
                    .await?;
                match result {
                    client::AuthResult::Success => Ok(()),
                    _ => Err(anyhow!("Private key auth failed")),
                }
            }
            _ => Err(anyhow!("Private key auth failed")),
        }
    }
}

impl Default for InternalSSHClient {
    fn default() -> Self {
        Self {
            debug: false,
            session: None,
            auth_method: AuthMethod::None,
            server_check: ServerCheckMethod::NoCheck,
        }
    }
}

/// A simple SSH client.
///
/// This client can open a single session and reuse said session
/// to spawn multiple channels and execute a command on that channel.
/// Currently it is not possible to get the output of an executed command.
/// The output of commands can only be printed in debug mode.
///
/// **Note:** Changing the configuration while a session is active doesn't
/// automatically close it, so the current session may still use the old configuration
/// and needs to manually be closed for it to take effect.
///
/// # Example usage
///
/// ```
/// var client: SSHClient = SSHClient.new()
/// client.user = "example_user"
/// client.ip = "127.0.0.1"
/// # Optional, as default is 22 already
/// client.port = 22
/// client.set_auth_password("secure_pw")
/// # Optional, as exec() would also try to open a session,
/// # but this way an error can be handled.
/// var err: Variant = client.open_session()
/// if err:
///     push_error("Failed to open session: %s" % err)
///     return
/// client.exec("echo Hello from SSH")
/// ```
#[derive(GodotClass)]
#[class(base = RefCounted)]
pub struct SSHClient {
    /// SSH user
    #[var]
    user: Variant,
    /// Server ip (defaults to 22)
    #[var]
    ip: Variant,
    /// Server port
    #[var]
    port: u16,
    _internal_ssh_client: InternalSSHClient,
}

#[godot_api]
pub impl IRefCounted for SSHClient {
    fn init(_base: Base<RefCounted>) -> Self {
        Self {
            user: Variant::nil(),
            ip: Variant::nil(),
            port: 22,
            _internal_ssh_client: InternalSSHClient::default(),
        }
    }
}

#[godot_api]
pub impl SSHClient {
    /// Set debug state of the client. In debug state it will verbosely print status updates
    /// and executed command outputs.
    #[func]
    fn set_debug(&mut self, debug: bool) {
        self._internal_ssh_client.debug = debug;
    }

    /// Get the current debug state.
    #[func]
    fn get_debug(&self) -> bool {
        self._internal_ssh_client.debug
    }

    /// Execute a command on the client. Needs to be configured to work.
    /// If there is already a session active, it will use this session, otherwise it will try to open one.
    ///
    /// * `cmd` - Command to execute.
    #[func]
    fn exec(&mut self, cmd: String) -> bool {
        if let Err(e) = self.check_configured() {
            godot_error!("{}", e);
            return false;
        }
        if let Err(e) = block_on(self._internal_ssh_client.exec_ssh(
            cmd,
            &self.ip.to_string(),
            &self.user.to_string(),
            self.port,
        )) {
            godot_error!("{}", e);
            return false;
        }
        true
    }

    /// Try to open a session for the client. If a session is already active it will be closed.
    /// Will return null on success, otherwise a string with the error will be returned.
    #[func]
    fn open_session(&mut self) -> Variant {
        if let Err(e) = self.check_configured() {
            return Variant::from(e.to_string());
        }
        if let Err(e) = block_on(self._internal_ssh_client.open_session(
            &self.ip.to_string(),
            &self.user.to_string(),
            self.port,
        )) {
            return Variant::from(e.to_string());
        }
        Variant::nil()
    }

    /// Disconnect the current session if one is active.
    #[func]
    fn disconnect_session(&mut self) {
        if let Err(error) = block_on(self._internal_ssh_client.disconnect_session()) {
            godot_error!("Failed to disconnect ssh session: {}", error);
        }
    }

    /// Returns the current session status.
    #[func]
    fn is_session_active(&self) -> bool {
        if let Some(session) = &self._internal_ssh_client.session {
            return !session.is_closed();
        }
        false
    }

    /// If the current auth method is a private key method, this function can add the private key
    /// to the current server's authorized keys. It doesn't check if the private key is already authorized, so
    /// it is recommended to only call this method on auth failure.
    ///
    /// **Note:** This will close any currently active sessions.
    ///
    /// * `password` - Password to temporarily connect to the server.
    #[func]
    fn add_key_to_server(&mut self, password: String) -> bool {
        if let Err(e) = self.check_configured() {
            godot_error!("{}", e);
            return false;
        }
        if let Err(e) = self._internal_ssh_client.add_key_to_server(
            password,
            &self.ip.to_string(),
            &self.user.to_string(),
            self.port,
        ) {
            godot_error!("{}", e);
            return false;
        }
        true
    }

    /// Sets auth method to type private key file.
    ///
    /// * `key_path` - Path to private key.
    /// * `password` - Optional password to decrypt private key.
    #[func]
    fn set_auth_key_file(&mut self, key_path: String, password: String) {
        self._internal_ssh_client.auth_method = AuthMethod::PrivateKeyFile {
            key_file_path: PathBuf::from(key_path),
            key_pass: if password.as_str() != "" {
                Some(password)
            } else {
                None
            },
        }
    }

    /// Sets auth method to type private key.
    ///
    /// * `key_data` - Base64 encoded key data of the private key.
    /// * `password` - Optional password to decrypt private key.
    #[func]
    fn set_auth_key(&mut self, key_data: String, password: String) {
        self._internal_ssh_client.auth_method = AuthMethod::PrivateKey {
            key_data,
            key_pass: if password.as_str() != "" {
                Some(password)
            } else {
                None
            },
        }
    }

    /// Sets auth method to type password.
    ///
    /// * `password` - Password for server.
    #[func]
    fn set_auth_password(&mut self, password: String) {
        self._internal_ssh_client.auth_method = AuthMethod::Password(password);
    }

    /// Sets the method by which to check the server against.
    ///
    /// * `method` - Currently supported: "known_hosts_file" or "no_check".
    #[func]
    fn set_server_check_method(&mut self, method: String) {
        match method.as_str() {
            "known_hosts_file" => {
                self._internal_ssh_client.server_check = ServerCheckMethod::DefaultKnownHostsFile
            }
            "no_check" => self._internal_ssh_client.server_check = ServerCheckMethod::NoCheck,
            _ => {
                self._internal_ssh_client.server_check = ServerCheckMethod::NoCheck;
            }
        }
    }

    // TODO add an optional password to encrypt key
    /// Generates a private key in the openssh format. This can be used as the `key_data` for `set_auth_key`.
    /// Returns empty string on failure.
    ///
    /// * `key_type` - Currently supported: "ED25519" or "RSA".
    /// * `key_size` - Size of the key if it's RSA. Recommended value is 4096. (Will be ignored for ED25519)
    /// * `comment` - Comment of the key. This is e.g. user@hostname by default for openssh.
    #[func]
    fn generate_private_key(key_type: String, key_size: i64, comment: String) -> String {
        match generate_private_key(key_type, key_size, comment) {
            Ok(base64_key) => base64_key,
            Err(e) => {
                godot_error!("{}", e);
                "".to_string()
            }
        }
    }

    /// Checks that the client is configured.
    fn check_configured(&self) -> anyhow::Result<()> {
        if self.user.is_nil() || self.user.get_type() != VariantType::STRING {
            anyhow::bail!("Invalid user \"{}\"", self.user);
        }
        if self.ip.is_nil() || self.ip.get_type() != VariantType::STRING {
            anyhow::bail!("Invalid ip \"{}\"", self.ip);
        }
        Ok(())
    }
}

/// Helper function that generates a base64 encoded key.
fn generate_private_key(
    key_type: String,
    key_size: i64,
    comment: String,
) -> anyhow::Result<String> {
    let mut rng = OsRng;
    let key_data = match key_type.as_str() {
        "ED25519" => KeypairData::from(Ed25519Keypair::random(&mut rng)),
        "RSA" => KeypairData::from(match RsaKeypair::random(&mut rng, key_size as usize) {
            Ok(key_data) => key_data,
            Err(e) => anyhow::bail!("Failed to generate rsa key data: {}", e),
        }),
        _ => anyhow::bail!("Unknown key type: {}", key_type),
    };
    let private_key = match PrivateKey::new(key_data, comment) {
        Ok(private_key) => private_key,
        Err(e) => anyhow::bail!("Failed to generate private key: {}", e),
    };
    Ok(private_key
        .to_openssh(keys::ssh_key::LineEnding::default())
        .unwrap()
        .to_string())
}
