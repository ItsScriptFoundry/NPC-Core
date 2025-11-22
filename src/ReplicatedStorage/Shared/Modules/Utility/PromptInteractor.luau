-- ReplicatedStorage/Utils/PromptInteractor.lua
local PromptInteractor = {}

function PromptInteractor.Setup(Data, onInteract)
	local NPC = Data.NPC
	if not NPC:FindFirstChild("HumanoidRootPart") or not NPC:FindFirstChild("Humanoid") or NPC.Humanoid.Health <= 0 then
		warn("NPC is dead or missing.")
		return nil
	end

	local Prompt = NPC.HumanoidRootPart:FindFirstChild("DialoguePrompt")
	if not Prompt then
		return nil
	end

	local connection = Prompt.Triggered:Connect(function(player)
		Data.Interacted = true
		Data.Interactor = player
		if onInteract then
			onInteract(player)
		end
	end)

	return connection
end

function PromptInteractor.Cleanup(connection)
	if connection then
		connection:Disconnect()
	end
end

return PromptInteractor
