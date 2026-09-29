# AGENTS.md

**Read `CLAUDE.md` first.** It holds the full project context (systems, status, world layout, decisions, dev setup)
and is kept up to date. Plan docs are in `docs/`. This file is only the short version.

Bind A Dragon: a Roblox dragon-collecting idle game (Luau, Rojo, 3-person team).

## Key rules
- **Server-authoritative.** RNG, currency, levels, rebirths and rewards are decided on the server only. Clients send
  requests; every RemoteEvent is type-checked, ownership/cost-checked and rate-limited on the server.
- **Config holds all numbers and wording.** Tunable values live in `src/ReplicatedStorage/Shared/Config` (with a
  comment each); UI colors/sizes in `Config/UITheme`, player-facing text in `Config/Text`. Never hard-code them.
- **The world and assets live in the place file, not Git.** Workspace, models, terrain and art are built in Studio;
  only code is in `src/`. Don't delete Studio-only content (e.g. `ServerStorage.Backups`).
- **Rojo is pinned to 7.6.1** (7.7.0 crashes `rojo serve` on temp-file saves). Don't upgrade.
- **No Creator Store scripts.** Store assets are allowed only script-free; delete any scripts inside and report them.
  Nothing third-party decides currency, rewards or RNG.
- **Direct pushes to `main` are OK** (the "must be a pull request" warning is a bypass notice).
- One module per system (`Services/` server, `Controllers/` client, `Init()`/`Start()`), `--!strict` where practical.
- After finishing a system, update the Current status table in `CLAUDE.md`.
