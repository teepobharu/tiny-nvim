# Obsidian Vault Audit

## Commands

- `:ObsidianVaultAudit` / `:SnacksObsidianVaultAudit` opens a Snacks picker for Obsidian vault/config cleanup discovery.
- `:ObsidianVaultAudit!` skips filesystem discovery and only shows registry/cache/profile-store items.

## What It Checks

- Obsidian registry: `~/Library/Application Support/obsidian/obsidian.json`
- Discovered `.obsidian` config dirs under common roots: `~/Personal`, `~/Documents`, `~/AgodaGit`, `~/dotfiles`
- Obsidian app cache dirs: `Cache`, `Code Cache`, `GPUCache`, `DawnGraphiteCache`, `DawnWebGPUCache`
- Settings Profiles global store: `~/Library/Application Support/ObsidianPlugins/Profiles`

## Picker Actions

- `<CR>`: open selected vault in Obsidian for vault/orphan-config rows; non-vault rows fall back to revealing the path.
- `<A-o>`: reveal selected filesystem path.
- `<A-y>`: copy item report to clipboard.
- `<A-q>`: quarantine selected config/cache path under `~/.Trash/obsidian-cleanup/YYYYMMDD/`.
- `<A-r>`: remove selected vault from `obsidian.json`; writes a timestamped backup first.
- `<A-x>`: quarantine config and remove registry entry.
- `<C-r>`: refresh audit.

## Cleanup Rules

- Empty `.obsidian` dirs and missing registered vault paths are `dead`.
- Broad roots like `~/Documents` or `~/AgodaGit` are `review`.
- Nested vaults and worktree vaults are `review`.
- Large `.obsidian` dirs outside the main notes vault are `review` because they are likely full seeded configs.
- Cache entries are marked `cache`; quit Obsidian before quarantining them.

## Safety

Actions prompt before mutating anything. File cleanup moves paths to a Trash quarantine folder instead of deleting. Registry removal writes a backup next to `obsidian.json`.
