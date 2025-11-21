--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

return function()
	local TimePassed = StateMachine.Transition.new("Wandering")
	TimePassed.Name = "IdleToWander"

	function TimePassed:ShouldTrigger(State, Data)
		if (Data.IdleTime or 0) < 3 then
			return false
		end

		-- 10% chance per check
		return math.random(1, 10) == 1
	end

	return TimePassed
end
