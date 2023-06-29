use gdnative::prelude::*;
use nix::{
    fcntl::{FcntlArg, OFlag},
    sys::epoll,
};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::collections::HashMap;
use evdev::{
    Device,
    InputEventKind::{AbsAxis, Key},
    AbsoluteAxisType,
};
use std::fs;

/// Time interval between retrying to reconnect device
const RETRY_TIMER: f32 = 0.5;
/// The input devices path
const INPUT_DIR_PATH: &str = "/dev/input/";

macro_rules! PARSE_EVENT {
    ($owner:expr,$function:expr,$event:expr) => {
        $owner.get_parent().unwrap().assume_safe().call($function, &[Variant::new($event.value())])
    };
}

/// GrabTouchDevice "class"
/// Handles all evdev functions and then calls handler functions
#[derive(NativeClass)]
#[inherit(Node)]
pub struct GrabTouchDevice {
    /// The current device
    device: Option<Device>,
    /// String is formatted like this: "{id}: {name}"
    device_list: Option<HashMap<String, usize>>,
    /// State of device
    grabbed: bool,
    /// Timer for trying to reconnect
    retry_device: f32,
    /// Flag to try and grab the device for set amount of time
    try_grab: bool,
    /// Name of the currently selected device
    device_name: String,
    /// Current /dev/input dir, used to detect input device changes
    input_dir: String,
    /// The maximum absolute x axis value of current device
    device_max_abs_x: i32,
    /// The maximum absolute y axis value of current device
    device_max_abs_y: i32,
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

#[methods]
impl GrabTouchDevice {
    fn new(_owner: &Node) -> Self {
        GrabTouchDevice {
            device: None,
            device_list: None,
            grabbed: false,
            retry_device: 0.0,
            try_grab: false,
            device_name: String::new(),
            input_dir: read_input_dir(),
            device_max_abs_x: 0,
            device_max_abs_y: 0,
        }
    }


    #[method]
    fn get_device_max_abs_x(&mut self) -> Variant {
        return Variant::new(self.device_max_abs_x);
    }

    #[method]
    fn get_device_max_abs_y(&mut self) -> Variant {
        return Variant::new(self.device_max_abs_y);
    }

    /// Internal function to set self.device to matching self.device_name
    fn _set_device(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // Ensure that if a device is already grabbed we ungrab it first
        if self.grabbed {
            self.ungrab_device();
        }

        // Get id from device_list by matching name
        let id: usize = *match self.device_list.as_ref().unwrap().get(self.device_name.as_str()) {
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
    #[method]
    fn set_device(&mut self, name: String) -> Variant {
        self._get_devices();

        self.device_name = name;

        match self._set_device() {
            Err(e) => return Variant::new(e.to_string()),
            _ => (),
        }

        Variant::new(true)
    }

    /// Reconnect device the current device
    /// This is for a manual call by the handler
    #[method]
    fn reconnect_device(&mut self) {
        self.set_device(self.device_name.clone());
    }

    /// Internal function that populates self.device_list
    /// Only devices that support AbsoluteAxisTypes are listed
    fn _get_devices(&mut self) {
        let mut devices = evdev::enumerate().map(|t| t.1).collect::<Vec<_>>();
        devices.reverse();
        let mut device_map: HashMap<String, usize> = HashMap::new();
        for (i, d) in devices.iter().enumerate() {
           if d.supported_absolute_axes().map_or(false, |axes| axes.contains(AbsoluteAxisType::ABS_X) &&
                                                               axes.contains(AbsoluteAxisType::ABS_Y)) {
               device_map.insert(format!("{}", d.name().unwrap_or("Unnamed device")), i);
           }
        }
        self.device_list = Some(device_map);
    }

    /// Get all devices that support AbsoluteAxisTypes
    #[method]
    fn get_devices(&mut self) -> Variant {
        self._get_devices();

        let mut device_list_string: Vec<String> = Vec::new();
        match self.device_list.as_mut() {
            Some(device_list) => {
                for (n, _i) in device_list {
                    device_list_string.push(format!("{}", n));
                }
            },
            None => (),
        }
        device_list_string.reverse();
        Variant::new(device_list_string)
    }

    /// Grab the current self.device, set self.grabbed accordingly
    #[method]
    fn grab_device(&mut self) -> Variant {
        match self.device.as_mut() {
            Some(device) => {
                match device.grab() {
                    Err(e) => return Variant::new(e.to_string()),
                    _ => (),
                };
                self.grabbed = true;
            }
            None => (),
        }
        Variant::new(true)
    }

    /// Ungrab the current self.device, set self.grabbed accordingly
    #[method]
    fn ungrab_device(&mut self) {
        match self.device.as_mut() {
            Some(device) => {
                device.ungrab().unwrap();
                self.grabbed = false;
            }
            None => return,
        }
    }

    /// Returns true if something changed in input_dir
    fn _compare_input_dir(&mut self) -> bool {
        let new_dir = read_input_dir();

        // Check if input devices changed
        if self.input_dir != new_dir {
            // Store the new input_dir
            self.input_dir = new_dir;
            return true
        }
        return false
    }

    /// Godot _process function
    #[method]
    fn _physics_process(&mut self, #[base] owner: &Node, delta: f32) {
        // If not connected, retry to connect
        if !self.grabbed {
            // Store delta
            self.retry_device += delta;

            // Try grabbing the device multiple times when a new device is connected
            // as sometimes it won't immediately grab the device
            if self.try_grab && self.retry_device <= RETRY_TIMER / 2.0 {
                self.set_device(self.device_name.clone());
            } else if self.try_grab {
                self.try_grab = false;
            }

            // If cumulative delta is over timer
            if self.retry_device >= RETRY_TIMER {
                if self._compare_input_dir() {
                    self.try_grab = true;
                    // Try to connect to device
                    self.set_device(self.device_name.clone());
                }

                // Reset timer
                self.retry_device = 0.0;
            }
            return;
        }

        // Main loop when device is grabbed
        match self.device.as_mut() {
            Some(device) => {
                match device.fetch_events() {
                    Ok(iterator) => {
                        // Match event
                        for ev in iterator {
                            if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_X) {
                                unsafe { PARSE_EVENT!(owner, "x_coord_event", ev) };
                            } else if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_Y) {
                                unsafe { PARSE_EVENT!(owner, "y_coord_event", ev) };
                            } else if ev.kind() == Key(evdev::Key::BTN_TOUCH) {
                                unsafe { PARSE_EVENT!(owner, "key_event", ev) };
                            } else if ev.kind() == Key(evdev::Key::BTN_LEFT) {
                                unsafe { PARSE_EVENT!(owner, "key_event", ev) };
                            }
                        }
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        return;
                    }
                    Err(e) => {
                        // When we lose the device set grabbed to start trying to reconnect
                        self.grabbed = false;
                        self.try_grab = true;
                        godot_print!("{}", e);
                    }
                }
            }
            None => return,
        }
    }
}
