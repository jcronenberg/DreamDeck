use godot::prelude::*;

mod grab_touch_device;

struct DreamDeckTouch;

#[gdextension]
unsafe impl ExtensionLibrary for DreamDeckTouch {}
