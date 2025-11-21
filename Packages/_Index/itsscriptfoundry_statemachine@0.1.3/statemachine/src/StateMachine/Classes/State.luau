local State = {}
State.__index = State
State.Type = "State" -- Added for consistency

function State.new(Name: string)
	local self = setmetatable({}, State)
	self.Name = Name or ""
	self.Transitions = {} -- Array of factory functions returning Transition instances
	return self
end

-- Called when entering this state
function State:OnEnter(Data) end

-- Called when leaving this state
function State:OnLeave(Data) end

-- Called every heartbeat tick (if enabled) while this is the current state
function State:OnUpdate(Data, Dt) end

-- Called when machine.Data changes while this is the current state
function State:OnDataChanged(Data, Key, NewValue, OldValue) end

-- Return false to prevent transitioning out of this state
function State:CanChangeState(TargetStateName)
	return true
end

return State
