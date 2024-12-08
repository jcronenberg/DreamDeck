use godot::prelude::*;

mod ssh_client;

struct DreamDeck;

#[gdextension]
unsafe impl ExtensionLibrary for DreamDeck {}
