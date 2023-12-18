use godot::prelude::*;

mod better_processes;
mod ssh_client;

struct DreamDeck;

#[gdextension]
unsafe impl ExtensionLibrary for DreamDeck {}
