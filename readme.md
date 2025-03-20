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

## Plugin structure

```
ferrum
├── commands.lua
├── core.lua
├── init.lua
└── util.lua
```

## Licence

WTFPL
