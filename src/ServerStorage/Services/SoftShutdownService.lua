local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Knit)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local GetFirstChild = require(ReplicatedStorage.Knit.Util.Additions.Utility.GetFirstChild)
local Signal = require(ReplicatedStorage.Knit.Util.Signal)
local TeleportPromise = require(ServerStorage.Modules.Promises.TeleportPromise)

local SoftShutdownService = Knit.CreateService({
	Client = {};
	Name = "SoftShutdownService";
})

SoftShutdownService.IsShuttingDown = false
SoftShutdownService.IsTemporary = false
SoftShutdownService.PlayerDataSaved = Signal.new()
SoftShutdownService.ReservedServerCode = nil
SoftShutdownService.OnShutdownFunctions = {}

local MESSAGE_CLASS_NAME = "Message"

local IsShuttingDown: BoolValue = GetFirstChild(ReplicatedStorage, "BoolValue", "IsShuttingDown")
local IsTemporary: BoolValue = GetFirstChild(ReplicatedStorage, "BoolValue", "IsTemporary")

local function OnPlayerDataSaved(Player: Player)
	local ReservedServerCode = SoftShutdownService.ReservedServerCode
	repeat
		ReservedServerCode = SoftShutdownService.ReservedServerCode
	until ReservedServerCode or not task.wait()

	TeleportPromise.PromiseTeleportToPrivateServer(game.PlaceId, ReservedServerCode, table.create(1, Player)):Catch(CatchFactory("TeleportPromise.PromiseTeleportToPrivateServer"))
end

local function OnChildAdded(Child: Instance)
	if Child:IsA(MESSAGE_CLASS_NAME) then
		if Child.Name == "TemporaryMessage" then
			SoftShutdownService.IsShuttingDown = true
			SoftShutdownService.IsTemporary = true
			IsShuttingDown.Value = true
			IsTemporary.Value = true
		elseif Child.Name == "ShutdownMessage" then
			SoftShutdownService.IsShuttingDown = true
			SoftShutdownService.IsTemporary = false
			IsShuttingDown.Value = true
			IsTemporary.Value = false
		end
	end
end

function SoftShutdownService:AddOnShutdownFunction(OnShutdownFunction: () -> ())
	table.insert(self.OnShutdownFunctions, OnShutdownFunction)
	return self
end

function SoftShutdownService:KnitInit()
	self.PlayerDataSaved:Connect(OnPlayerDataSaved)
	Workspace.ChildAdded:Connect(OnChildAdded)

	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		local Message = Instance.new(MESSAGE_CLASS_NAME)
		Message.Name = "TempMessage"
		Message.Text = "This is a temporary lobby. Teleporting back in a moment."
		Message.Parent = Workspace

		local TeleportOptions = Instance.new("TeleportOptions")
		TeleportOptions.ShouldReserveServer = false

		local WaitTime = 5
		Players.PlayerAdded:Connect(function(Player: Player)
			task.wait(WaitTime)
			WaitTime /= 2
			TeleportPromise.PromiseTeleportAsync(game.PlaceId, table.create(1, Player), TeleportOptions):Catch(CatchFactory("TeleportPromise.PromiseTeleportAsync"))
		end)

		task.spawn(function()
			for _, Player in ipairs(Players:GetPlayers()) do
				TeleportPromise.PromiseTeleportAsync(game.PlaceId, table.create(1, Player), TeleportOptions):Catch(CatchFactory("TeleportPromise.PromiseTeleportAsync"))
				task.wait(WaitTime)
				WaitTime /= 2
			end
		end)
	else
		game:BindToClose(function()
			if #Players:GetPlayers() == 0 or game.JobId == "" then
				return
			end

			local Message = Instance.new(MESSAGE_CLASS_NAME)
			Message.Name = "ShutdownMessage"
			Message.Text = "Rebooting servers for update. Please wait"
			Message.Parent = Workspace

			task.wait(2)
			TeleportPromise.PromiseReserveServer(game.PlaceId):Then(function(ReservedServerCode)
				self.ReservedServerCode = ReservedServerCode
				ReplicatedStorage:SetAttribute("ReservedServerCode", ReservedServerCode)

				local function PlayerAdded(Player: Player)
					TeleportPromise.PromiseTeleportToPrivateServer(game.PlaceId, ReservedServerCode, table.create(1, Player)):Catch(CatchFactory("TeleportPromise.PromiseTeleportToPrivateServer"))
				end

				Players.PlayerAdded:Connect(PlayerAdded)

				for _, OnShutdownFunction in ipairs(self.OnShutdownFunctions) do
					OnShutdownFunction()
				end

				-- -- stylua: ignore
				-- repeat until Knit.Services.GameService or not task.wait()
				-- task.wait(0.5)

				-- Knit.Services.GameService:ReleaseProfiles()
				--TeleportPromise.PromiseTeleportToPrivateServer(game.PlaceId, ReservedServerCode, Players:GetPlayers()):Catch(CatchFactory("TeleportPromise.PromiseTeleportToPrivateServer")):Wait()
			end):Catch(CatchFactory("TeleportPromise.PromiseReserveServer")):Wait()

			while #Players:GetPlayers() > 0 do
				task.wait(1)
			end
		end)
	end
end

return SoftShutdownService
