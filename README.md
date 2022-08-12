# DreamDeck
A macroboard for a seperate touchscreen monitor on linux.
![image](https://user-images.githubusercontent.com/54934253/176308133-d2021cba-7299-4c8d-98f1-345ecb294dc1.png)


## Description
This project's main goal is to provide an application that let's you use a touchscreen monitor as a macroboard on Linux. It let's you launch programs, execute shell scripts etc.  
Normally when you use a touchscreen on Linux, it simulates a mouse event, which in turn moves the mouse cursor. This for me was not what I wanted, since I would then have to move the cursor back manually.  
This project circumvents this by grabbing the touchscreen input via evdev and then forwards the events to the application. This can of course be toggled to give back the original functionality if you need it.  

## Project status
This project is still a prototype.  
The basic functionality is there but I plan on adding more features.  
Right now the backbone of grabbing the evdev device and simulating the input without moving the mouse is mostly working as intended.  
There is also support for basic buttons, that execute shell scripts or launch programs.  

## Installation
### Building the project
You will need rust/cargo and godot 3 (3.5 recommended).
```bash
# Download
## Clone the project
git clone https://github.com/jcronenberg/DreamDeck
## cd into the project
cd DreamDeck

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
<strong>Important: The config system is still very much a work in progress!</strong>  
The program will crash without a configuration present, see the following section how to create one.

### Creating a config file
First create this directory if it doesn't already exist `~/.local/share/godot/app_userdata/DreamDeck` or just start the project once (it will crash without a config)  
Here you will have to create some config files, see this [link](https://github.com/jcronenberg/dotfiles/tree/master/various/DreamDeck) for an example configuration. Copy those files into the above directory and modify them to fit your needs.  
Note: icons need to be stored in `~/.local/share/godot/app_userdata/DreamDeck/icons` the path in `plugins/Macroboard/config` is relative to that directory.

## Plugins
### Connect to Spotify's API
1. Go to the [Spotify dashboard](https://developer.spotify.com/dashboard/applications)
1. Click `Create an app`
    - You now can see your `Client ID` and `Client Secret`
1. Now click `Edit Settings`
1. Add `http://localhost:8888/callback` to the Redirect URIs
1. Scroll down and click `Save`
1. You are now ready to authenticate with Spotify!
1. Follow instructions shown by DreamDeck
