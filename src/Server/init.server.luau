--!strict

--[[
	PlayerData server orchestrator.

	- Dynamically discovers child data modules (DataDefinition) and merges their templates.
	- Manages ProfileStore sessions for each player.
	- Passes DataContext to each child module so they own their own Set/Get.
	- Listens for ByteNet GetRequest packets and responds with data.
	- Sends Initialized packet to the client after first sync.

	Coupled with: ProfileStore, ByteNet (via shared Packets), child DataDefinition modules
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Packets = require(ReplicatedStorage.Shared.PlayerData.Packets)
local Types = require(script.Types)

type DataDefinition = Types.DataDefinition
type DataContext = Types.DataContext

--------------------------------------------------------------------------------
-- Child module discovery
--------------------------------------------------------------------------------

local definitions: { DataDefinition } = {}
local fullTemplate: { [string]: { [string]: any } } = {}

for _, child in script:GetChildren() do
	if not child:IsA("ModuleScript") then
		continue
	end

	local childModule = require(child) :: any

	if type(childModule) ~= "table" then
		continue
	end

	if childModule.Name == nil or childModule.Template == nil then
		continue
	end

	local definition = childModule :: DataDefinition
	table.insert(definitions, definition)
	fullTemplate[definition.Name] = table.clone(definition.Template)
	print(`[PlayerData] Registered data module: {definition.Name}`, "Template:", definition.Template)
end

print(`[PlayerData] Registered {#definitions} data module(s)`)

--------------------------------------------------------------------------------
-- ProfileStore
--------------------------------------------------------------------------------

local playerStore = ProfileStore.New("PlayerData", fullTemplate)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local activeProfiles: { [Player]: any } = {}

--------------------------------------------------------------------------------
-- Initial sync — pushes all current values to the client, then Initialized
--------------------------------------------------------------------------------

local function syncAllToClient(player: Player, profile: any)
	for _, definition in definitions do
		local runtimeRef = profile.Data[definition.Name]

		for key, value in runtimeRef do
			Packets.DataChanged.sendTo({
				Module = definition.Name,
				Key = key,
				Value = value,
			}, player)
		end
	end

	Packets.Initialized.sendTo(nil, player)
end

--------------------------------------------------------------------------------
-- Player lifecycle
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = playerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Failed to load data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

    

	profile.OnSessionEnd:Connect(function()
		for _, definition in definitions do
			definition.Cleanup(player)
		end

		activeProfiles[player] = nil
		player:Kick("Session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	activeProfiles[player] = profile

	for _, definition in definitions do
		local name = definition.Name
		local runtimeRef: { [string]: any } = profile.Data[name]
        
		local context: DataContext = {
			Runtime = runtimeRef,
			NotifyChanged = function(key: string, value: any)
				Packets.DataChanged.sendTo({
					Module = name,
					Key = key,
					Value = value,
				}, player)
			end,
		}
		for key, value in runtimeRef do
			if definition.Template[key] == nil then
				warn(`[PlayerData] Unknown key "{key}" in module "{name}" for {player.Name} — removing.`)
				runtimeRef[key] = nil
				continue
			end

			local validators = definition.Validators
			local validator  = validators and validators[key]

			local ok: boolean
			if validator then
				ok = validator(value)
			else
				-- Fallback: plain typeof match (covers primitives with no explicit validator).
				ok = typeof(value) == typeof(definition.Template[key])
			end

			if not ok then
				warn(`[PlayerData] Invalid value for key "{key}" in module "{name}" for {player.Name} — resetting to template default.`)
				runtimeRef[key] = nil
			end
		end
        
		profile:Reconcile() -- Reset any unexpected keys to match the template

		definition.Init(player, context)
	end

	syncAllToClient(player, profile)

	print(`[PlayerData] Loaded profile for {player.Name}`)
    -- Uncomment to debug profile data on player join
    print(`[PlayerData] profile of {player.Name} is `, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = activeProfiles[player]

	if profile then
		profile:EndSession()
	end

	for _, definition in definitions do
		definition.Cleanup(player)
	end

	activeProfiles[player] = nil
end

--------------------------------------------------------------------------------
-- ByteNet listeners
--------------------------------------------------------------------------------

Packets.GetRequest.listen(function(data: { Module: string, Key: string }, player: Player?)
	if not player then
		return
	end

	local profile = activeProfiles[player]

	if not profile then
		return
	end

	local moduleData = profile.Data[data.Module]

	if not moduleData then
		return
	end

	local value = moduleData[data.Key]

	Packets.GetResponse.sendTo({
		Module = data.Module,
		Key = data.Key,
		Value = value,
	}, player)
end)

--------------------------------------------------------------------------------
-- Connect lifecycle
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
