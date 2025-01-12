use godot::prelude::*;

mod ssh_client;

struct DreamDeckSSH;

#[gdextension]
unsafe impl ExtensionLibrary for DreamDeckSSH {}
