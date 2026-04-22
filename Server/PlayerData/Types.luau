--!strict

--[[
	Server-side type definitions for the PlayerData system.

	DataContext — passed to child modules on player init so they can read/write runtime data.
	DataDefinition — the contract that child data modules must satisfy.
]]

export type DataContext = {
	Runtime: { [string]: any },
	NotifyChanged: (key: string, value: any) -> (),
}

-- Per-key validator functions.  Return true = value is acceptable, false = reset to template default.
export type KeyValidators = { [string]: (value: any) -> boolean }

export type DataDefinition = {
	Name:       string,
	Template:   { [string]: any },
	-- Optional: if absent, falls back to a plain typeof() check.
	Validators: KeyValidators?,
	Init:       (player: Player, context: DataContext) -> (),
	Cleanup:    (player: Player) -> (),
}

return nil
