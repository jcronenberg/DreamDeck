use godot::prelude::*;

mod better_processes;

struct DreamDeck;

#[gdextension]
unsafe impl ExtensionLibrary for DreamDeck {}
