use gdnative::prelude::*;

mod grab_touch_device;

fn init(handle: InitHandle) {
    handle.add_class::<grab_touch_device::GrabTouchDevice>();
}

godot_init!(init);
