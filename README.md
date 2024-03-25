# Structural Lua Editor

A "structural editor", letting you efficiently edit your code as a tree rather than just text.

### Controls
- e, d, s, f to move up, down, left, right
- i, j, k, l to insert up, down, left, right
- space to insert on the currently selected block
- backspace to delete currently selected block
- x, c, and v are cut, copy, and paste
- ctrl-s to save
- escape to get out of insert mode

If the text you insert matches the name of a block, that block will be inserted instead.
For example, type "fn" and then press enter while in insert mode to create a function.

### Unimplemented Stuff (So far)
- Undo/Redo
- Support for multiple files (and files not named "save.lua")
- Support for more Lua constructs
- Support for customization
- Support for multiple languages
- Probably a bunch of stuff, but these are the main points

### Setup
- Download [Lyte2D](https://github.com/lyte2d/lyte2d), currently tested with version 0.7.11.
- Download [DejaVu Sans](https://dejavu-fonts.github.io/) and place `DejaVuSans.ttf` in this directory. (You need to have a font file in `ttf` form in this directory, but if you know what you're doing you can modify `graphics.lua` to use a font other than `DejaVuSans`).
- Run `lyte.exe .` in this directory.