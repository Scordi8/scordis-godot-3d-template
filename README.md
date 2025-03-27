# Scordi's 3D template for Godot 4.4

## Whats the template for?
This template is what I use as a starting point for most if not all of my 3d projects. it contains several years and revisions worth of stuff that I've found useful in my experiences.
It's not supposed to rival what can be achieved with installing various addons like debug draw, and was created as an internal solution to my problems.
It's tailored to me and my 3d projects, so while all are free to take inspiration (and my code, tho credit would be apprciated), you might be better off starting from scratch or with a different project.

## What's in it?
We got the ConfigHandler, misc Utils, Debug drawing and on-screen text, plus a main menu with a settings screen.
What are those thing, you may ask? well,

### ConfigHandler
The ConfigHandler is a singleton created to handle all the user settings stuff. Using a reference file (user_config_ref.json in content/assets/misc), a config file (.cfg) is created in the user's local files (typically under the appdata folders).
It creates a handful of dictionaries that get used by the menu to construct the settings options, meaning that to add or remove a setting, only the reference json file need to be modified.
There's also an `add_setting` method in it that allows for new settings to be registered during launch when default_config_parsed is emitted, targetting mods.

### Utils
Class Utils is filled with static functions that get used across the project. Various array tools for map, filter, and sort, node and aabb functions, custom warning function to work with the debug singeleton, and position based randomness.

### Debug
The Debug singleton hosts a couple of drawing stuff, such as drawing lines, aabbs, and axis. Alongside that is the Toast system which adds debug messages in the top left corner of the screen.

### And other stuff
the DevCamera, a tool to inspect 3d scenes in-game without launching everything in a specific process, the InputButton for getting mkb inputs for the settings, and the global singleton with callable queues.
