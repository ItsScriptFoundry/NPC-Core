-- ServerScriptService/NPCSetup.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

-- Create NPC-specific data
local npcData = {
	Health = 100,
	NPC = workspace.NPCs.Villager,
}

-- Initialize the state machine (pass factories directly, not nested)
StateMachine.new(
	"Idle",
	StateMachine.LoadFromFolder(ReplicatedStorage.NPCSystem.Villager.States),
	npcData,
	{ UseHeartbeat = true, Debug = true, HeartbeatInterval = 0 } -- Enable debugging to see warnings
)
