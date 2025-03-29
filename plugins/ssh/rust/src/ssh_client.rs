use crate::internal_ssh_client::{
    generate_private_key, AuthMethod, InternalSSHClient, ServerCheckMethod,
};
use async_std::task::block_on;
use godot::prelude::*;
use std::path::PathBuf;

/// A simple SSH client.
///
/// This client can open a single session and reuse said session
/// to spawn multiple channels and execute a command on that channel.
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
    ///
    /// **Note:** If a session is already open, the debug state won't apply to until closed
    /// and reopened.
    #[func]
    fn set_debug(&mut self, debug: bool) {
        self._internal_ssh_client.debug = debug;
    }

    /// Get the current debug state.
    #[func]
    fn get_debug(&self) -> bool {
        self._internal_ssh_client.debug
    }

    /// Execute a command asynchronously on the client. Client needs to be configured to work.
    /// If there is already a session active, it will use this session, otherwise it will try to open one.
    ///
    /// **Note:** While the client connects this will still block the thread, only after a connection is established
    /// and the command execution has started will it execute asynchronously.
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

    /// Execute a command in a blocking fashion on the client. Client needs to be configured to work.
    /// If there is already a session active, it will use this session, otherwise it will try to open one.
    ///
    /// * `cmd` - Command to execute.
    #[func]
    fn exec_blocking(&mut self, cmd: String) -> Variant {
        if let Err(e) = self.check_configured() {
            godot_error!("{}", e);
            return Variant::nil();
        }
        match self._internal_ssh_client.exec_ssh_blocking(
            cmd,
            &self.ip.to_string(),
            &self.user.to_string(),
            self.port,
        ) {
            Err(e) => {
                godot_error!("{}", e);
                Variant::nil()
            }
            Ok(dict) => Variant::from(dict),
        }
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
