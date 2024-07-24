use evdev::{
    AbsoluteAxisType, Device,
    InputEventKind::{AbsAxis, Key},
};
use godot::prelude::*;
use nix::{
    fcntl::{FcntlArg, OFlag},
    sys::epoll,
};
use std::collections::HashMap;
use std::fs;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};

/// Time interval between retrying to reconnect device
const RETRY_TIMER: f64 = 0.5;
/// The input devices path
const INPUT_DIR_PATH: &str = "/dev/input/";

macro_rules! PARSE_EVENT {
    ($parent:expr,$function:expr,$event:expr) => {
        $parent.call($function, &[$event.value().to_variant()])
    };
}

/// GrabTouchDevice "class"
/// Handles all evdev functions and then calls handler functions
#[derive(GodotClass)]
#[class(base=Node)]
pub struct GrabTouchDevice {
    /// The current device
    device: Option<Device>,
    /// String is formatted like this: "{id}: {name}"
    device_list: Option<HashMap<GString, usize>>,
    /// State of device
    grabbed: bool,
    /// Timer for trying to reconnect
    retry_device: f64,
    /// Flag to try and grab the device for set amount of time
    try_grab: bool,
    /// Name of the currently selected device
    device_name: Option<GString>,
    /// Current /dev/input dir, used to detect input device changes
    input_dir: GString,
    /// The maximum absolute x axis value of current device
    device_max_abs_x: i32,
    /// The maximum absolute y axis value of current device
    device_max_abs_y: i32,
    parent: Option<Gd<Node>>,

    base: Base<Node>,
}

/// Read content of INPUT_DIR_PATH
/// Returns a String with all filenames inside
/// The String is not formatted, since it is used mainly for comparison
fn read_input_dir() -> String {
    let paths = fs::read_dir(INPUT_DIR_PATH).unwrap();
    let mut ret = String::new();

    for path in paths {
        ret.push_str(path.unwrap().path().to_str().unwrap());
    }
    ret
}

#[godot_api]
impl GrabTouchDevice {
    #[func]
    fn get_device_max_abs_x(&mut self) -> i32 {
        self.device_max_abs_x
    }

    #[func]
    fn get_device_max_abs_y(&mut self) -> i32 {
        self.device_max_abs_y
    }

    /// Internal function to set self.device to matching self.device_name
    fn _set_device(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // Ensure that if a device is already grabbed we ungrab it first
        if self.grabbed {
            self.ungrab_device();
        }

        if self.device_list.is_none() {
            return Err("No devices registered".into());
        }

        // Get id from device_list by matching name
	let device_name: &GString = match &self.device_name {
	    Some(device_name) => &device_name,
	    None => return Err("No device name set".into()),
	};
        let id: usize = *match self.device_list.as_ref().unwrap().get(device_name) {
            Some(id) => id,
            None => return Err("Device not found".into()),
        };

        // Get device by id
        let mut devices = evdev::enumerate().map(|t| t.1).collect::<Vec<_>>();
        devices.reverse();
        let device = devices.into_iter().nth(id).unwrap();

        // Nonblocking stuff
        let raw_fd = device.as_raw_fd();
        nix::fcntl::fcntl(raw_fd, FcntlArg::F_SETFL(OFlag::O_NONBLOCK))?;

        let epoll_fd = epoll::epoll_create1(epoll::EpollCreateFlags::EPOLL_CLOEXEC)?;
        let epoll_fd = unsafe { OwnedFd::from_raw_fd(epoll_fd) };
        let mut event = epoll::EpollEvent::new(epoll::EpollFlags::EPOLLIN, 0);
        epoll::epoll_ctl(
            epoll_fd.as_raw_fd(),
            epoll::EpollOp::EpollCtlAdd,
            raw_fd,
            Some(&mut event),
        )?;

        // get and store max absolute axis values for the device
        self.device_max_abs_x = device.get_abs_state().unwrap()[0].maximum;
        self.device_max_abs_y = device.get_abs_state().unwrap()[1].maximum;

        // store device so we can fetch events in _process
        self.device = Some(device);

        Ok(())
    }

    /// Set self.device by specified name
    #[func]
    fn set_device(&mut self, name: GString) -> Variant {
        self._get_devices();

        self.device_name = Some(name);

        if let Err(e) = self._set_device() {
            return e.to_string().to_variant();
        }

        true.to_variant()
    }

    /// Reconnect device the current device
    /// This is for a manual call by the handler
    #[func]
    fn reconnect_device(&mut self) {
	if let Some(device_name) = &self.device_name {
	    self.set_device(device_name.clone());
	}
    }

    /// Internal function that populates self.device_list
    /// Only devices that support AbsoluteAxisTypes are listed
    fn _get_devices(&mut self) {
        // Only refresh self.device_list if change in input_dir occurred
        if !self._compare_input_dir() {
            return;
        }

        let mut devices = evdev::enumerate().map(|t| t.1).collect::<Vec<_>>();
        devices.reverse();
        let mut device_map: HashMap<GString, usize> = HashMap::new();
        for (i, d) in devices.iter().enumerate() {
            if d.supported_absolute_axes().map_or(false, |axes| {
                axes.contains(AbsoluteAxisType::ABS_X) && axes.contains(AbsoluteAxisType::ABS_Y)
            }) {
                device_map.insert(d.name().unwrap_or("Unnamed device").to_string().into(), i);
            }
        }
        self.device_list = Some(device_map);
    }

    /// Get all devices that support AbsoluteAxisTypes
    #[func]
    fn get_devices(&mut self) -> PackedStringArray {
        self._get_devices();

        let mut device_list_string: Vec<GString> = Vec::new();
        if let Some(device_list) = &self.device_list {
            for n in device_list.keys() {
                device_list_string.push(format!("{}", n).into());
            }
        }
        device_list_string.reverse();
        PackedStringArray::from_iter(device_list_string)
    }

    /// Grab the current self.device, set self.grabbed accordingly
    #[func]
    fn grab_device(&mut self) -> Variant {
        if let Some(device) = self.device.as_mut() {
            if let Err(e) = device.grab() {
                return e.to_string().to_variant();
            }
            self.grabbed = true;
        }
        true.to_variant()
    }

    /// Ungrab the current self.device, set self.grabbed accordingly
    #[func]
    fn ungrab_device(&mut self) {
        if let Some(device) = self.device.as_mut() {
            device.ungrab().unwrap();
            self.grabbed = false;
        }
    }

    /// Returns true if something changed in input_dir
    fn _compare_input_dir(&mut self) -> bool {
        let new_dir = read_input_dir();

        // Check if input devices changed
        if self.input_dir != new_dir.clone().into() {
            // Store the new input_dir
            self.input_dir = new_dir.into();
            return true;
        }
        false
    }
}

#[godot_api]
impl INode for GrabTouchDevice {
    fn init(base: Base<Self::Base>) -> Self {
        GrabTouchDevice {
            device: None,
            device_list: None,
            grabbed: false,
            retry_device: 0.0,
            try_grab: false,
            device_name: None,
            input_dir: GString::new(),
            device_max_abs_x: 0,
            device_max_abs_y: 0,
            parent: None,
            base,
        }
    }

    /// Godot _physics_process function
    fn physics_process(&mut self, delta: f64) {
        // If not connected, retry to connect
        if !self.grabbed && self.device_name.is_some() {
            // Store delta
            self.retry_device += delta;

            // Try grabbing the device multiple times when a new device is connected
            // as sometimes it won't immediately grab the device
            if self.try_grab && self.retry_device <= RETRY_TIMER / 2.0 {
                self.set_device(self.device_name.as_ref().unwrap().clone());
            } else if self.try_grab {
                self.try_grab = false;
            }

            // If cumulative delta is over timer
            if self.retry_device >= RETRY_TIMER {
                if self._compare_input_dir() {
                    self.try_grab = true;
                    // Try to connect to device
                    self.set_device(self.device_name.as_ref().unwrap().clone());
                }

                // Reset timer
                self.retry_device = 0.0;
            }
            return;
        }

        // let mut parent = self.base_mut().get_parent().unwrap();
        if self.parent.is_none() {
            let parent = self.base_mut().get_parent();
            if parent.is_none() {
                godot_error!("Touch: failed to get parent");
                return;
            }
            self.parent = parent;
        }
        // Main loop when device is grabbed
        if let Some(device) = self.device.as_mut() {
            match device.fetch_events() {
                Ok(iterator) => {
                    // Match event
                    for ev in iterator {
                        if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_X) {
                            PARSE_EVENT!(self.parent.clone().unwrap(), "x_coord_event".into(), ev);
                        } else if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_Y) {
                            PARSE_EVENT!(self.parent.clone().unwrap(), "y_coord_event".into(), ev);
                        } else if ev.kind() == Key(evdev::Key::BTN_TOUCH)
                            || ev.kind() == Key(evdev::Key::BTN_LEFT)
                        {
                            PARSE_EVENT!(self.parent.clone().unwrap(), "key_event".into(), ev);
                        }
                    }
                }
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {}
                Err(e) => {
                    // When we lose the device set grabbed to start trying to reconnect
                    self.grabbed = false;
                    self.try_grab = true;
                    godot_print!("{}", e);
                }
            }
        }
    }
}
