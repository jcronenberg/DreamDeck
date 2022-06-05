use gdnative::prelude::*;
use nix::{
    fcntl::{FcntlArg, OFlag},
    sys::epoll,
};
use std::os::unix::io::{AsRawFd, RawFd};
use std::collections::HashMap;
use evdev::{
    Device,
    InputEventKind::{AbsAxis, Key},
    AbsoluteAxisType,
};
use std::fs;

/// Time interval between retrying to reconnect device
const RETRY_TIMER: f32 = 1.0;
/// The input devices path
const INPUT_DIR_PATH: &str = "/dev/input/";

/// GrabTouchDevice "class"
/// Handles all evdev functions and then calls handler functions
#[derive(NativeClass)]
#[inherit(Node)]
pub struct GrabTouchDevice {
    /// The current device
    device: Option<Device>,
    /// String is formatted like this: "{id}: {name}"
    device_list: Option<HashMap<String, usize>>,
    /// Handler for handeling events in godot
    handler: Option<Ref<Node>>,
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
            handler: None,
            grabbed: false,
            retry_device: 0.0,
            try_grab: false,
            device_name: String::new(),
            input_dir: read_input_dir(),
        }
    }

    /// Internal function to set self.device by specified id
    /// id needs to be a valid id for evdev::enumerate()
    fn _set_device(&mut self, owner: &Node) {
        // Ensure that if a device is already grabbed we ungrab it first
        if self.grabbed {
            self.ungrab_device(owner);
        }

        // Get id from device_list by matching name
        let id: usize = *match self.device_list.as_ref().unwrap().get(self.device_name.as_str()) {
            Some(id) => id,
            None => return,
        };

        // Get device by id
        let mut devices = evdev::enumerate()
            .collect::<Vec<_>>();
        devices.reverse();
        let device = devices.into_iter().nth(id).unwrap();

        // Nonblocking stuff
        let raw_fd = device.as_raw_fd();
        nix::fcntl::fcntl(raw_fd, FcntlArg::F_SETFL(OFlag::O_NONBLOCK)).unwrap();

        let epoll_fd = Epoll::new(epoll::epoll_create1(
            epoll::EpollCreateFlags::EPOLL_CLOEXEC,
        ).unwrap());
        let mut event = epoll::EpollEvent::new(epoll::EpollFlags::EPOLLIN, 0);
        epoll::epoll_ctl(
            epoll_fd.as_raw_fd(),
            epoll::EpollOp::EpollCtlAdd,
            raw_fd,
            Some(&mut event),
        ).unwrap();

        // store device so we can fetch events in _process
        self.device = Some(device);

        // Grab device
        self.grab_device(owner);
    }

    /// Set self.device by specified name
    #[export]
    fn set_device(&mut self, owner: &Node, name: String) {
        self._get_devices();

        self.device_name = name;

        self._set_device(owner);
    }

    /// Reconnect device the current device
    /// This is for a manual call by the handler
    #[export]
    fn reconnect_device(&mut self, owner: &Node) {
        godot_print!("reconnecting device");
        self.set_device(owner, self.device_name.clone());
    }

    /// Internal function that populates self.device_list
    /// Only devices that support AbsoluteAxisTypes are listed
    fn _get_devices(&mut self) {
        let mut devices = evdev::enumerate()
            .collect::<Vec<_>>();
        devices.reverse();
        let mut device_map: HashMap<String, usize> = HashMap::new();
        for (i, d) in devices.iter().enumerate() {
           if d.supported_absolute_axes().map_or(false, |axes| axes.contains(AbsoluteAxisType::ABS_MT_POSITION_X)) {
               device_map.insert(format!("{}", d.name().unwrap_or("Unnamed device")), i);
           }
        }
        self.device_list = Some(device_map);
    }

    /// Get all devices that support AbsoluteAxisTypes
    #[export]
    fn get_devices(&mut self, _owner: &Node) -> Variant {
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
    #[export]
    fn grab_device(&mut self, _owner: &Node) {
        match self.device.as_mut() {
            Some(device) => {
                device.grab().unwrap();
                self.grabbed = true;
            }
            None => return,
        }
    }

    /// Ungrab the current self.device, set self.grabbed accordingly
    #[export]
    fn ungrab_device(&mut self, _owner: &Node) {
        match self.device.as_mut() {
            Some(device) => {
                device.ungrab().unwrap();
                self.grabbed = false;
            }
            None => return,
        }
    }

    /// Godot _ready function
    #[export]
    fn _ready(&mut self, owner: &Node) {
        self.handler = Some(Node::get_node(owner, NodePath::from_str("/root/HandleTouchEvents")).unwrap());
    }

    /// Godot _process function
    #[export]
    fn _process(&mut self, owner: &Node, delta: f32) {
        // If not connected, retry to connect
        if !self.grabbed {
            // Store delta
            self.retry_device += delta;

            // Try grabbing the device multiple times when a new device is connected
            // as sometimes it won't immediately grab the device
            if self.try_grab && self.retry_device <= RETRY_TIMER / 3.0 {
                self.set_device(owner, self.device_name.clone());
            } else if self.try_grab {
                self.try_grab = false;
            }

            // If cumulative delta is over timer
            if self.retry_device >= RETRY_TIMER {
                // Read input dir
                let new_dir = read_input_dir();

                // Check if input devices changed
                if self.input_dir != new_dir {
                    // Store the new input_dir
                    self.input_dir = read_input_dir();
                    self.try_grab = true;

                    // Try to connect to device
                    self.set_device(owner, self.device_name.clone());
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
                        // Make sure we have a handler
                        let handler = match self.handler {
                            Some(handler) => unsafe { handler.assume_safe() },
                            None => { godot_print!("Handler missing"); return },
                        };

                        // Match event
                        for ev in iterator {
                            if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_X) {
                                unsafe { handler.call("x_coord_event", &[Variant::new(ev.value())]) };
                            } else if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_Y) {
                                unsafe { handler.call("y_coord_event", &[Variant::new(ev.value())]) };
                            } else if ev.kind() == Key(evdev::Key::BTN_TOUCH) {
                                unsafe { handler.call("key_event", &[Variant::new(ev.value())]) };
                            }
                        }
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        return;
                    }
                    Err(e) => {
                        // When we lose the device set grabbed to start trying to reconnect
                        self.grabbed = false;
                        godot_print!("{}", e);
                    }
                }
            }
            None => return,
        }
    }
}

struct Epoll(RawFd);

impl Epoll {
    pub(crate) fn new(fd: RawFd) -> Self {
        Epoll(fd)
    }
}

impl AsRawFd for Epoll {
    fn as_raw_fd(&self) -> RawFd {
        self.0
    }
}
