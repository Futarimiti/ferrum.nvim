# ferrum

    <C-[><C-W><C-K>i:r<CR><C-\><C-N><C-W><C-J>i

What that does is to take you out of current working buffer,
enters the GHCi session, reloads everything, and return to where you were.
I'm not having fun typing that every time a change is made,
neither are my pinkies. Time to make a change.

## Usage

### TL;DR

- Start REPL on a buffer with `:REPL` to activate buflocal commands
- Send text with `:Sendln [text]`, send lines in buffer with `:SendRange`
- Ending a session makes buflocal commands unavailable

### Starting

```lua
require('ferrum').setup {}
```

Within a buffer, say `A.hs`, run `:REPL ghci` to spawn a GHCi session.
This launches GHCi linked to `A.hs` buffer in a split window:


    +----------------------------------+
    |ghci>                             |
    |~                                 |
    |~                                 |
    |term://ghci=======================|
    |module A where                    |
    |~                                 |
    |~                                 |
    |A.hs==============================|
    +----------------------------------+

> [!NOTE]
> Similar to [`:Start`](https://github.com/tpope/vim-dispatch),
> by default `:REPL` enters the spawned session.
> To stay in the working buffer, use `:REPL!`.

...and creates several buffer-local commands in `A.hs` buffer
to communicate with GHCi:

- `:SendlnREPL` (`:Sendln` if unambiguous) to send a single line.

    Try `:Sendln :t (>>=)` from `A.hs` buffer:

        +----------------------------------+
        |ghci> :t (>>=)                    |
        |(>>=) :: Monad m => m a -> (a -> m|
        | b) -> m b                        |
        |term://ghci=======================|
        |module A where                    |
        |~                                 |
        |~                                 |
        |A.hs==============================|
        |:Sendln :t (>>=)                  |
        +----------------------------------+

    GHCi uses `:r` to reload all loaded modules. A trick to auto-reload on save:

    ```vim
    autocmd BufWritePost *.hs,*.lhs silent! SendlnREPL :r
    ```

- `:[range]SendRangeREPL` (or `:SendRange`) to send multiple lines in buffer,
  `:'<,'>SendRange` to send visual selected lines.

    > [!NOTE]
    > User may need to wrap up with `:{` and `:}` when sending multiple lines to GHCi.

    Feel free to define a keymap:

    ```vim
    xnoremap <leader>r :SendRangeREPL<CR>
    ```
    ```vim
    " ftplugin/haskell.vim
    xnoremap <buffer> <silent> <leader>r 
            \:<C-U>SendlnREPL :{<CR>
            \:'<,'>SendRangeREPL<CR>
            \:SendlnREPL :}<CR>
    ```

    Yeah I should definitely make a lua API or something, this is tedious

### Multi-client

Each buffer could talk to only one REPL by maximum,
but an active session can be shared.
Use `:LinkREPL` (`:Link` if unambiguous) to connect a buffer to an
existing session. Think of language server and clients.

    +------+
    |      |           
    | A.hs |     :Sendln 3 + 4      +---------+ 
    |      | ---------------------> |         |  
    +------+                        | ghci    |  
    +------+                        | session |  
    |      | ---------------------> |         |
    | B.hs |         :Stop          +---------+  
    |      |    
    +------+

A shared REPL session is controlled by commands from all its clients,
and accepts lines from all the them.
As the session finishes, all the clients are dropped.

### Finishing

`:StopREPL` (`:Stop` if unambiguous) in one of the client buffers finishes the linking session. 
Alternatively the user may `:bwipeout!` the REPL buffer or quit the REPL manually.
Upon doing so, buffer-local commands to interact with the session are removed from each of client buffers.

> [!NOTE]
> `:hid`ing or `:quit`ing the REPL window does not terminate the session,
> hence controls from client buffers are not dropped.
> If the user accidentally closes the session window,
> use `:FocusREPL` (`:Focus` if unambiguous) to bring it back.

See `:h ferrum.txt` for more details.

## FAQ

> I want to split the REPL window sideways, not atop

`:REPL` recognises modifiers.
`:vertical rightbelow REPL` splits rightwards. `:vertical leftabove REPL` splits leftwards.
`:horizontal rightbelow REPL` splits downwards. `:horizontal leftabove REPL` splits upwards.
`:horizontal topleft REPL` splits at top. `:horizontal botright REPL` splits at bottom.
`:tab REPL` opens a new tab.
I hate popups so I probably won't actively support float windows,
but PRs are welcome.

> I want to contribute

Glad to hear! Here's the roadmap:

- [ ] Add end-user lua API
- [ ] User configuration
    - [ ] seriously what's worth configuring?

ferrum is still in the early stages
and I'll be intensively committing
breaking changes in the upcoming weeks.
If you're interested in working on any of the goals above,
please check with me first as I may already be on them!

And of course, bug reports and QoL improvements are always welcome.

## Related projects

#### [iron.nvim](https://github.com/Vigemus/iron.nvim)

ferrum was directly inspired by iron, though only by the name.
I had mix feelings for iron, which led to birth of ferrum
where I'm finally satisfied. *Or am I?* (Michael voice)

#### [dispatch.vim](https://github.com/tpope/vim-dispatch)

dispatch influences several design choices in ferrum.
Additionally I anticipate more integrations
till ferrum eventually becomes an extension of it.

#### [slime.vim](https://github.com/jpalardy/vim-slime)

Well that's awkward. I entirely didn't hear slime until now
I have finished the whole thing, just to find out
what I have done was done years before with 5x times better.
Change of plan: use slime for a while then think of
any improvements to make.

## Licence

WTFPL
