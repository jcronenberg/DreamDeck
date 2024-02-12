# DreamDeck
DreamDeck is a versatile Macroboard software designed for touchscreen devices, offering functionality similar to that of a Stream Deck.

![image](https://github.com/jcronenberg/DreamDeck/assets/54934253/996e89e4-4991-4f19-ad1f-5c928e267af9)

## Project status
DreamDeck is currently in a prototype stage. While the basic functionality is implemented, ongoing development will introduce additional features.  
Current features include:
* Local shell buttons
* SSH buttons
* Spotify integration
* Linux exclusive touch

## Installation
### Building the project
To build DreamDeck, ensure you have Rust/Cargo and Godot 4 (latest stable version recommended) installed.
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
The binary and libraries can now be found in `bin/`  
On linux you can now also install via `make install`

### Configuring
In the main menu, plugins can be enabled and disabled. You can also enter edit mode, which let's you configure the Macroboard plugin.  
The configuration files can be found in `~/.local/share/godot/app_userdata/DreamDeck` after the app was once launched.
You can also specify a custom directory via a cli argument like this `--confdir=local_config` (Note that a `=` is mandatory because of the way godot handles cli arguments).  
It is not recommended to edit the config files yourself.  
Note: Icons for buttons need to be stored in the config directory at `~/.local/share/godot/app_userdata/DreamDeck/icons/` folder and the path in buttons is relative to this directory.

## Plugins
### Connect to Spotify's API
1. Go to the [Spotify dashboard](https://developer.spotify.com/dashboard/applications)
1. Click `Create an app`
    - Note down your `Client ID` and `Client Secret`
1. Click on `Edit Settings`
1. Add `http://localhost:8888/callback` to the Redirect URIs
1. Scroll down and click `Save`
1. You are now ready to authenticate with Spotify! Follow instructions shown by DreamDeck

### Linux exclusive touch
Normally when using a touchscreen on linux, it automatically also moves the mouse. DreamDeck let's you circumvent this by grabbing the touch device via evdev and then interpreting the touch events.  
This is only recommended for devices with more than 1 monitor connected.

## Used Addons
DreamDeck uses code from some Addons that awesome people made. Huge thanks to these projects:
* [GodotTPD](https://github.com/deep-entertainment/godottpd)
* [GODOT YT-DLP](https://github.com/Nolkaloid/godot-yt-dlp)
* [Better Processes](https://gitlab.com/greenfox/better-processes)
