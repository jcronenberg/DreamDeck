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
}

#[methods]
impl GrabTouchDevice {
    fn new(_owner: &Node) -> Self {
        GrabTouchDevice {
            device: None,
            device_list: None,
            handler: None,
            grabbed: false,
        }
    }

    /// Internal function to set self.device by specified id
    /// id needs to be a valid id for evdev::enumerate()
    fn _set_device(&mut self, owner: &Node, id: usize) {
        // Ensure that if a device is already grabbed we ungrab it first
        if self.grabbed {
            self.ungrab_device(owner);
        }

        // Get device by id
        let mut devices = evdev::enumerate()
            .collect::<Vec<_>>();
        devices.reverse();
        let mut device = devices.into_iter().nth(id).unwrap();

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

        // grab device MAYBE debug?
        device.grab().unwrap();
        self.grabbed = true;

        // store device so we can fetch events in _process
        self.device = Some(device);
    }

    /// Set self.device by specified name
    #[export]
    fn set_device(&mut self, owner: &Node, name: String) {
        if self.device_list == None {
            self._get_devices();
        }
        self._set_device(owner, *self.device_list.as_ref().unwrap().get(name.as_str()).unwrap());
    }

    /// Internal function that populates self.device_list
    /// Only devices that support AbsoluteAxisTypes are listed
    fn _get_devices(&mut self) {
        let mut devices = evdev::enumerate()
            .collect::<Vec<_>>();
        devices.reverse();
        let mut device_map: HashMap<String, usize> = HashMap::new();
        for (i, d) in devices.iter().enumerate() {
           if d.supported_absolute_axes().map_or(false, |axes| axes.contains(AbsoluteAxisType::ABS_X)) {
               device_map.insert(format!("{}: {}", i, d.name().unwrap_or("Unnamed device")), i);
           }
        }
        self.device_list = Some(device_map);
    }

    /// Get all devices that support AbsoluteAxisTypes
    #[export]
    fn get_devices(&mut self, _owner: &Node) -> Variant {
        if self.device_list == None {
            self._get_devices();
        }
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
    fn _process(&mut self, _owner: &Node, _delta: f32) {
        match self.device.as_mut() {
            Some(device) => {
                match device.fetch_events() {
                    Ok(iterator) => {
                        let handler = match self.handler {
                            Some(handler) => unsafe { handler.assume_safe() },
                            None => { godot_print!("Handler missing"); return },
                        };
                        for ev in iterator {
                            if self.grabbed {
                                if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_X) {
                                    unsafe { handler.call("x_coord_event", &[Variant::new(ev.value())]) };
                                } else if ev.kind() == AbsAxis(AbsoluteAxisType::ABS_Y) {
                                    unsafe { handler.call("y_coord_event", &[Variant::new(ev.value())]) };
                                } else if ev.kind() == Key(evdev::Key::BTN_TOUCH) {
                                    unsafe { handler.call("key_event", &[Variant::new(ev.value())]) };
                                }
                            }
                        }
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        return;
                    }
                    Err(e) => {
                        godot_print!("{}", e);
                    }
                }
            }
            None => return,//godot_print!("No device"),
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
