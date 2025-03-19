# ferrum

iron.nvim ripoff

## Usage

- Start REPL session per buffer with `:REPL`  
- Send text to the REPL with `:SendREPL`, or send a range with `'<,'>SendRangeREPL`
- Stop REPL sessions with `:StopREPL`  

See `:h ferrum.txt` for more details

## Plugin Structure

```
ferrum
├── commands.lua
├── core.lua
├── init.lua
└── util.lua
```

## License

WTFPL
