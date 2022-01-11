local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Promise = require(ReplicatedStorage.Knit.Util.Promise)
local Typer = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Typer)

local TeleportPromise = {}

local function TeleportAsync(PlaceId: number, Players: {Player}, TeleportOptions: TeleportOptions?): TeleportAsyncResult
	return TeleportService:TeleportAsync(PlaceId, Players, TeleportOptions)
end

local function TeleportToPrivateServer(PlaceId: number, ReservedServerAccessCode: string, Players: {Player})
	return TeleportService:TeleportToPrivateServer(PlaceId, ReservedServerAccessCode, Players)
end

local ArrayOfPlayers = Typer.ArrayOfInstanceWhichIsAPlayersOrEmptyTable

TeleportPromise.PromiseReserveServer = Typer.PromiseAssignSignature(Typer.Integer, function(PlaceId: number)
	return Promise.new(function(Resolve, Reject)
		local ServerData
		local Success, Error = pcall(function()
			ServerData = table.pack(TeleportService:ReserveServer(PlaceId))
		end)

		if Success then
			Resolve(table.unpack(ServerData, 1, ServerData.n))
		else
			Reject(Error)
		end
	end)
end) :: (PlaceId: number) -> any

TeleportPromise.PromiseTeleportToPrivateServer = Typer.PromiseAssignSignature(Typer.Integer, Typer.String, ArrayOfPlayers, function(PlaceId: number, ReservedServerAccessCode: string, Players: {Player})
	return Promise.new(function(Resolve, Reject)
		local Success, Error = pcall(TeleportToPrivateServer, PlaceId, ReservedServerAccessCode, Players);
		(Success and Resolve or Reject)(Error)
	end)
end) :: (PlaceId: number, ReservedServerAccessCode: string, Players: {Player}) -> any

TeleportPromise.PromiseTeleportAsync = Typer.PromiseAssignSignature(Typer.Integer, ArrayOfPlayers, Typer.OptionalInstanceWhichIsATeleportOptions, function(PlaceId: number, Players: {Player}, TeleportOptions: TeleportOptions?)
	return Promise.Defer(function(Resolve, Reject)
		local Success, TeleportAsyncResult = pcall(TeleportAsync, PlaceId, Players, TeleportOptions);
		(Success and Resolve or Reject)(TeleportAsyncResult)
	end)
end) :: (PlaceId: number, Players: {Player}, TeleportOptions: TeleportOptions?) -> any

table.freeze(TeleportPromise)
return TeleportPromise
