--!strict

--[[
	Type definitions for the Inventory data module.

	Cases  — { [CaseName: string]: number }  e.g. { Covert = 3, Classified = 1 }
	Knives — { [KnifeName: string]: number } e.g. { ["Karambit Fade"] = 2 }
	Cash   — number
]]

-- CaseName matches a RarityName key in shared/CaseSystem/Config.
export type CaseMap  = { [string]: number }
export type KnifeMap = { [string]: number }

export type InventoryTemplate = {
	Knives: KnifeMap,
	Cases:  CaseMap,
	Cash:   number,
}

export type InventoryModule = {
	Name:        string,
	Template:    { [string]: any },
	Init:        (player: Player, context: any) -> (),
	Cleanup:     (player: Player) -> (),
	Set:         (player: Player, key: string, value: any) -> (),
	Get:         (player: Player, key: string) -> any,
	AddCase:     (player: Player, caseName: string) -> (),
	RemoveCase:  (player: Player, caseName: string) -> boolean,
	AddKnife:    (player: Player, knifeName: string) -> (),
}

return nil
