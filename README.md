# DreamDeck
DreamDeck is a versatile Macroboard software tailored for touchscreen devices, distinguishing itself from Stream Decks and similar software by leveraging the entire screen, offering more than just simple button displays.

![image](https://github.com/jcronenberg/DreamDeck/assets/54934253/996e89e4-4991-4f19-ad1f-5c928e267af9)

## Project status
DreamDeck is in a prototype stage, so expect potential breaking changes. Use it at your own discretion.  
While the basic functionality is implemented, there are significant features yet to be added before the software reaches the alpha stage.  
Feedback and contributions are of course always welcome.

### Current features
* Local shell buttons
* SSH buttons
* Spotify integration
* Linux exclusive touch

## Installation
### Building the project
To build DreamDeck, ensure you have Rust/Cargo and Godot 4 (latest stable version recommended) with the corresponding export templates installed.
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
The configuration files can be found in `~/.local/share/dreamdeck` after the app was once launched.
You can also specify a custom directory via a cli argument like this `--confdir=local_config` (Note that a `=` is mandatory because of the way godot handles cli arguments).  
It is not recommended to edit the config files yourself.  

## Plugins
### Linux exclusive touch
Normally when using a touchscreen on linux, it automatically also moves the mouse. DreamDeck let's you circumvent this by grabbing the touch device via evdev and then interpreting the touch events.  
This is only recommended for devices with more than 1 monitor connected.

## Used Addons
DreamDeck uses code from some Addons that awesome people made. Huge thanks to these projects:
* [GodotTPD](https://github.com/deep-entertainment/godottpd)
* [GODOT YT-DLP](https://github.com/Nolkaloid/godot-yt-dlp)
* [Better Processes](https://gitlab.com/greenfox/better-processes)
* [Godot UUID](https://github.com/binogure-studio/godot-uuid)
* [Dockable Container](https://github.com/gilzoide/godot-dockable-container)
* [ReorderableContainer](https://github.com/FoolLin/ReorderableContainer)
