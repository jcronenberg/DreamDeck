use godot::prelude::*;

mod grab_touch_device;

struct GrabTouchDevice;

#[gdextension]
unsafe impl ExtensionLibrary for GrabTouchDevice {}
