# pet.nvim

Bring a *pet party* to your mundane text editing - release the pets to **waddle** across your editor!

![demo](demo.gif)

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API](#api)
- [Options](#options)
- [Inspiration](#inspiration)

## Features

- playful pets *wander* across your screen
- pick *your own pet*
- your well-mannered companions *respect* your workspace, keeping their *paws off your text* (and line numbers, status lines etc)
- your friends *follow you* across the *windows*, and will start appearing wherever currently you are

## Installation

<details>
  <summary>lazy.nvim</summary>

Add the following to your `lazy.nvim` config:

```lua
{
    "rhusiev/pet.nvim",
    config = function()
        require("pet").start_pet_party() -- To start the party when you open Neovim
    end,
}
```

</details>

<details>
  <summary>packer.nvim</summary>

Add the following to your `packer.nvim` config:

```lua
use {
    "rhusiev/pet.nvim",
    config = function()
        require("pet").start_pet_party() -- To start the party when you open Neovim
    end,
}
```

</details>

<details>
  <summary>vim-plug</summary>

Add the following to your `vim-plug` config:

```vim
Plug 'rhusiev/pet.nvim'
```

</details>

## Quick Start

Run `:PetStartParty` to start the party!

To stop the party - `:PetStopParty`, to add just one pet - `:PetAdd`.

## API

There is a lua API to handle the party with more control:

```lua
require("pet").start_pet_party() -- Start the party
require("pet").stop_pet_party() -- Stop the party
require("pet").add_pet() -- Add a single pet
```

Some useful helper functions to build customization around the plugin:

```lua
local pet_utils = require("pet.utils")

-- Convert x relative to a window to absolute (relative to the whole editor)
pet_utils.to_absolute_x(x, attached_to_wininfo)
-- Convert x absolute (relative to the whole editor) to relative to a window
pet_utils.to_relative_x(x, attached_to_wininfo)
-- Convert y relative to a window to absolute (relative to the whole editor)
pet_utils.to_absolute_y(y, attached_to_wininfo)
-- Convert y absolute (relative to the whole editor) to relative to a window
pet_utils.to_relative_y(y, attached_to_wininfo)
-- Convert x and y relative to a window to absolute (relative to the whole editor)
pet_utils.to_absolute(x, y, attached_to_wininfo)
-- Convert x and y absolute (relative to the whole editor) to relative to a window
pet_utils.to_relative(x, y, attached_to_wininfo)
-- Draw a character at x,y position for a certain amount of time
pet_utils.draw_mark(x, y, char, time, attached_to_wininfo)
```

For documentation, see [utils.lua](lua/pet/utils.lua)

## Options

You can add configuration when starting a party or adding a pet. Here are the default values of the config:

```lua
require("pet").start_pet_party({
    -- The maximum number of pets simultaneously in the party
    max_pets = 4,

    -- The period in milliseconds at which a pet is spawned
    -- (if there still is some room in the party)
    spawn_period = 2000,
    -- The period in milliseconds at which a pet will move
    step_period = 150,
    -- The time in milliseconds before the first pet appears
    wait_period = 1000,

    -- The string to use as a pet
    pet_string = "🐧",
    -- How many characters does a string visually occupy
    -- If not present, defaults to the length lua provides, which is the length in bytes, so is not always accurate
    pet_length = #"🐧",

    -- The number of moves a pet does before disappearing
    repeats = 100,

    -- The minimum number of spaces at the window edges,
    -- around which a pet can not move
    min_skip_left = 0,
    min_skip_right = 0,
    min_skip_above = 0,
    min_skip_below = 0,

    -- Whether to avoid moving over text
    avoid_text = true,
    -- A function that takes a pet and its coordinates and outputs new coordinates. By default it moves in the same direction as previously and with some probability changes its direction. Additionally, with some probability a pet might stop moving.
    move_function = default_moving_function,
})
```

You can also find all the default values at `lua/pet/defaults.lua`.

The same config can be passed to `require("pet").add_pet()`, with the exception of `max_pets` and `spawn_period`, which will be ignored.

## Move function

The default move function moves in the same direction as previously and with some probability changes its direction. Additionally, with some probability a pet might stop moving.

You can write your own function. It should take a pet as the first argument, `x` as a second one and `y` as the third one. `x` and `y` are relative to the window. You can use `pet.state` as a table with a state that will be preserved till the next invocation of the function. However, as there is no state during the first invocation, a recommended practice is to check `if pet.state == nil` at the beginning of the function and state the default state there. For example, the default implementation uses:

```lua
if pet.state == nil then
    pet.state = {
        moving = true,
        direction = math.random(4),
    }
end
```

to set the starting direction of movement and the variable `moving` to `true`, which represents whether the pet is moving at the moment.

You can find more about the `pet` table at the [API](#API) section.

The default implementation of the function can be found at `lua/pet/defaults.lua`, as well as other default values.

There are also some helper functions, notably to translate between relative (to the window) and absoulte (relative to the whole editor) coordinates. You can find them at `lua/pet/utils.lua` or at the [API](#API) section.

## Inspiration

The original idea comes from [duck.nvim](https://github.com/tamton-aquib/duck.nvim)

I wanted to change the behavior completely, so I decided to write my own plugin.
