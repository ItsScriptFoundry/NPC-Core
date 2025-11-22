--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)
local PromptInteractor = require(ReplicatedStorage.Shared.Modules.Utility.PromptInteractor)

local Waypoints = workspace.Waypoints

return function()
	local Wandering = StateMachine.State.new("Wandering")
	Wandering.Transitions = {
		require(script.Parent.Parent.Transitions.TimePassedToIdle),
		require(script.Parent.Parent.Transitions.PlayerInteraction),
	}

	local Connection = nil

	-- Use state-specific data, not blocking loops
	function Wandering:OnEnter(Data)
		if not Data.NPC or not Data.NPC:FindFirstChild("Humanoid") then
			warn("NPC or Humanoid missing")
			return
		end

		print(`[{Data.NPC.Name}] Started wandering`)

		Connection = PromptInteractor.Setup(Data)

		-- Store walk data in Data (persisted across updates)
		Data.WalkData = {
			NPC = Data.NPC,
			Humanoid = Data.NPC:FindFirstChild("Humanoid") :: Humanoid,
			Waypoints = Waypoints:GetChildren(),
			CurrentWaypoint = nil,
			LastMoveTime = 0,
			WaitTime = 0,
		}

		self:_SelectNewWaypoint(Data)
	end

	function Wandering:OnUpdate(Data, Dt)
		local walkData = Data.WalkData
		if not walkData or not walkData.Humanoid then
			return
		end

		-- Check if finished waiting/moving
		if tick() - walkData.LastMoveTime >= walkData.WaitTime then
			self:_SelectNewWaypoint(Data)
		end
	end

	function Wandering:OnLeave(Data)
		print(`[{Data.NPC.Name}] Stopped wandering`)
		if Data.WalkData and Data.WalkData.Humanoid then
			Data.WalkData.Humanoid:MoveTo(Data.WalkData.Humanoid.RootPart.Position)
		end
		Data.WalkData = nil -- Cleanup

		PromptInteractor.Cleanup(Connection)
	end

	-- Helper: Pick and move to a random waypoint
	function Wandering:_SelectNewWaypoint(Data)
		local walkData = Data.WalkData
		if not walkData or #walkData.Waypoints == 0 then
			return
		end

		local randomIndex = math.random(1, #walkData.Waypoints)
		local waypoint = walkData.Waypoints[randomIndex]
		local rootPos = walkData.Humanoid.RootPart.Position

		local targetPos = Vector3.new(waypoint.Position.X, rootPos.Y, waypoint.Position.Z)

		walkData.Humanoid:MoveTo(targetPos)
		walkData.CurrentWaypoint = waypoint
		walkData.LastMoveTime = tick()
		walkData.WaitTime = math.random(3, 10) -- Wait 3-10 seconds after arriving

		print(`[{walkData.NPC.Name}] Moving to waypoint {randomIndex}`)
	end

	return Wandering
end
