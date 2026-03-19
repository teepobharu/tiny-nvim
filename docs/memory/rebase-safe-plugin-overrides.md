# Rebase-Safe Plugin Override Pattern

Keep local behavior out of upstream files whenever possible.

## Rule of thumb

- `lua/plugins/*.lua` = upstream/base specs
- `lua/plugins/extra/my*.lua` = local domain overrides
- `lua/plugins/extra/xx*.lua` = grouped mute switches
- `lua/plugins/extra/disablePlugins.lua` = single-plugin final disable layer

## Ownership

- Put AI tools in `myAi.lua`
- Put coding/completion/formatting in `myCoding.lua`
- Put UI/menu/status/tabline overrides in `myUi.lua`
- Put snacks picker/explorer/dashboard overrides in `mySnacks.lua`
- Leave `myEditor.lua` for editor-core items that do not yet have a better domain home

## Toggle strategy

- Use `vim.g.disabled_plugins` only for single-file plugins or project-local overrides
- Use `xx*.lua` when the upstream file owns a group of related specs and needs a named mute switch
- Load `disablePlugins` last so its `enabled = false` fragments win predictably

## Naming

- `my<Name>.lua` = owning override module
- `xx<Name>.lua` = hard-off group toggle
- avoid adding new local behavior directly to upstream files unless the upstream layout gives no safer seam
