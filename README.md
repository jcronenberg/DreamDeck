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
