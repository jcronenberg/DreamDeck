use anyhow::anyhow;
use async_std::future;
use async_std::task::block_on;
use chrono::Local;
use client::Msg;
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
pub enum AuthMethod {
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

pub struct Client {
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

pub struct InternalSSHClient {
    pub debug: bool,
    pub session: Option<Handle<Client>>,
    pub auth_method: AuthMethod,
    pub server_check: ServerCheckMethod,
}

impl InternalSSHClient {
    pub fn add_key_to_server(
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

        block_on(self.disconnect_session())?;
        block_on(self.open_session(ip, user, port))?;
        // Adding the key via a ssh command
        // This is kind of ugly but it is the best way I found that should work
        // most reliably even if the server is windows.
        // The mkdir will most likely fail because on most setups .ssh should
        // already exist, but this only prints a error and still works.
        self.exec_ssh_blocking("mkdir .ssh".to_string(), ip, user, port)?;
        self.exec_ssh_blocking(
            format!("echo {} >> .ssh/authorized_keys", pub_key),
            ip,
            user,
            port,
        )?;

        // Change back auth_method
        self.auth_method = auth_method_store;

        // A session may have been opened by the _exec_ssh call
        block_on(self.disconnect_session())?;

        Ok(())
    }

    pub fn exec_ssh_blocking(
        &mut self,
        cmd: String,
        ip: &String,
        user: &String,
        port: u16,
    ) -> anyhow::Result<Dictionary> {
        let mut channel = block_on(self.open_channel(ip, user, port))?;

        // run cmd
        if let Err(error) = block_on(channel.exec(false, cmd.clone())) {
            anyhow::bail!(
                "Couldn't execute command: \"{}\" on {:?}: {}",
                cmd,
                channel.id(),
                error
            );
        } else if self.debug {
            godot_print!("Executing command: \"{}\" on {:?}", cmd, channel.id());
        }
        let mut stdout = String::new();
        let mut stderr = String::new();
        let mut exit_status: i64 = -1;
        loop {
            let msg = block_on(channel.wait());
            match msg {
                Some(msg) => match msg {
                    ChannelMsg::Data { data } => stdout.push_str(&String::from_utf8_lossy(&data)),
                    ChannelMsg::ExtendedData { ext, data } => {
                        if ext == 1 {
                            stderr.push_str(&String::from_utf8_lossy(&data))
                        }
                    }
                    ChannelMsg::ExitStatus {
                        exit_status: new_exit_status,
                    } => exit_status = new_exit_status as i64,
                    _ => (),
                },
                None => break,
            }
        }

        Ok(dict! {"stdout": stdout, "stderr": stderr, "exit_status": exit_status})
    }

    pub async fn exec_ssh(
        &mut self,
        cmd: String,
        ip: &String,
        user: &String,
        port: u16,
    ) -> anyhow::Result<()> {
        let channel = self.open_channel(ip, user, port).await?;

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

    async fn open_channel(
        &mut self,
        ip: &String,
        user: &String,
        port: u16,
    ) -> anyhow::Result<Channel<Msg>> {
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
        match channel {
            Ok(channel) => Ok(channel),
            Err(error) => anyhow::bail!("Couldn't open channel: {}", error),
        }
    }

    /// Open a new session
    pub async fn open_session(
        &mut self,
        ip: &String,
        user: &String,
        port: u16,
    ) -> anyhow::Result<()> {
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
    pub async fn disconnect_session(&mut self) -> Result<(), russh::Error> {
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

/// Helper function that generates a base64 encoded key.
pub fn generate_private_key(
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
