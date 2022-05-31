# TouchMacroboard
A macroboard for a seperate touchscreen monitor using Godot and Rust.

## Description
This project's goal is to provide an application that let's you use a touchscreen monitor as a macroboard on Linux. It let's you launch programs, execute shell scripts etc.  
Normally when you use a touchscreen on Linux, it simulates a mouse event, which in turn moves the mouse cursor. This for me was not what I wanted, since I would then have to move the cursor back manually.  
This project circumvents this by grabbing the touchscreen input via evdev and then forwards the events to the application. This can of course be toggled to give back the original functionality if you need it.  

## Project status
This project is still a prototype.  
The basic functionality is there but I plan on adding more features.  
Right now the backbone of grabbing the evdev device and simulating the input without moving the mouse is mostly working as intended.  
There is also support for basic buttons, that execute shell scripts or launch programs.  

## Installation
### Building the project
You will need rust/cargo and godot 3.
```bash
# Download
## Clone the project
git clone https://github.com/jcronenberg/TouchMacroboard
## cd into project
cd TouchMacroboard

# Building the rust library
## cd to rust dir
cd rust
## Build the library
## Note: release is required as it is the linked library
##       it is also recommended as the debug build is too slow for use
cargo build --release
## cd back
cd ..

# Building the project
godot --export "Linux/X11"
```
The binary can now be found in `bin/`  
<strong>Important: A config file is required for the project to work!</strong>  
See the following section how to create one.

### Creating a config file
First create this directory if it doesn't already exist `~/.local/share/godot/app_userdata/TouchMacroboard` or just start the project once (it will crash without a config)  
In this path create a `config.json`.
My personal config can be found [here](https://github.com/jcronenberg/dotfiles/blob/master/various/executable_config.json) for reference.  
Note: icons need to be stored in `~/.local/share/godot/app_userdata/TouchMacroboard/icons`
