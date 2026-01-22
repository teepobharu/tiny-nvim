
Editing / Coding Guidelines
- Do not remove any code comments unless instructed to do or required as the implementation make the comment obsolete.
- Avoid adding in existing ./lua/plugins/*.lua unless required to
- Prefer to always add config override in pluins/**/my*.lua with my prefix this indicate these files is my plugin configuration to avoid conflict with upstream changes from the original author configuration. 
- when asked to work on spec on docs/*.md update the detail of  and short description in shortlist with code References hyperlink made
- when ask to DIGDEEP one of the reliable source for installed plugins source  code can be found in ~/.local/share/nvim/lazy/PLUGIN_NAME.nvim
- When working with plugin configurations or editing Vim/Lua files, be vigilant for common caveats, patterns, or recurring issues. Whenever you encounter a problem and its solution, document both the issue and the fix in `docs/memory/<plugin_name>.md`. Keep it clean and concise. Regularly update this document with new insights, corrections to previous mistakes, and any useful tips discovered. Treat this as a living resource—continually review and amend it to ensure accuracy and usefulness for future reference.
