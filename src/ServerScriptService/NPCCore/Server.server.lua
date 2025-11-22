-- ServerScriptService/NPCSetup.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

-- Create NPC-specific data

for _, NPC in workspace.NPCs:GetChildren() do
	local npcData = {
		Health = 100,
		NPC = NPC,
		Interacted = false,
	}
	StateMachine.new(
		"Idle",
		StateMachine.LoadFromFolder(ReplicatedStorage.NPCSystem.Villager.States),
		npcData,
		{ UseHeartbeat = true, Debug = true, HeartbeatInterval = 0 }
	)
end
