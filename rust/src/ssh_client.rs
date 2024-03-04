use anyhow::anyhow;
use async_ssh2_tokio::{AuthMethod, ServerCheckMethod};
use async_std::future;
use async_std::task::block_on;
use async_trait::async_trait;
use chrono::Local;
use godot::prelude::*;
use osshkeys::keys::KeyPair;
use russh::client::Handle;
use russh::*;
use russh_keys::*;
use std::fs;
use std::sync::Arc;
use std::time::Duration;

// TODO make blocking an option
// because right now we just log the received data,
// however in the future something may depend on that data
// so to allow something to parse that, we should add an option to block the client
// but that means for every command there needs to be a SSHClient spawned
// or we could implement session management and allow opening multiple sessions per SSHClient

struct Client {
    debug: bool,
    ip: String,
    port: u16,
    server_check: ServerCheckMethod,
}

#[async_trait]
impl client::Handler for Client {
    type Error = anyhow::Error;

    async fn check_server_key(
        self,
        server_public_key: &key::PublicKey,
    ) -> Result<(Self, bool), Self::Error> {
        match &self.server_check {
            ServerCheckMethod::NoCheck => Ok((self, true)),
            ServerCheckMethod::PublicKey(key) => {
                let pk = russh_keys::parse_public_key_base64(key)
                    .map_err(|_| async_ssh2_tokio::Error::ServerCheckFailed)?;

                Ok((self, pk == *server_public_key))
            }
            ServerCheckMethod::PublicKeyFile(key_file_name) => {
                let pk = russh_keys::load_public_key(key_file_name)
                    .map_err(|_| async_ssh2_tokio::Error::ServerCheckFailed)?;

                Ok((self, pk == *server_public_key))
            }
            ServerCheckMethod::KnownHostsFile(known_hosts_path) => {
                let result = russh_keys::check_known_hosts_path(
                    &self.ip,
                    self.port,
                    server_public_key,
                    known_hosts_path,
                )
                .map_err(|_| async_ssh2_tokio::Error::ServerCheckFailed)?;

                Ok((self, result))
            }
            ServerCheckMethod::DefaultKnownHostsFile => {
                let result = russh_keys::check_known_hosts(&self.ip, self.port, server_public_key)
                    .map_err(|_| async_ssh2_tokio::Error::ServerCheckFailed)?;

                Ok((self, result))
            }
            _ => Err(anyhow!(async_ssh2_tokio::Error::ServerCheckFailed)),
        }
    }

    async fn data(
        self,
        channel: ChannelId,
        data: &[u8],
        session: client::Session,
    ) -> Result<(Self, client::Session), Self::Error> {
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
        Ok((self, session))
    }

    async fn extended_data(
        self,
        channel: ChannelId,
        ext: u32,
        data: &[u8],
        session: client::Session,
    ) -> Result<(Self, client::Session), Self::Error> {
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
        Ok((self, session))
    }

    async fn exit_status(
        self,
        channel: ChannelId,
        exit_status: u32,
        session: client::Session,
    ) -> Result<(Self, client::Session), Self::Error> {
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
        Ok((self, session))
    }
}

#[derive(GodotClass)]
#[class(base = Node)]
pub struct SSHClient {
    debug: bool,
    session: Option<Handle<Client>>,
    auth_method: Option<AuthMethod>,
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
            auth_method: None,
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
    fn setup(&mut self, user: GString, ip: GString, port: i64) {
        self.user = Some(user.into());
        self.ip = Some(ip.clone().into());
        self.port = port as u16;
    }

    #[func]
    fn set_debug(&mut self, debug: bool) {
        self.debug = debug;
    }

    #[func]
    fn exec(&mut self, cmd: GString) -> bool {
        if self.session.is_none() && !self.open_session() {
            return false;
        }
        return block_on(self._exec_ssh(cmd.to_string()));
    }

    #[func]
    fn open_session(&mut self) -> bool {
        match block_on(self._open_session()) {
            Ok(session) => self.session = Some(session),
            Err(error) => {
                self.session = None;
                godot_error!("Failed to open ssh session: {}", error);
                return false;
            }
        }
        true
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

    /// Adds the currently set self.auth_method to the ssh servers authorized_keys file
    /// This only works if self.auth_method is set to PrivateKeyFile
    /// to establish an ssh session which then copies the key a password needs to be
    /// supplied to handle authentication
    #[func]
    fn add_key(&mut self, password: GString) -> bool {
        let key_path;
        let passphrase: Option<String>;

        // Is only possible if self.auth_method is of type private key
        // We extract the values of self.auth_method to convert it later
        if let AuthMethod::PrivateKeyFile {
            key_file_name,
            key_pass,
        } = self.auth_method.clone().unwrap()
        {
            passphrase = key_pass;
            key_path = key_file_name;
        } else {
            return false;
        }

        // Since we can't log in with the currently set auth_method
        // we simply store it and replace it temporarily with a password
        let auth_method_store = self.auth_method.clone();
        self.auth_method = Some(AuthMethod::Password(password.into()));

        // With the extracted values we can generate a KeyPair which can give as the publickey string
        let key_pair = match KeyPair::from_keystr(
            &fs::read_to_string(key_path).unwrap(),
            passphrase
                .map(|string| string.as_str().to_owned())
                .as_deref(),
        ) {
            Ok(key) => key,
            Err(e) => {
                godot_error!("Couldn't load key: {}", e);
                return false;
            }
        };

        if self.debug {
            godot_print!("Copying public key to SSH server");
        }

        // Adding the key via a ssh command
        // TODO maybe only add if key isn't there
        let result = block_on(self._exec_ssh(format!(
            "echo \"{}\" >> ~/.ssh/authorized_keys",
            key_pair.serialize_publickey().unwrap()
        )));

        // Change back auth_method
        self.auth_method = auth_method_store;

        result
    }

    #[func]
    fn set_auth_method(&mut self, method: GString, key_path: GString, password: GString) {
        match method.to_string().as_str() {
            "key_file" => {
                self.auth_method = Some(AuthMethod::PrivateKeyFile {
                    key_file_name: key_path.to_string(),
                    key_pass: if password.to_string() != *"" {
                        Some(password.to_string())
                    } else {
                        None
                    },
                })
            }
            "password" => self.auth_method = Some(AuthMethod::Password(password.to_string())),
            _ => {
                self.auth_method = None;
            }
        }
    }

    #[func]
    fn set_server_check_method(&mut self, method: GString) {
        match method.to_string().as_str() {
            "known_hosts_file" => self.server_check = ServerCheckMethod::DefaultKnownHostsFile,
            "no_check" => self.server_check = ServerCheckMethod::NoCheck,
            _ => {
                self.server_check = ServerCheckMethod::NoCheck;
            }
        }
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

    async fn _open_session(&mut self) -> Result<Handle<Client>, anyhow::Error> {
        if self.auth_method.is_none() {
            return Err(anyhow!("No authentication method set"));
        } else if self.ip.is_none() || self.user.is_none() {
            return Err(anyhow!("Client not configured"));
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
                return Err(anyhow!("Timed out when trying to open channel"));
            }
        }?;

        let result = match self
            ._authenticate(
                &mut session,
                &self.user.clone().unwrap(),
                self.auth_method.clone().unwrap(),
            )
            .await
        {
            Ok(_) => Ok(session),
            Err(e) => return Err(anyhow!(e)),
        };

        if self.debug {
            godot_print!(
                "Successfully connected to {}:{}",
                self.ip.as_ref().unwrap(),
                self.port
            );
        }

        result
    }

    /// Disconnects a session
    async fn _disconnect_session(&mut self) -> Result<(), russh::Error> {
        if let Some(session) = &self.session {
            session
                .disconnect(russh::Disconnect::ByApplication, "", "")
                .await?
        }
        Ok(())
    }

    /// This takes a handle and performs authentication with the given method.
    async fn _authenticate(
        &mut self,
        handle: &mut Handle<Client>,
        username: &String,
        auth: AuthMethod,
    ) -> Result<(), anyhow::Error> {
        match auth {
            AuthMethod::Password(password) => {
                if handle
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
                    match russh_keys::decode_secret_key(key_data.as_str(), key_pass.as_deref()) {
                        Ok(kp) => kp,
                        Err(e) => return Err(anyhow!(e)),
                    };

                if handle
                    .authenticate_publickey(username, Arc::new(cprivk))
                    .await
                    .is_ok()
                {
                    return Ok(());
                };
                Err(anyhow!("Private key auth failed"))
            }
            AuthMethod::PrivateKeyFile {
                key_file_name,
                key_pass,
            } => {
                let cprivk = match russh_keys::load_secret_key(key_file_name, key_pass.as_deref()) {
                    Ok(kp) => kp,
                    Err(e) => return Err(anyhow!(e)),
                };

                if let Ok(is_authenticated) = handle
                    .authenticate_publickey(username, Arc::new(cprivk))
                    .await
                {
                    if is_authenticated {
                        return Ok(());
                    }
                };
                Err(anyhow!("Private key auth failed"))
            }
            _ => Err(anyhow!("Private key auth failed")),
        }
    }
}

// TODO this part is for the future to generate a ssh key pair
// use osshkeys::KeyType;
// use std::os::unix::prelude::PermissionsExt;
//
// fn generate_key(key_path: String) {
//     let key_pair = KeyPair::generate(KeyType::ED25519, 0).unwrap();
//     let pub_key_path = format!("{}.pub", &key_path);
//     let _ = fs::write(
//         &key_path,
//         key_pair
//             .serialize_openssh(None, osshkeys::cipher::Cipher::Aes256_Ctr)
//             .unwrap(),
//     );
//     let _ = set_perm(&key_path);
//     let _ = fs::write(
//         &pub_key_path,
//         format!("{}\n", key_pair.serialize_publickey().unwrap()),
//     );
//     let _ = set_perm(&pub_key_path);
// }

// // TODO investigate if how this works for non-linux oses
// fn set_perm(path: &str) -> std::io::Result<()> {
//     let mut perms = fs::metadata(path)?.permissions();
//     perms.set_mode(0o600);
//     fs::set_permissions(path, perms)?;
//     Ok(())
// }
