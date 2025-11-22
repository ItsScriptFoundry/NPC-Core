local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

return function()
	local PlayerInteraction = StateMachine.Transition.new("Interacted")

	function PlayerInteraction:ShouldTrigger(State, Data)
		local NPC = Data.NPC
		if not NPC or not NPC:FindFirstChild("HumanoidRootPart") then
			warn("Rejected because NPC doesn't exist.")
			return false
		end

		return Data.Interacted
	end

	return PlayerInteraction
end
