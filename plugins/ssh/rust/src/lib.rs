use godot::prelude::*;

mod internal_ssh_client;
mod ssh_client;

struct DreamDeckSSH;

#[gdextension]
unsafe impl ExtensionLibrary for DreamDeckSSH {}
