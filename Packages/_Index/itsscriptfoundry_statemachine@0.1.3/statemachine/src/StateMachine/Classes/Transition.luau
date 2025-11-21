local Transition = {}
Transition.__index = Transition
Transition.Type = "Transition"

function Transition.new(TargetStateName: string)
	local self = setmetatable({}, Transition)
	self.Target = TargetStateName
	self.Name = "" -- Optional: set for debugging (e.g., "LowHealthTransition")
	return self
end

-- Override this to define when the transition should fire
-- @return boolean True to trigger state change
function Transition:ShouldTrigger(State, Data)
	return false
end

-- Called when the state machine enters the state containing this transition
function Transition:OnEnter(State, Data) end

-- Called when the state machine leaves the state containing this transition
function Transition:OnLeave(State, Data) end

return Transition
