--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StateMachine = require(ReplicatedStorage.Packages.StateMachine)

return function()
	local Interacted = StateMachine.State.new("Interacted")
	local Connection = nil
	local rotationSpeed = 5

	function Interacted:OnEnter(Data)
		if not Data.NPC then
			return
		end

		print(`[{Data.NPC.Name}] Entered Interaction`)

		local Interactor = Data.Interactor
		if not Interactor then
			warn("Interactor doesn't exist")
			return
		end

		local NPC = Data.NPC

		local Character = Interactor.Character
		if
			not Character
			or not Character:FindFirstChild("HumanoidRootPart")
			or not Character:FindFirstChild("Humanoid")
		then
			warn("Character doesn't exist")
			return
		end

		Connection = RunService.Heartbeat:Connect(function(dt: number)
			local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
			local NPCRoot = NPC:FindFirstChild("HumanoidRootPart")

			if not HumanoidRootPart or not NPCRoot then
				return
			end

			local lookAt = Vector3.new(HumanoidRootPart.Position.X, NPCRoot.Position.Y, HumanoidRootPart.Position.Z)
			local targetCFrame = CFrame.lookAt(NPCRoot.Position, lookAt)

			local alpha = 1 - math.exp(-rotationSpeed * dt)
			NPCRoot.CFrame = NPCRoot.CFrame:Lerp(targetCFrame, alpha)
		end)
	end

	function Interacted:OnUpdate(Data, Dt) end

	function Interacted:OnLeave(Data)
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end
	end

	return Interacted
end
