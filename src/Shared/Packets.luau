--!strict

--[[
	ByteNet namespace for the PlayerData system.
	Defines all packets used for client-server data communication.

	Coupled with: ByteNet
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("PlayerData", function()
	return {
		GetRequest = ByteNet.definePacket({
			value = ByteNet.struct({
				Module = ByteNet.string,
				Key = ByteNet.string,
			}),
		}),

		GetResponse = ByteNet.definePacket({
			value = ByteNet.struct({
				Module = ByteNet.string,
				Key = ByteNet.string,
				Value = ByteNet.unknown,
			}),
		}),

		DataChanged = ByteNet.definePacket({
			value = ByteNet.struct({
				Module = ByteNet.string,
				Key = ByteNet.string,
				Value = ByteNet.unknown,
			}),
		}),

		Initialized = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
	}
end)
