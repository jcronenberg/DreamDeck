# DreamDeck
A macroboard for a separate touchscreen monitor on linux.
![image](https://user-images.githubusercontent.com/54934253/176308133-d2021cba-7299-4c8d-98f1-345ecb294dc1.png)


## Description
This projects main goal is to provide an application that lets you use a touchscreen monitor as a macroboard on Linux. It lets you launch programs, execute shell scripts etc.  
Normally when you use a touchscreen on Linux, it simulates a mouse event, which in turn moves the mouse cursor. This for me was not what I wanted, since I would then have to move the cursor back manually.  
This project circumvents this by grabbing the touchscreen input via evdev and then forwards the events to the application. This can of course be toggled to give back the original functionality if you need it.  

## Project status
This project is still a prototype.  
The basic functionality is there but I plan on adding more features.  
Right now the backbone of grabbing the evdev device and simulating the input without moving the mouse is mostly working as intended.  
There is also support for basic buttons, that execute shell scripts or launch programs.  

## Installation
### Building the project
You will need rust/cargo and godot 4 (the latest stable is recommended).
```bash
# Download
## Clone the project
git clone https://github.com/jcronenberg/DreamDeck

# Build for Linux and Windows
make
# Build for just Linux
make linux
# Build for just Windows
make windows
```
The binaries can now be found in `bin/`

### Configuring
The configuration files can be found in `~/.local/share/godot/app_userdata/DreamDeck` after the app was once launched.
You can also specify a custom directory via a cli argument like this `--confdir=local_config` (Note that a `=` is mandatory because of the way godot handles cli arguments).  
The macroboard can be edited in the app via the edit mode or via modifying the config files directly (just be careful when editing these).
Note: icons need to be stored in the config directory in a `icons/` folder and the path in macroboard is relative to that directory.

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

## Used Addons
DreamDeck uses code from some Addons that awesome people made. Huge thanks to these projects:
* [GodotTPD](https://github.com/deep-entertainment/godottpd)
* [GODOT YT-DLP](https://github.com/Nolkaloid/godot-yt-dlp)
* [Better Processes](https://gitlab.com/greenfox/better-processes)
