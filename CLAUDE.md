Editing / Coding Guidelines

- Do not remove any code comments unless instructed to do or required as the implementation make the comment obsolete.
- Avoid adding in existing ./lua/plugins/\*.lua unless required to
- myEditor currently contains most overridden user config for the plugins, but ideally the plugins should be inside plugins/extra/my<plugin_name>.lua we can slowly migrate this - not urgent, for new overridden that has not been specified in my\*.lua prefix can start putting on that
- For plugin configuration overrides, use files named plugins/extra/my<plugin_name>.lua. This helps separate personal changes from upstream configurations.
- When adding new overrides, prefer creating a my\*.lua file with the "my" prefix to avoid conflicts with updates from the original plugin author.
- Only modify plugins/\*.lua directly if necessary (e.g., when deep merging config is not possible (e.g functions and not table). In such cases, move custom code to lua/plugins/extras/ or lua/utils/ as appropriate. If placed in /extras, ensure it is imported in the relevant entry point.
- when asked to work on spec on docs/\*.md update the detail of and short description in shortlist with code References hyperlink made
- when ask to DIGDEEP one of the reliable source for installed plugins source code can be found in ~/.local/share/$NVIM_APPNAME/lazy/<plugin_name> (ie. ~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/)
- When working with plugin configurations or editing Vim/Lua files, be vigilant for common caveats, patterns, or recurring issues. Whenever you encounter a problem and its solution, document both the issue and the fix in `docs/memory/<plugin_name>.md`. Keep it clean and concise. Regularly update this document with new insights, corrections to previous mistakes, and any useful tips discovered. Treat this as a living resource—continually review and amend it to ensure accuracy and usefulness for future reference.

Task Tracking Workflow

- Keep user in the loop to verify changes work with checkbox, then iterate to fix if needed on failed cases
- Follow tasks/ folder structure for status management:
  - `tasks/open/` - New tasks ready to start
  - `tasks/wip/` - Work in progress
  - `tasks/review/` - Awaiting user verification
  - `tasks/done/` - Completed and verified
  - `tasks/drafts/` - Task ideas and planning
- **Link Format Rule**: All file links in task files MUST use paths relative to git root WITHOUT `../` prefix
  - ✓ Correct: `[File](lua/utils/snacks_actions.lua)`
  - ✗ Wrong: `[File](../../lua/utils/snacks_actions.lua)`
- See [Task Tracking Guide](docs/task_tracking.md) for detailed templates, frontmatter format, and workflow
