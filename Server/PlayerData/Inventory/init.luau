--!strict

--[[
	Inventory data module.
	Owns Set/Get for the Inventory slice of player data.
	Provides AddCase/RemoveCase/AddKnife helpers for count-based item management.

	Cases  = { [CaseName: string]: number }  (CaseName matches a RarityName in Config)
	Knives = { [KnifeName: string]: number }
	Cash   = number

	Coupled with: PlayerData (parent system — via DataDefinition contract)
]]

local PlayerDataTypes = require(script.Parent.Types)

type DataContext = PlayerDataTypes.DataContext

local Template = {
	Knives = {} :: { [string]: number },
	Cases  = {} :: { [string]: number },
	Cash   = 0,
}

local contexts: { [Player]: DataContext } = {}

-- Validates that a value is a flat { [string]: number } map.
-- Rejects old UUID-keyed entry structs and any non-table junk.
local function isStringNumberMap(value: any): boolean
	if type(value) ~= "table" then return false end
	for k, v in pairs(value) do
		if type(k) ~= "string" or type(v) ~= "number" then
			return false
		end
	end
	return true
end

local Inventory = {
	Name     = "Inventory",
	Template = Template,

	Validators = {
		Knives = isStringNumberMap,
		Cases  = isStringNumberMap,
		Cash   = function(value: any): boolean
			return type(value) == "number"
		end,
	},

	Init = function(player: Player, context: DataContext)
		contexts[player] = context
	end,

	Cleanup = function(player: Player)
		contexts[player] = nil
	end,
}

--------------------------------------------------------------------------------
-- Core Set / Get
--------------------------------------------------------------------------------

function Inventory.Set(player: Player, key: string, value: any)
	assert(Template[key] ~= nil, `Invalid Inventory key "{key}"`)
	assert(value ~= nil, "Cannot set Inventory value to nil. Use an empty table or 0 depending on the key.")
	assert(typeof(value) == typeof(Template[key]), `Invalid type for key "{key}". Expected {typeof(Template[key])}, got {typeof(value)}.`)

	local context = contexts[player]

	if not context then
		warn(`[Inventory] No context for {player.Name}`)
		return
	end

	context.Runtime[key] = value
	context.NotifyChanged(key, value)
end

function Inventory.Get(player: Player, key: string): any
	local context = contexts[player]

	if not context then
		warn(`[Inventory] No context for {player.Name}`)
		return nil
	end

	if Template[key] == nil then
		warn(`[Inventory] Invalid key "{key}"`)
		return nil
	end

	return context.Runtime[key]
end

--------------------------------------------------------------------------------
-- Case helpers  (count-map: Cases[caseName] = count)
--------------------------------------------------------------------------------

function Inventory.AddCase(player: Player, caseName: string)
	local cases = Inventory.Get(player, "Cases") :: { [string]: number }?

	if not cases then
		warn(`[Inventory] No context for {player.Name}`)
		return
	end

	local updated = table.clone(cases)
	updated[caseName] = (updated[caseName] or 0) + 1
	Inventory.Set(player, "Cases", updated)
end

function Inventory.RemoveCase(player: Player, caseName: string): boolean
	local cases = Inventory.Get(player, "Cases") :: { [string]: number }?

	if not cases then
		warn(`[Inventory] No context for {player.Name}`)
		return false
	end

	local current = cases[caseName] or 0
	if current <= 0 then
		return false
	end

	local updated = table.clone(cases)
	if current == 1 then
		updated[caseName] = nil
	else
		updated[caseName] = current - 1
	end
	Inventory.Set(player, "Cases", updated)

	return true
end

--------------------------------------------------------------------------------
-- Knife helpers  (count-map: Knives[knifeName] = count)
--------------------------------------------------------------------------------

function Inventory.AddKnife(player: Player, knifeName: string)
	local knives = Inventory.Get(player, "Knives") :: { [string]: number }?

	if not knives then
		warn(`[Inventory] No context for {player.Name}`)
		return
	end

	local updated = table.clone(knives)
	updated[knifeName] = (updated[knifeName] or 0) + 1
	Inventory.Set(player, "Knives", updated)
end

return table.freeze(Inventory)
