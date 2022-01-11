local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetTimeFromHttp = require(script.GetTimeFromHttp)
local GetTimeFromOsClock = require(script.GetTimeFromOsClock)
local GetTimeFromRemote = require(script.GetTimeFromRemote)
local Promise = require(script.Parent.Parent.Parent.Promise)
local SyncedClock = require(script.SyncedClock)

local DefaultNetworkClock, DefaultNetworkClockNoHttp

local NetworkClock = {}
NetworkClock.ClassName = "NetworkClock"
NetworkClock.CREATE_REMOTE_FUNCTION = {}
NetworkClock.__index = NetworkClock

local DefaultSyncMode, DefaultResyncOnSuccessInterval
if RunService:IsServer() then
	DefaultSyncMode = "Http"
	DefaultResyncOnSuccessInterval = 120
else
	DefaultSyncMode = "RemoteFunction"
	DefaultResyncOnSuccessInterval = 30
end

type Url = string

export type Options = {
	Name: string,
	RemoteFunction: any?,
	ResyncLerpOffset: boolean?,
	ResyncOnFailureInterval: number?,
	ResyncOnSuccessInterval: number?,
	TimeSource: string?,

	HttpTimeout: number?,
	HttpMinResults: number?,
	HttpUrls: {Url}?,
}

local DEFAULT_OPTIONS = {
	Name = false;
	RemoteFunction = NetworkClock.CREATE_REMOTE_FUNCTION;
	ResyncLerpOffset = true;
	ResyncOnFailureInterval = 10;
	ResyncOnSuccessInterval = DefaultResyncOnSuccessInterval;
	TimeSource = DefaultSyncMode; -- "Http" | "OsClock" | "RemoteFunction"

	HttpTimeout = 10;
	HttpMinResults = 3;
	HttpUrls = {
		"https://www.wikipedia.org";
		"https://www.microsoft.com";
		"https://stackoverflow.com";
		"https://www.amazon.com";
		"https://aws.amazon.com";
	};
}

local function InitRemoteFunction(self)
	return Promise.Try(function()
		if self.Options.RemoteFunction == NetworkClock.CREATE_REMOTE_FUNCTION then
			if RunService:IsServer() then
				local RemoteFunction = Instance.new("RemoteFunction")
				RemoteFunction.Name = "__NetworkClock:" .. self.Name
				self.RemoteFunction = RemoteFunction
			else
				self.RemoteFunction = ReplicatedStorage:WaitForChild("__NetworkClock:" .. self.Name)
			end
		elseif typeof(self.Options.RemoteFunction) == "Instance" then
			self.RemoteFunction = self.Options.RemoteFunction
		elseif Promise.Is(self.Options.RemoteFunction) then
			self.RemoteFunction = self.Options.RemoteFunction:Expect()
		end

		if RunService:IsServer() then
			function self.RemoteFunction.OnServerInvoke()
				return self.Clock:GetRawTime()
			end
		end
	end)
end

local function AttemptSync(self)
	local Options = self.Options
	local TimeSource = Options.TimeSource
	local SyncPromise

	if TimeSource == "Http" then
		SyncPromise = GetTimeFromHttp(Options.HttpUrls, Options.HttpTimeout, Options.HttpMinResults)
	elseif TimeSource == "OsClock" then
		SyncPromise = GetTimeFromOsClock()
	elseif TimeSource == "RemoteFunction" then
		SyncPromise = GetTimeFromRemote(self.RemoteFunction)
	end

	return assert(SyncPromise, "Bad TimeSource"):Then(function(Data)
		self.Clock:TrySetOffset(Data.Offset, Data.Accuracy)
	end)
end

local function AttemptSyncUntilSuccess(self)
	return Promise.Try(function()
		while true do
			local Success, Error = AttemptSync(self):Wait()
			if Success then
				return
			end

			warn("[NetworkClock] " .. tostring(self.Options.TimeSource) .. " sync failed because: " .. tostring(Error))
			task.wait(self.Options.ResyncOnFailureInterval)
		end
	end)
end

local function SyncPersistentlyInBackground(self)
	return Promise.Try(function()
		while true do
			local Success, Error = AttemptSyncUntilSuccess(self):Wait()
			if not Success then
				warn("[NetworkClock] " .. tostring(self.Options.TimeSource) .. " persistent sync failed because: " .. tostring(Error))
				warn("[NetworkClock] Stopping background sync. This Clock (" .. tostring(self.Name) .. ") may drift out of sync.")
				error(Error)
			end

			task.wait(self.Options.ResyncOnSuccessInterval)
		end
	end)
end

local function Init(self)
	return Promise.Try(function()
		InitRemoteFunction(self):Expect()
		AttemptSyncUntilSuccess(self):Expect()

		if RunService:IsServer() and self.Options.RemoteFunction == NetworkClock.CREATE_REMOTE_FUNCTION then
			self.RemoteFunction.Parent = ReplicatedStorage
		end

		if self.Options.ResyncOnSuccessInterval > 0 then
			SyncPersistentlyInBackground(self)
		end

		return self
	end):Catch(function(Error)
		warn("[NetworkClock] Init failed because: " .. tostring(Error))
		return Promise.Reject(Error)
	end)
end

function NetworkClock.new(NewOptions: Options?)
	local self = setmetatable({}, NetworkClock)

	local Options = {}
	for Key, Value in next, DEFAULT_OPTIONS do
		if NewOptions and NewOptions[Key] ~= nil then
			Options[Key] = NewOptions[Key]
		else
			Options[Key] = Value
		end
	end

	self.Options = Options

	assert(type(self.Options.Name) == "string", "expected string for options.Name, got " .. typeof(self.Options.Name))
	if self.Options.TimeSource == "RemoteFunction" and not self.Options.RemoteFunction then
		error("When options.TimeSource is \"RemoteFunction\", options.RemoteFunction must be set")
	end

	self.Name = self.Options.Name
	self.Clock = SyncedClock.new({
		ShouldLerp = self.Options.ResyncLerpOffset;
	})

	self.Init = Init(self)

	return self
end

function NetworkClock.Default()
	if not DefaultNetworkClock then
		DefaultNetworkClock = NetworkClock.new({Name = "NetworkClock:Default"})
	end

	return DefaultNetworkClock
end

function NetworkClock.DefaultNoHttp()
	if not DefaultNetworkClockNoHttp then
		if RunService:IsServer() then
			DefaultNetworkClockNoHttp = NetworkClock.new({
				Name = "NetworkClock:DefaultNoHttp";
				ResyncOnSuccessInterval = 0;
				TimeSource = "OsClock";
			})
		else
			DefaultNetworkClockNoHttp = NetworkClock.new({
				Name = "NetworkClock:DefaultNoHttp";
				ResyncOnSuccessInterval = 30;
				TimeSource = "RemoteFunction";
			})
		end
	end

	return DefaultNetworkClockNoHttp
end

function NetworkClock:GetInitalizedPromise()
	return Promise.Try(function()
		return self.Init:Expect()
	end)
end

function NetworkClock:WaitUntilInitialized()
	return self.Init:Expect()
end

function NetworkClock:GetTime()
	return self.Clock:GetTime()
end

function NetworkClock:GetAccuracy()
	return self.Clock:GetAccuracy()
end

function NetworkClock:__call()
	return self.Clock:GetTime()
end

function NetworkClock:__tostring()
	return "NetworkClock"
end

export type NetworkClock = typeof(NetworkClock.new())
table.freeze(NetworkClock)
return NetworkClock
