# ferrum

iron.nvim ripoff

## Usage

```lua
require('ferrum').setup {}
```

- Start REPL session per buffer with `:REPL`  to activate buflocal commands
- Send text to the REPL with `:Sendln`, or send a range with `'<,'>SendRange`
- Stop REPL sessions with `:Stop`  
- Deactivates buflocal commands when finished

See `:h ferrum.txt` for more details

## FAQ

> I want a vertical split for the REPL window.

`:REPL` accepts modifiers.
`:vertical rightbelow REPL` splits rightwards. `:vertical leftabove REPL` splits leftwards.
`:horizontal rightbelow REPL` splits downwards. `:horizontal leftabove REPL` splits upwards.
`:horizontal topleft REPL` splits at top. `:horizontal botright REPL` splits at bottom.
`:tab REPL` opens a new tab.

## Plugin structure

```
lua/ferrum
├── buffer.lua
├── commands
│   └── buflocal.lua
├── commands.lua
├── core.lua
├── init.lua
├── jobs.lua
└── util.lua
```

## Licence

WTFPL
