# PlayerData

A reusable, module-based player data system for Roblox. Designed to be dropped into any project as a Git submodule — add it once, extend it with game-specific modules.

---

## Requirements

- [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) — handles data persistence
- [ByteNet](https://github.com/ffrostflame/ByteNet) — handles client-server replication via the Packets definition in Shared

Both must be installed in your project before this system will work.

---

## Structure

```
PlayerData/
├── Server/
│   └── PlayerData/         → place into ServerScriptService
│       └── Inventory/      → example module, replace with your own
└── Shared/
    └── PlayerData/         → place into ReplicatedStorage
```

**Server** owns the data lifecycle — ProfileStore sessions, module discovery, validation, and replication. Nothing outside this layer touches data directly.

**Shared** owns the network contract — the Packets definition lives here because both the server and client need to reference it. Keeping it in ReplicatedStorage means the client can communicate with the system without depending on any server-side code.

---

## Adding to a Project

### 1 — Add as a submodule

```bash
git submodule add https://github.com/koze/PlayerData.git modules/PlayerData
```

### 2 — Point Rojo at it

In your game's `default.project.json`:

```json
"ServerScriptService": {
  "$path": "modules/PlayerData/Server"
},
"ReplicatedStorage": {
  "$path": "modules/PlayerData/Shared"
}
```

Rojo places `Server/PlayerData` into `ServerScriptService` and `Shared/PlayerData` into `ReplicatedStorage` automatically.

### 3 — Install dependencies via Wally

In your game's `wally.toml`:

```toml
[dependencies]
ProfileStore = "madstudioroblox/profilestore@^1.0.0"
ByteNet = "ffrostflame/bytenet@^0.1.0"
```

Then run:

```bash
wally install
```

---

## Adding a Module

Modules are `ModuleScript`s placed inside `Server/PlayerData/`. The system discovers them automatically — no registration code needed.

Every module must follow this structure or it will be rejected at load:

```lua
--!strict

local MyModule = {}

local playerContexts: { [Player]: DataContext } = {}

-- Required: unique name, used as the key your data is stored under in ProfileStore.
MyModule.Name = "MyModule"

-- Required: defines the data shape and default values.
MyModule.Template = {
    Level = 1,
    Experience = 0,
}

-- Optional: per-key validators.
-- If omitted, falls back to typeof matching against the Template.
MyModule.Validators = {
    Level = function(value: any): boolean
        return type(value) == "number" and value >= 1
    end,
    Experience = function(value: any): boolean
        return type(value) == "number" and value >= 0
    end,
}

-- Required: called when the player's profile is loaded.
-- context.Runtime is a direct reference to this module's data in the profile.
-- context.NotifyChanged replicates a key/value change to the client.
function MyModule.Init(player: Player, context: DataContext)
    playerContexts[player] = context
end

-- Required: called when the player leaves or the session ends.
-- Must clean up any per-player state your module holds.
function MyModule.Cleanup(player: Player)
    playerContexts[player] = nil
end

return MyModule
```

### Exposing a Public API

External scripts require the module directly and call its functions:

```lua
function MyModule.AddExperience(player: Player, amount: number)
    local context = playerContexts[player]
    if not context then return end

    context.Runtime.Experience += amount
    context.NotifyChanged("Experience", context.Runtime.Experience)
end
```

Then from any server script:

```lua
local MyModule = require(ServerScriptService.PlayerData.MyModule)
MyModule.AddExperience(player, 100)
```

Guards against invalid input, missing players, or corrupt state belong inside the module itself.

---

## Module Rules

- `Name` must be unique across all modules. **Never rename it after shipping** — renaming orphans existing player data.
- `Template` defines both shape and defaults. Keys missing from the Template are removed on load. Keys with invalid values are reset to the Template default.
- `Validators` are optional but recommended for anything beyond simple primitives.
- `Cleanup` must release all per-player state. An empty or missing Cleanup causes memory leaks.

---