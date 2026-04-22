--!strict

--[[
	Shared type definitions for the PlayerData packet payloads.
	Used by both client and server to type ByteNet communication.
]]

export type GetRequestPayload = {
	Module: string,
	Key: string,
}

export type GetResponsePayload = {
	Module: string,
	Key: string,
	Value: unknown,
}

export type DataChangedPayload = {
	Module: string,
	Key: string,
	Value: unknown,
}

return nil
