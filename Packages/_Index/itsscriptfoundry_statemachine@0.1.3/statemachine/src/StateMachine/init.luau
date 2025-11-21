local RunService = game:GetService("RunService")
local Signal = require(script.Utility.Signal)
local Janitor = require(script.Utility.Janitor)

local StateMachine = {}
StateMachine.__index = StateMachine

-- Each state and transition class is expected to expose a constructor-style function.
StateMachine.State = require(script.Classes.State)
StateMachine.Transition = require(script.Classes.Transition)

function StateMachine.new(InitialStateName, StateFactories, Data, Options)
	assert(type(InitialStateName) == "string", "InitialStateName must be string")
	assert(type(StateFactories) == "table", "StateFactories must be table of factory functions")

	-- Create the state machine core object
	local self = setmetatable({}, StateMachine)
	self._Janitor = Janitor.new()
	self._States = {} -- Holds name → state object
	self._Current = nil
	self._Previous = nil
	self._IsChangingState = false -- Used to prevent re-entrant transitions
	self._Destroyed = false

	-- Apply options with defaults
	self._Options = { UseHeartbeat = false, HeartbeatInterval = 0, Debug = false }
	if Options then
		-- Shallow copy so user can override any field
		for K, V in pairs(Options) do
			self._Options[K] = V
		end
	end
	self._Debug = self._Options.Debug
	self._WarnErrors = self._Options.WarnErrors or false

	-- Data table is user-defined, copied to avoid unexpected external mutation
	self.Data = {}
	if Data then
		for K, V in pairs(Data) do
			self.Data[K] = V
		end
	end

	-- Events for observers to listen to
	self.StateChanged = Signal.new()
	self.DataChanged = Signal.new()

	--[[ 
		Build each state by running its factory function.
		We also attach a Janitor to each state for any temporary
		connections created while that state is active.
	]]
	for _, Factory in ipairs(StateFactories) do
		assert(type(Factory) == "function", "StateFactories must be functions")
		local State = Factory()

		assert(type(State.Name) == "string", "State factory must define State.Name")
		assert(self._States[State.Name] == nil, "Duplicate state name: " .. State.Name)

		-- Link state back to this machine
		State._Machine = self
		State._Janitor = Janitor.new()

		-- Build transition instances for this state
		local Instances = {}
		if type(State.Transitions) == "table" then
			for _, TFactory in ipairs(State.Transitions) do
				assert(type(TFactory) == "function", "Transition must be a factory function")
				local T = TFactory()
				T._State = State -- Backref for context
				table.insert(Instances, T)
			end
		end
		State._Transitions = Instances
		self._States[State.Name] = State
	end

	-- Validate transition targets
	for _, State in pairs(self._States) do
		for _, T in ipairs(State._Transitions) do
			if type(T.Target) == "string" then
				assert(
					self._States[T.Target],
					string.format("Transition target '%s' not found in state '%s'", T.Target, State.Name)
				)
			end
		end
	end

	-- The initial state must actually exist
	assert(self._States[InitialStateName], "Initial state not found: " .. InitialStateName)

	-- If heartbeat updates are enabled, schedule periodic updates
	if self._Options.UseHeartbeat then
		local Last = 0
		local Conn = RunService.Heartbeat:Connect(function(Dt)
			if self._Destroyed then
				return
			end

			-- Accumulate time so user can throttle updates
			Last = Last + Dt
			local Interval = self._Options.HeartbeatInterval or 0
			if Interval == 0 or Last >= Interval then
				Last = 0
				self:_OnHeartbeat(Dt)
			end
		end)
		self._Janitor:Add(Conn)
	end

	-- Enter the initial state immediately
	self:_changeStateInternal(InitialStateName, true)

	return self
end

function StateMachine:_OnHeartbeat(Dt)
	-- Skip updates if destroyed or if current state vanished unexpectedly
	if self._Destroyed then
		return
	end
	local State = self._States[self._Current]
	if not State then
		return
	end

	-- Call per-frame update if provided by the state
	if type(State.OnUpdate) == "function" then
		State.OnUpdate(State, self.Data, Dt)
	end

	-- Evaluate transitions to see if any should trigger this frame
	for _, T in ipairs(State._Transitions) do
		if type(T.ShouldTrigger) == "function" then
			local Ok, Should = pcall(T.ShouldTrigger, T, State, self.Data)
			if Ok and Should then
				-- Only transition if the target is valid
				if type(T.Target) == "string" and self._States[T.Target] then
					self:ChangeState(T.Target)
					return -- Prevent multiple transitions in one update
				end
			elseif not Ok then
				-- Error from user's ShouldTrigger
				local ErrorMsg =
					string.format("StateMachine error in ShouldTrigger for state '%s': %s", State.Name, Should)
				if self._Debug or self._WarnErrors then
					warn(ErrorMsg)
				end
			end
		end
	end
end

function StateMachine:GetCurrentState()
	-- Return the name, or empty string if none
	return self._Current or ""
end

function StateMachine:GetPreviousState()
	return self._Previous or ""
end

function StateMachine:ChangeData(Key, NewValue)
	-- Update user data and propagate change events
	if self._Destroyed then
		return
	end

	local Old = self.Data[Key]
	if Old == NewValue then
		return -- No change, avoid unnecessary calls
	end

	self.Data[Key] = NewValue

	-- Notify current state first if it cares about data changes
	local State = self._States[self._Current]
	if State and type(State.OnDataChanged) == "function" then
		task.spawn(State.OnDataChanged, State, self.Data, Key, NewValue, Old)
	end

	-- Then fire the public event
	self.DataChanged:Fire(self.Data, Key, NewValue, Old)
end

function StateMachine:ChangeState(NewState)
	-- Public entry point for state changes
	if self._Destroyed then
		return
	end
	assert(type(NewState) == "string", "ChangeState expects string")
	assert(self._States[NewState], "State not found: " .. tostring(NewState))

	-- Prevent nested or simultaneous transitions
	if self._IsChangingState then
		if self._Debug then
			warn(string.format("StateMachine:ChangeState('%s') called during state transition, ignoring", NewState))
		end
		return
	end

	local Current = self._States[self._Current]
	if Current and type(Current.CanChangeState) == "function" then
		-- Give the current state a say in whether it's allowed to transition
		local Ok, Allowed = pcall(Current.CanChangeState, Current, NewState)
		if Ok and not Allowed then
			return -- Transition blocked by user logic
		elseif not Ok then
			local ErrorMsg =
				string.format("StateMachine error in CanChangeState for state '%s': %s", Current.Name, Allowed)
			if self._Debug or self._WarnErrors then
				warn(ErrorMsg)
			end
		end
	end

	-- Execute the transition with safety
	self._IsChangingState = true
	local Success, Error = pcall(function()
		self:_changeStateInternal(NewState, false)
	end)
	self._IsChangingState = false

	if not Success then
		local ErrorMsg = string.format("StateMachine error during state change to '%s': %s", NewState, Error)
		if self._Debug or self._WarnErrors then
			warn(ErrorMsg)
		end
	end
end

function StateMachine:_changeStateInternal(NewState, _IsInitial)
	-- Internal transition handler, does all enter/leave work
	local Prev = self._States[self._Current]
	local NextState = self._States[NewState]

	-- Leave previous state, if it exists
	if Prev then
		if type(Prev.OnLeave) == "function" then
			Prev.OnLeave(Prev, self.Data)
		end

		-- Let transitions clean up if they defined an OnLeave hook
		for _, T in ipairs(Prev._Transitions) do
			if type(T.OnLeave) == "function" then
				T.OnLeave(T, Prev, self.Data)
			end
		end

		-- Reset anything registered under the previous state's janitor
		Prev._Janitor:Destroy()
		Prev._Janitor = Janitor.new()
	end

	-- Update bookkeeping
	self._Previous = self._Current
	self._Current = NewState

	-- Run OnEnter for transitions first (allows setup before state logic)
	for _, T in ipairs(NextState._Transitions) do
		if type(T.OnEnter) == "function" then
			T.OnEnter(T, NextState, self.Data)
		end
	end

	-- Then run the state's own OnEnter
	if type(NextState.OnEnter) == "function" then
		NextState.OnEnter(NextState, self.Data)
	end

	-- Fire public event with new and old names
	local PrevName = Prev and Prev.Name or ""
	self.StateChanged:Fire(NewState, PrevName)
end

function StateMachine:Destroy()
	-- Fully dismantles the machine and all attached objects
	if self._Destroyed then
		return
	end
	self._Destroyed = true

	-- Call final OnLeave for the current state
	local Cur = self._States[self._Current]
	if Cur and type(Cur.OnLeave) == "function" then
		Cur.OnLeave(Cur, self.Data)
	end

	-- Clean machine-level resources
	self._Janitor:Destroy()

	-- Clean state objects and transitions
	for _, State in pairs(self._States) do
		if State then
			State._Machine = nil -- Break reference

			if State._Transitions then
				for _, T in ipairs(State._Transitions) do
					if T then
						T._State = nil
					end
				end
			end

			-- Kill state-specific Janitor cleanup
			if State._Janitor then
				State._Janitor:Destroy()
			end
		end
	end

	-- Clear stored data
	for K in pairs(self.Data) do
		self.Data[K] = nil
	end

	self._States = {}

	-- Destroy events so listeners can disconnect
	self.StateChanged:Destroy()
	self.DataChanged:Destroy()
end

function StateMachine.LoadFromFolder(Folder)
	-- Utility for loading multiple state/transition factory modules from a folder
	local Factories = {}
	for _, Child in ipairs(Folder:GetChildren()) do
		if Child:IsA("ModuleScript") then
			local Ok, F = pcall(require, Child)
			-- Only modules that return a function are considered valid state factories
			if Ok and type(F) == "function" then
				table.insert(Factories, F)
			end
		end
	end
	return Factories
end

return StateMachine
