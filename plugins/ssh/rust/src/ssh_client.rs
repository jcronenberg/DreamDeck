use anyhow::anyhow;
use async_std::future;
use async_std::task::block_on;
use base64::prelude::BASE64_STANDARD;
use base64::Engine;
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

#[derive(GodotClass)]
#[class(base = Node)]
pub struct SSHClient {
    debug: bool,
    session: Option<Handle<Client>>,
    auth_method: AuthMethod,
    server_check: ServerCheckMethod,
    user: Option<String>,
    ip: Option<String>,
    port: u16,
    _base: Base<Node>,
}

#[godot_api]
pub impl INode for SSHClient {
    fn init(base: Base<Node>) -> Self {
        Self {
            debug: false,
            session: None,
            auth_method: AuthMethod::None,
            server_check: ServerCheckMethod::NoCheck,
            user: None,
            ip: None,
            port: 22,
            _base: base,
        }
    }
}

/// A simple SSH client that can open a single session and reuse said session
/// to spawn multiple channels and execute a command on that channel
#[godot_api]
pub impl SSHClient {
    #[func]
    fn setup(&mut self, user: String, ip: String, port: i64) {
        self.user = Some(user);
        self.ip = Some(ip);
        self.port = port as u16;
    }

    #[func]
    fn set_debug(&mut self, debug: bool) {
        self.debug = debug;
    }

    #[func]
    fn exec(&mut self, cmd: String) -> bool {
        if self.session.is_none() {
            let result = self.open_session();
            if !result.is_nil() {
                godot_error!("Failed to open session: {}", result);
                return false;
            }
        }
        block_on(self._exec_ssh(cmd))
    }

    #[func]
    fn open_session(&mut self) -> Variant {
        self.session = Some(match block_on(self._open_session()) {
            Ok(session) => session,
            Err(error) => return Variant::from(error.to_string()),
        });
        Variant::nil()
    }

    #[func]
    fn disconnect_session(&mut self) {
        if let Err(error) = block_on(self._disconnect_session()) {
            godot_error!("Failed to disconnect ssh session: {}", error);
        }
    }

    #[func]
    fn is_session_active(&mut self) -> bool {
        if let Some(session) = &self.session {
            return !session.is_closed();
        }
        false
    }

    /// If the current auth method is a private key method, this function can the private key
    /// to the current server. It doesn't check if the private key is already authorized, so
    /// it is recommended to only call this method on auth failure.
    ///
    /// * `password` - Password to temporarily connect to the server.
    #[func]
    fn add_key(&mut self, password: String) -> bool {
        let passphrase: Option<String>;

        let private_key = match self.auth_method.clone() {
            AuthMethod::PrivateKeyFile {
                key_file_path,
                key_pass,
            } => {
                passphrase = key_pass;
                match PrivateKey::read_openssh_file(&key_file_path) {
                    Ok(key_data) => key_data,
                    Err(e) => {
                        godot_error!("Failed to read key at {}: {}", key_file_path.display(), e);
                        return false;
                    }
                }
            }
            AuthMethod::PrivateKey { key_data, key_pass } => {
                passphrase = key_pass;
                match PrivateKey::from_bytes(&BASE64_STANDARD.decode(key_data).unwrap()) {
                    Ok(private_key) => private_key,
                    Err(e) => {
                        godot_error!("Failed to parse private key: {}", e);
                        return false;
                    }
                }
            }
            // Is only possible if self.auth_method is of type private key
            _ => return false,
        };
        let private_key = if private_key.is_encrypted() {
            if let Some(passphrase) = passphrase {
                match private_key.decrypt(passphrase) {
                    Ok(private_key) => private_key,
                    Err(e) => {
                        godot_error!("Failed to parse private key: {}", e);
                        return false;
                    }
                }
            } else {
                godot_error!("Key is encrypted but no password provided.");
                return false;
            }
        } else {
            private_key
        };

        let pub_key = match private_key.public_key().to_openssh() {
            Ok(pub_key) => pub_key,
            Err(e) => {
                godot_error!("Failed to serialize public key: {}", e);
                return false;
            }
        };

        // Temporarily set auth method to password to allow login
        let auth_method_store = self.auth_method.clone();
        self.auth_method = AuthMethod::Password(password);

        if self.debug {
            godot_print!("Copying public key to SSH server");
        }

        // Adding the key via a ssh command
        let result = block_on(self._exec_ssh(format!(
            "echo \"{}\" >> $HOME/.ssh/authorized_keys",
            pub_key
        )));

        // Change back auth_method
        self.auth_method = auth_method_store;

        // A session may have been opened by the _exec_ssh call
        self.disconnect_session();

        result
    }

    /// Sets auth method to type private key file.
    ///
    /// * `key_path` - Path to private key.
    /// * `password` - Optional password to decrypt private key.
    #[func]
    fn set_auth_key_file(&mut self, key_path: String, password: String) {
        self.auth_method = AuthMethod::PrivateKeyFile {
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
        self.auth_method = AuthMethod::PrivateKey {
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
        self.auth_method = AuthMethod::Password(password);
    }

    /// Sets the method by which to check the server against.
    ///
    /// * `method` - Currently supported: "known_hosts_file" or "no_check".
    #[func]
    fn set_server_check_method(&mut self, method: String) {
        match method.as_str() {
            "known_hosts_file" => self.server_check = ServerCheckMethod::DefaultKnownHostsFile,
            "no_check" => self.server_check = ServerCheckMethod::NoCheck,
            _ => {
                self.server_check = ServerCheckMethod::NoCheck;
            }
        }
    }

    /// Generates a private key base64 encoded. This can be used as the `key_data` for `set_auth_key`.
    /// Returns empty string on failure.
    ///
    /// * `key_type` - Currently supported: "ED25519" or "RSA".
    /// * `key_size` - Size of the key if it's RSA. Recommended value is 4096.
    /// * `comment` - Comment of the key. This is e.g. user@hostname by default for openssh.
    #[func]
    fn generate_private_key(key_type: String, key_size: i64, comment: String) -> String {
        let mut rng = OsRng;
        let key_data = match key_type.as_str() {
            "ED25519" => KeypairData::from(Ed25519Keypair::random(&mut rng)),
            "RSA" => KeypairData::from(match RsaKeypair::random(&mut rng, key_size as usize) {
                Ok(key_data) => key_data,
                Err(e) => {
                    godot_error!("Failed to generate rsa key data: {}", e);
                    return "".to_string();
                }
            }),
            _ => {
                godot_error!("Unknown key type: {}", key_type);
                return "".to_string();
            }
        };
        let private_key = match PrivateKey::new(key_data, comment) {
            Ok(private_key) => private_key,
            Err(e) => {
                godot_error!("Failed to generate private key: {}", e);
                return "".to_string();
            }
        };
        BASE64_STANDARD.encode(private_key.to_bytes().unwrap())
    }

    async fn _exec_ssh(&mut self, cmd: String) -> bool {
        if self.session.is_none() {
            if self.debug {
                godot_print!("No session open at exec call, trying to open one")
            }
            match block_on(self._open_session()) {
                Ok(session) => self.session = Some(session),
                Err(error) => {
                    godot_error!("Failed to open ssh session: {}", error);
                    return false;
                }
            }
        }
        // Check if session is closed
        if self.session.as_ref().unwrap().is_closed() {
            // Try reopening session once
            match self._open_session().await {
                Ok(session) => self.session = Some(session),
                Err(error) => {
                    self.session = None;
                    godot_error!("Failed to open ssh session: {}", error);
                    return false;
                }
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
                    godot_error!("Timed out when trying to open channel");
                    return false;
                }
            };
        let channel = match channel {
            Ok(channel) => channel,
            Err(error) => {
                godot_error!("Couldn't open channel: {}", error);
                return false;
            }
        };
        // run cmd
        if let Err(error) = channel.exec(false, cmd.clone()).await {
            godot_error!(
                "Couldn't execute command: \"{}\" on {:?}: {}",
                cmd,
                channel.id(),
                error
            );
            return false;
        } else if self.debug {
            godot_print!("Executing command: \"{}\" on {:?}", cmd, channel.id());
        }
        true
    }

    /// Open a new session with current client settings
    async fn _open_session(&mut self) -> Result<Handle<Client>, anyhow::Error> {
        if self.auth_method == AuthMethod::None {
            anyhow::bail!("No authentication method set");
        } else if self.ip.is_none() || self.user.is_none() {
            anyhow::bail!("Client not configured");
        }

        let config = russh::client::Config {
            // TODO make this configurable
            keepalive_interval: Some(Duration::new(300, 0)),
            ..Default::default()
        };
        let config = Arc::new(config);
        let sh = Client {
            ip: self.ip.clone().unwrap(),
            port: self.port,
            server_check: self.server_check.clone(),
            debug: self.debug,
        };

        if self.debug {
            godot_print!(
                "Trying to connect to {}:{}",
                self.ip.as_ref().unwrap(),
                self.port
            );
        }

        // TODO maybe make this configurable
        let dur = Duration::new(1, 0);
        let mut session = match future::timeout(
            dur,
            russh::client::connect(config, (self.ip.clone().unwrap(), self.port), sh),
        )
        .await
        {
            Ok(channel) => channel,
            Err(_) => {
                anyhow::bail!("Timed out when trying to open channel");
            }
        }?;

        if let Err(e) = self._authenticate(&mut session).await {
            anyhow::bail!(e);
        };

        if self.debug {
            godot_print!(
                "Successfully connected to {}:{}",
                self.ip.as_ref().unwrap(),
                self.port
            );
        }

        Ok(session)
    }

    /// Disconnects current session
    async fn _disconnect_session(&mut self) -> Result<(), russh::Error> {
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
    async fn _authenticate(&mut self, session: &mut Handle<Client>) -> Result<(), anyhow::Error> {
        let username = match &self.user {
            None => anyhow::bail!("No user set"),
            Some(user) => user,
        };
        match &self.auth_method {
            AuthMethod::Password(password) => {
                if session
                    .authenticate_password(username, password)
                    .await
                    .is_ok()
                {
                    return Ok(());
                };
                Err(anyhow!("Wrong Password"))
            }
            AuthMethod::PrivateKey { key_data, key_pass } => {
                let cprivk =
                    match russh::keys::decode_secret_key(key_data.as_str(), key_pass.as_deref()) {
                        Ok(kp) => kp,
                        Err(e) => return Err(anyhow!(e)),
                    };

                let result = session
                    .authenticate_publickey(
                        username,
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
                        username,
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
