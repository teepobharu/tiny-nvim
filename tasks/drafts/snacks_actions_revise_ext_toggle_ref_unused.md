
1. Buffers External Filtering + non used
- check if these action want to be used: lua/utils/editor_keymaps.lua:787:11
are these filter duplicate of external of external filter in buffer.transform = function(item, ctx)


2. code ref can we unify Code Reference picker (keymap) and  Select Path Format pickers  (snacks file,buffer action)?
- use just select path format and fix @ format not working properly sample list shown currently 
``` 
Git (colon): lua/utils/editor_keymaps.lua:1464:3                                                                                    
Git (space): lua/utils/editor_keymaps.lua 1464:3                                                                                    
Git (@): @lua/utils/editor_keymaps.lua:1464:3                                                                                       
Git (@caps): @lua/utils/editor_keymaps.lua L1464:C3                                                                                 
Git (#): lua/utils/editor_keymaps.lua#L1464C3                                                                                       
Relative CWD (colon): lua/utils/editor_keymaps.lua:1464:3                                                                           
Relative CWD (space): lua/utils/editor_keymaps.lua 1464:3                                                                           
Relative CWD (@): @lua/utils/editor_keymaps.lua:1464:3                                                                              
Relative CWD (@caps): @lua/utils/editor_keymaps.lua L1464:C3                                                                        
Relative CWD (#): lua/utils/editor_keymaps.lua#L1464C3                                                                              
Absolute (colon): /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua:1464:3                     
Absolute (space): /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua 1464:3                     
Absolute (@): @/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua:1464:3                        
Absolute (@caps): @/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua L1464:C3                  
Absolute (#): /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua#L1464C3                                         
```
  

3. check toggle external logic on buffers by default to only exclude non cwd git dir files, and <a-shift-e> to toggle between this possibility : vim.g subproject marker or cwd (this toggle will not persist between pickers)
- check in files picker if similar logic can be applied into file picker
