--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

return function()
	local TimePassed = StateMachine.Transition.new("Idle")
	TimePassed.Name = "WanderToIdle"

	function TimePassed:ShouldTrigger(State, Data)
		-- Must have been wandering for at least 5 seconds
		local wanderTime = Data.WalkData and (tick() - Data.WalkData.LastMoveTime) or 0
		if wanderTime < 5 then
			return false
		end

		-- 10% chance per check
		return math.random(1, 10) == 1
	end

	return TimePassed
end
