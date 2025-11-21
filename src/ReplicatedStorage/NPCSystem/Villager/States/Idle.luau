--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

return function()
	local Idle = StateMachine.State.new("Idle")
	Idle.Transitions = {
		require(script.Parent.Parent.Transitions.TimePassedToWandering),
	}

	function Idle:OnEnter(Data)
		print(`[{Data.NPC.Name}] Entered Idle`)
		Data.IdleTime = 0 -- Reset timer
	end

	function Idle:OnUpdate(Data, Dt)
		Data.IdleTime = (Data.IdleTime or 0) + Dt
	end

	function Idle:OnLeave(Data)
		print(`[{Data.NPC.Name}] Left Idle after {math.floor(Data.IdleTime)}s`)
	end

	return Idle
end
