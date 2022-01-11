-- Comm
-- Stephen Leitnick
-- August 05, 2021

--[[
	CORE FUNCTIONS:
		Comm.Server.BindFunction(parent: Instance, name: string, func: (Instance, ...any) -> ...any, middleware): RemoteFunction
		Comm.Server.WrapMethod(parent: Instance, tbl: {}, name: string, inbound: ServerMiddleware?, outbound: ServerMiddleware?): RemoteFunction
		Comm.Server.CreateSignal(parent: Instance, name: string, inbound: ServerMiddleware?, outbound: ServerMiddleware?): RemoteSignal

		Comm.Client.GetFunction(parent: Instance, name: string, usePromise: boolean, middleware: ClientMiddleware?): (...any) -> ...any
		Comm.Client.GetSignal(parent: Instance, name: string, inbound: ClientMiddleware?, outbound: ClientMiddleware?): ClientRemoteSignal

	HELPER CLASSES:
		serverComm = Comm.Server.ForParent(parent: Instance, namespace: string?): ServerComm
		serverComm:BindFunction(name: string, func: (Instance, ...any) -> ...any, inbound: ServerMiddleware?, outbound: ServerMiddleware?): RemoteFunction
		serverComm:WrapMethod(tbl: {}, name: string, inbound: ServerMiddleware?, outbound: ServerMiddleware?): RemoteFunction
		serverComm:CreateSignal(name: string, inbound: ServerMiddleware?, outbound: ServerMiddleware?): RemoteSignal

		serverComm:Destroy()

		clientComm = Comm.Client.ForParent(parent: Instance, usePromise: boolean, namespace: string?): ClientComm
		clientComm:GetFunction(name: string, usePromise: boolean, inbound: ClientMiddleware?, outbound: ClientMiddleware?): (...any) -> ...any
		clientComm:GetSignal(name: string, inbound: ClientMiddleware?, outbound: ClientMiddleware?): ClientRemoteSignal
		clientComm:Destroy()
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Debug = require(script.Parent.Additions.Debugging.Debug)
local Option = require(script.Parent.Option)
local Promise = require(script.Parent.Promise)
local Ser = require(script.Parent.Ser)
local Signal = require(script.Parent.Signal)

local _Janitor = require(script.Parent.Janitor)

type FnBind = (Instance, ...any) -> ...any
type Args = {
	n: number,
	[any]: any,
}

type ServerMiddlewareFn = (Instance, Args) -> (boolean, ...any)
type ServerMiddleware = {ServerMiddlewareFn}

type ClientMiddlewareFn = (Args) -> (boolean, ...any)
type ClientMiddleware = {ClientMiddlewareFn}

local IS_SERVER = RunService:IsServer()
local DEFAULT_COMM_FOLDER_NAME = "__comm__"
local WAIT_FOR_CHILD_TIMEOUT = 60

local function GetCommSubFolder(parent: Instance, subFolderName: string): Option.Option<Folder>
	local subFolder: Instance = nil
	if IS_SERVER then
		subFolder = parent:FindFirstChild(subFolderName)
		if not subFolder then
			subFolder = Instance.new("Folder")
			subFolder.Name = subFolderName
			subFolder.Parent = parent
		end
	else
		subFolder = parent:WaitForChild(subFolderName, WAIT_FOR_CHILD_TIMEOUT)
	end

	return Option.Wrap(subFolder)
end

--[=[
	@class RemoteSignal
	@server
	Created via `ServerComm:CreateSignal()`.
]=]
local RemoteSignal = {}
RemoteSignal.ClassName = "RemoteSignal"
RemoteSignal.__index = RemoteSignal

--[=[
	@within RemoteSignal
	@interface Connection
	.Disconnect () -> nil
]=]

function RemoteSignal.new(parent: Instance, name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?)
	local self = setmetatable({}, RemoteSignal)
	self._re = Instance.new("RemoteEvent")
	self._re.Name = name
	self._re.Parent = parent
	if outboundMiddleware and #outboundMiddleware > 0 then
		self._hasOutbound = true
		self._outbound = outboundMiddleware
	else
		self._hasOutbound = false
	end

	if inboundMiddleware and #inboundMiddleware > 0 then
		self._directConnect = false
		self._signal = Signal.new()
		self._re.OnServerEvent:Connect(function(player, ...)
			local args = Ser.DeserializeArgs(...)
			for _, middlewareFunc in ipairs(inboundMiddleware :: ServerMiddleware) do
				local middlewareResult = table.pack(middlewareFunc(player, args))
				if not middlewareResult[1] then
					return
				end
			end

			self._signal:Fire(player, Ser.UnpackArgs(args))
		end)
	else
		self._directConnect = true
	end

	return self
end

--[=[
	@param fn (player: Player, ...: any) -> nil -- The function to connect
	@return Connection
	Connect a function to the signal. Anytime a matching ClientRemoteSignal
	on a client fires, the connected function will be invoked with the
	arguments passed by the client.
]=]
function RemoteSignal:Connect(fn)
	local function new(...)
		fn(Ser.DeserializeArgsAndUnpack(...))
	end

	if self._directConnect then
		return self._re.OnServerEvent:Connect(new)
	else
		return self._signal:Connect(new)
	end
end

function RemoteSignal:_processOutboundMiddleware(player: Player?, ...: any)
	if not self._hasOutbound then
		return Ser.SerializeArgsAndUnpack(...)
	end

	local args = Ser.SerializeArgs(...)
	for _, middlewareFunc in ipairs(self._outbound) do
		local middlewareResult = table.pack(middlewareFunc(player, args))
		if not middlewareResult[1] then
			return table.unpack(middlewareResult, 2, middlewareResult.n)
		end
	end

	return Ser.UnpackArgs(args)
end

--[=[
	@param player Player -- The target client
	@param ... any -- Arguments passed to the client
	Fires the signal at the specified client with any arguments.

	:::note Outbound Middleware
	All arguments pass through any outbound middleware before being
	sent to the client.
	:::
]=]
function RemoteSignal:Fire(player: Player, ...: any)
	self._re:FireClient(player, self:_processOutboundMiddleware(player, ...))
end

--[=[
	@param ... any
	Fires the signal at _all_ clients with any arguments.

	:::note Outbound Middleware
	All arguments pass through any outbound middleware before being
	sent to the clients.
	:::
]=]
function RemoteSignal:FireAll(...: any)
	self._re:FireAllClients(self:_processOutboundMiddleware(nil, ...))
end

--[=[
	@param predicate (player: Player, argsFromFire: ...) -> boolean
	@param ... any -- Arguments to pass to the clients (and to the predicate)
	Fires the signal at any clients that pass the `predicate`
	function test. This can be used to fire signals with much
	more control logic.

	:::note Outbound Middleware
	All arguments pass through any outbound middleware before being
	sent to the clients.
	:::

	:::caution Predicate Before Middleware
	The arguments sent to the predicate are sent _before_ getting
	transformed by any middleware.
	:::

	```lua
	-- Fire signal to players of the same team:
	remoteSignal:FireFilter(function(player)
		return player.Team.Name == "Best Team"
	end)
	```
]=]
function RemoteSignal:FireFilter(predicate: (Player, ...any) -> boolean, ...: any)
	local args = Ser.SerializeArgs(...)
	for _, player in ipairs(Players:GetPlayers()) do
		if predicate(player, Ser.UnpackArgs(args)) then
			self._re:FireClient(player, self:_processOutboundMiddleware(nil, ...))
		end
	end
end

--[=[
	Destroys the RemoteSignal object.
]=]
function RemoteSignal:Destroy()
	self._re:Destroy()
	if self._signal then
		self._signal:Destroy()
	end
end

function RemoteSignal:__tostring()
	return "RemoteSignal"
end

--[=[
	@class ClientRemoteSignal
	@client
	Created via `ClientComm:GetSignal()`.
]=]
local ClientRemoteSignal = {}
ClientRemoteSignal.ClassName = "ClientRemoteSignal"
ClientRemoteSignal.__index = ClientRemoteSignal

--[=[
	@within ClientRemoteSignal
	@interface Connection
	.Disconnect () -> nil
]=]

function ClientRemoteSignal.new(re: RemoteEvent, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?)
	local self = setmetatable({}, ClientRemoteSignal)
	self._re = re
	if outboundMiddleware and #outboundMiddleware > 0 then
		self._hasOutbound = true
		self._outbound = outboundMiddleware
	else
		self._hasOutbound = false
	end

	if inboundMiddleware and #inboundMiddleware > 0 then
		self._directConnect = false
		self._signal = Signal.new()
		self._reConn = self._re.OnClientEvent:Connect(function(...)
			local args = Ser.DeserializeArgs(...)
			for _, middlewareFunc in ipairs(inboundMiddleware :: ClientMiddleware) do
				local middlewareResult = table.pack(middlewareFunc(args))
				if not middlewareResult[1] then
					return
				end
			end

			self._signal:Fire(Ser.UnpackArgs(args))
		end)
	else
		self._directConnect = true
	end

	return self
end

function ClientRemoteSignal:_processOutboundMiddleware(...: any)
	local args = Ser.SerializeArgs(...)
	for _, middlewareFunc in ipairs(self._outbound) do
		local middlewareResult = table.pack(middlewareFunc(args))
		if not middlewareResult[1] then
			return table.unpack(middlewareResult, 2, middlewareResult.n)
		end
	end

	return Ser.UnpackArgs(args)
end

--[=[
	@param fn (...: any) -> any
	@return Connection
	Connects a function to the remote signal. The function will be
	called anytime the equivalent server-side RemoteSignal is
	fired at this specific client that created this client signal.
]=]
function ClientRemoteSignal:Connect(fn)
	local function new(...)
		fn(Ser.DeserializeArgsAndUnpack(...))
	end

	if self._directConnect then
		return self._re.OnClientEvent:Connect(new)
	else
		return self._signal:Connect(new)
	end
end

--[=[
	@param ... any -- Arguments to pass to the server
	Fires the equivalent server-side signal with the given arguments.

	:::note Outbound Middleware
	All arguments pass through any outbound middleware before being
	sent to the server.
	:::
]=]
function ClientRemoteSignal:Fire(...: any)
	if self._hasOutbound then
		self._re:FireServer(self:_processOutboundMiddleware(...))
	else
		self._re:FireServer(Ser.SerializeArgsAndUnpack(...))
	end
end

--[=[
	Destroys the ClientRemoteSignal object.
]=]
function ClientRemoteSignal:Destroy()
	if self._signal then
		self._signal:Destroy()
	end
end

function ClientRemoteSignal:__tostring()
	return "ClientRemoteSignal"
end

--[=[
	@class Comm
	Remote communication library.

	This exposes the raw functions that are used by the `ServerComm` and `ClientComm` classes.
	Those two classes should be preferred over accessing the functions directly through this
	Comm library.
]=]
local Comm = {}
Comm.Server = {}
Comm.Client = {}

--[=[
	@within Comm
	@prop ServerComm ServerComm
]=]
--[=[
	@within Comm
	@prop ClientComm ClientComm
]=]

--[=[
	@within Comm
	@private
	@interface Server
	.BindFunction (parent: Instance, name: string, fn: FnBind, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteFunction
	.WrapMethod (parent: Instance, tbl: table, name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteFunction
	.CreateSignal (parent: Instance, name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteSignal
	Server Comm
]=]
--[=[
	@within Comm
	@private
	@interface Client
	.GetFunction (parent: Instance, name: string, usePromise: boolean, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?): (...: any) -> any
	.GetSignal (parent: Instance, name: string, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?): ClientRemoteFunction
	Client Comm
]=]

function Comm.Server.BindFunction(parent: Instance, name: string, func: FnBind, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteFunction
	Debug.Assert(IS_SERVER, "BindFunction must be called from the server")
	local folder = GetCommSubFolder(parent, "RF"):Expect("Failed to get Comm RF folder")
	local rf = Instance.new("RemoteFunction")
	rf.Name = name
	local hasInbound = type(inboundMiddleware) == "table" and #inboundMiddleware > 0
	local hasOutbound = type(outboundMiddleware) == "table" and #outboundMiddleware > 0
	local function ProcessOutbound(player, ...)
		local args = Ser.DeserializeArgs(...)
		for _, middlewareFunc in ipairs(outboundMiddleware :: ServerMiddleware) do
			local middlewareResult = table.pack(middlewareFunc(player, args))
			if not middlewareResult[1] then
				return table.unpack(middlewareResult, 2, middlewareResult.n)
			end
		end

		return Ser.UnpackArgs(args)
	end

	if hasInbound and hasOutbound then
		local function OnServerInvoke(player, ...)
			local args = Ser.DeserializeArgs(...)
			for _, middlewareFunc in ipairs(inboundMiddleware :: ServerMiddleware) do
				local middlewareResult = table.pack(middlewareFunc(player, args))
				if not middlewareResult[1] then
					return table.unpack(middlewareResult, 2, middlewareResult.n)
				end
			end

			return ProcessOutbound(player, func(player, Ser.UnpackArgs(args)))
		end

		rf.OnServerInvoke = OnServerInvoke
	elseif hasInbound then
		local function OnServerInvoke(player, ...)
			local args = Ser.DeserializeArgs(...)
			for _, middlewareFunc in ipairs(inboundMiddleware :: ServerMiddleware) do
				local middlewareResult = table.pack(middlewareFunc(player, args))
				if not middlewareResult[1] then
					return table.unpack(middlewareResult, 2, middlewareResult.n)
				end
			end

			return func(player, Ser.UnpackArgs(args))
		end

		rf.OnServerInvoke = OnServerInvoke
	elseif hasOutbound then
		local function OnServerInvoke(player, ...)
			return ProcessOutbound(player, func(player, Ser.DeserializeArgsAndUnpack(...)))
		end

		rf.OnServerInvoke = OnServerInvoke
	else
		rf.OnServerInvoke = func
	end

	rf.Parent = folder
	return rf
end

function Comm.Server.WrapMethod(parent: Instance, tbl: {}, name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteFunction
	Debug.Assert(IS_SERVER, "WrapMethod must be called from the server")
	local fn = tbl[name]
	Debug.Assert(type(fn) == "function", "Value at index " .. name .. " must be a function; got %q", fn)

	return Comm.Server.BindFunction(parent, name, function(...)
		return fn(tbl, ...)
	end, inboundMiddleware, outboundMiddleware)
end

function Comm.Server.CreateSignal(parent: Instance, name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?)
	Debug.Assert(IS_SERVER, "CreateSignal must be called from the server")
	local folder = GetCommSubFolder(parent, "RE"):Expect("Failed to get Comm RE folder")
	return RemoteSignal.new(folder, name, inboundMiddleware, outboundMiddleware)
end

function Comm.Client.GetFunction(parent: Instance, name: string, usePromise: boolean, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?)
	Debug.Assert(not IS_SERVER, "GetFunction must be called from the client")
	local folder = GetCommSubFolder(parent, "RF"):Expect("Failed to get Comm RF folder")
	local rf = folder:WaitForChild(name, WAIT_FOR_CHILD_TIMEOUT)
	Debug.Assert(rf ~= nil, "Failed to find RemoteFunction: " .. name)
	local hasInbound = type(inboundMiddleware) == "table" and #inboundMiddleware > 0
	local hasOutbound = type(outboundMiddleware) == "table" and #outboundMiddleware > 0
	local function ProcessOutbound(args)
		--args = Ser.DeserializeArgs(Ser.UnpackArgs(args))
		for _, middlewareFunc in ipairs(outboundMiddleware :: ClientMiddleware) do
			local middlewareResult = table.pack(middlewareFunc(args))
			if not middlewareResult[1] then
				return table.unpack(middlewareResult, 2, middlewareResult.n)
			end
		end

		return Ser.UnpackArgs(args)
	end

	if hasInbound then
		if usePromise then
			return function(...)
				local args = Ser.SerializeArgs(...)
				return Promise.new(function(resolve, reject)
					local success, res = pcall(function()
						if hasOutbound then
							return Ser.DeserializeArgs(rf:InvokeServer(ProcessOutbound(args)))
						else
							return Ser.DeserializeArgs(rf:InvokeServer(Ser.UnpackArgs(args)))
						end
					end)

					if success then
						for _, middlewareFunc in ipairs(inboundMiddleware :: ClientMiddleware) do
							local middlewareResult = table.pack(middlewareFunc(res))
							if not middlewareResult[1] then
								return table.unpack(middlewareResult, 2, middlewareResult.n)
							end
						end

						resolve(Ser.UnpackArgs(res))
					else
						reject(res)
					end
				end)
			end
		else
			return function(...)
				local res
				if hasOutbound then
					res = Ser.DeserializeArgs(rf:InvokeServer(ProcessOutbound(Ser.SerializeArgs(...))))
				else
					res = Ser.DeserializeArgs(rf:InvokeServer(Ser.SerializeArgsAndUnpack(...)))
				end

				for _, middlewareFunc in ipairs(inboundMiddleware :: ClientMiddleware) do
					local middlewareResult = table.pack(middlewareFunc(res))
					if not middlewareResult[1] then
						return table.unpack(middlewareResult, 2, middlewareResult.n)
					end
				end

				return Ser.UnpackArgs(res)
			end
		end
	else
		if usePromise then
			return function(...)
				local args = Ser.SerializeArgs(...)
				return Promise.new(function(resolve, reject)
					local success, res = pcall(function()
						if hasOutbound then
							return Ser.DeserializeArgs(rf:InvokeServer(ProcessOutbound(args)))
						else
							return Ser.DeserializeArgs(rf:InvokeServer(Ser.UnpackArgs(args)))
						end
					end)

					if success then
						resolve(Ser.UnpackArgs(res))
					else
						reject(res)
					end
				end)
			end
		else
			if hasOutbound then
				return function(...)
					return Ser.DeserializeArgsAndUnpack(rf:InvokeServer(ProcessOutbound(Ser.SerializeArgs(...))))
				end
			else
				return function(...)
					return Ser.DeserializeArgsAndUnpack(rf:InvokeServer(Ser.SerializeArgsAndUnpack(...)))
				end
			end
		end
	end
end

function Comm.Client.GetSignal(parent: Instance, name: string, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?)
	Debug.Assert(not IS_SERVER, "GetSignal must be called from the client")
	local folder = GetCommSubFolder(parent, "RE"):Expect("Failed to get Comm RE folder")
	local re = Debug.Assert(folder:WaitForChild(name, WAIT_FOR_CHILD_TIMEOUT), "Failed to find RemoteEvent: " .. name)
	return ClientRemoteSignal.new(re, inboundMiddleware, outboundMiddleware)
end

--[=[
	@class ServerComm
	@server
]=]
local ServerComm = {}
ServerComm.ClassName = "ServerComm"
ServerComm.__index = ServerComm

--[=[
	@within ServerComm
	@type ServerMiddlewareFn (player: Player, args: {any}) -> (shouldContinue: boolean, ...: any)
	The middleware function takes the client player and the arguments (as a table array), and should
	return `true|false` to indicate if the process should continue.

	If returning `false`, the optional varargs after the `false` are used as the new return values
	to whatever was calling the middleware.
]=]
--[=[
	@within ServerComm
	@type ServerMiddleware {ServerMiddlewareFn}
	Array of middleware functions.
]=]

--[=[
	@param parent Instance
	@param namespace string?
	@return ServerComm
	Constructs a ServerComm object. The `namespace` parameter is used
	in cases where more than one ServerComm object may be bound
	to the same object. Otherwise, a default namespace is used.
]=]
function ServerComm.new(parent: Instance, namespace: string?)
	Debug.Assert(IS_SERVER, "ServerComm must be constructed from the server")
	Debug.Assert(typeof(parent) == "Instance", "Parent must be of type Instance; got %q", parent)
	local ns = DEFAULT_COMM_FOLDER_NAME
	if namespace then
		ns = namespace
	end

	Debug.Assert(not parent:FindFirstChild(ns), "Parent already has another ServerComm bound to namespace " .. ns)
	local self = setmetatable({}, ServerComm)
	self._instancesFolder = Instance.new("Folder")
	self._instancesFolder.Name = ns
	self._instancesFolder.Parent = parent
	return self
end

--[=[
	@param name string
	@param fn (player: Player, ...: any) -> ...: any
	@param inboundMiddleware ServerMiddleware?
	@param outboundMiddleware ServerMiddleware?
	@return RemoteFunction
	Creates a RemoteFunction and binds the given function to it. Inbound
	and outbound middleware can be applied if desired.
]=]
function ServerComm:BindFunction(name: string, func: FnBind, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteFunction
	return Comm.Server.BindFunction(self._instancesFolder, name, func, inboundMiddleware, outboundMiddleware)
end

--[=[
	@param tbl table
	@param name string
	@param inboundMiddleware ServerMiddleware?
	@param outboundMiddleware ServerMiddleware?
	@return RemoteFunction
]=]
function ServerComm:WrapMethod(tbl: {}, name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?): RemoteFunction
	return Comm.Server.WrapMethod(self._instancesFolder, tbl, name, inboundMiddleware, outboundMiddleware)
end

--[=[
	@param name string
	@param inboundMiddleware ServerMiddleware?
	@param outboundMiddleware ServerMiddleware?
	@return RemoteSignal
]=]
function ServerComm:CreateSignal(name: string, inboundMiddleware: ServerMiddleware?, outboundMiddleware: ServerMiddleware?)
	return Comm.Server.CreateSignal(self._instancesFolder, name, inboundMiddleware, outboundMiddleware)
end

--[=[
	Destroy the ServerComm object.
]=]
function ServerComm:Destroy()
	self._instancesFolder:Destroy()
end

function ServerComm:__tostring()
	return "ServerComm"
end

--[=[
	@class ClientComm
	@client
]=]
local ClientComm = {}
ClientComm.ClassName = "ClientComm"
ClientComm.__index = ClientComm

--[=[
	@within ClientComm
	@type ClientMiddlewareFn (args: {any}) -> (shouldContinue: boolean, ...: any)
	The middleware function takes the arguments (as a table array), and should
	return `true|false` to indicate if the process should continue.

	If returning `false`, the optional varargs after the `false` are used as the new return values
	to whatever was calling the middleware.
]=]
--[=[
	@within ClientComm
	@type ClientMiddleware {ClientMiddlewareFn}
	Array of middleware functions.
]=]

--[=[
	@param parent Instance
	@param usePromise boolean
	@param namespace string?
	@return ClientComm
	Constructs a ClientComm object.

	If `usePromise` is set to `true`, then `GetFunction` will generate a function that returns a Promise
	that resolves with the server response. If set to `false`, the function will act like a normal
	call to a RemoteFunction and yield until the function responds.
]=]
function ClientComm.new(parent: Instance, usePromise: boolean, namespace: string?, janitor: _Janitor.Janitor?)
	Debug.Assert(not IS_SERVER, "ClientComm must be constructed from the client")
	Debug.Assert(typeof(parent) == "Instance", "Parent must be of type Instance; got %q", parent)
	local ns = DEFAULT_COMM_FOLDER_NAME
	if namespace then
		ns = namespace
	end

	local folder: Instance? = parent:WaitForChild(ns, WAIT_FOR_CHILD_TIMEOUT)
	Debug.Assert(folder ~= nil, "Could not find namespace for ClientComm in parent: " .. ns)
	local self = setmetatable({}, ClientComm)
	self._instancesFolder = folder
	self._usePromise = usePromise
	if janitor then
		janitor:Add(self, "Destroy")
	end

	return self
end

--[=[
	@param name string
	@param inboundMiddleware ClientMiddleware?
	@param outboundMiddleware ClientMiddleware?
	@return (...: any) -> any

	Generates a function on the matching RemoteFunction generated with ServerComm. The function
	can then be called to invoke the server. If this `ClientComm` object was created with
	the `usePromise` parameter set to `true`, then this generated function will return
	a Promise when called.

	```lua
	-- Server-side:
	local serverComm = ServerComm.new(someParent)
	serverComm:BindFunction("MyFunction", function(player, msg)
		return msg:upper()
	end)

	-- Client-side:
	local clientComm = ClientComm.new(someParent)
	local myFunc = clientComm:GetFunction("MyFunction")
	local uppercase = myFunc("hello world")
	print(uppercase) --> HELLO WORLD

	-- Client-side, using promises:
	local clientComm = ClientComm.new(someParent, true)
	local myFunc = clientComm:GetFunction("MyFunction")
	myFunc("hi there"):andThen(function(msg)
		print(msg) --> HI THERE
	end):catch(function(err)
		print("Error:", err)
	end)
	```
]=]
function ClientComm:GetFunction(name: string, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?)
	return Comm.Client.GetFunction(self._instancesFolder, name, self._usePromise, inboundMiddleware, outboundMiddleware)
end

--[=[
	@param name string
	@param inboundMiddleware ClientMiddleware?
	@param outboundMiddleware ClientMiddleware?
	@return ClientRemoteSignal
	Returns a new ClientRemoteSignal that mirrors the matching RemoteSignal created by
	ServerComm with the same matching `name`.
]=]
function ClientComm:GetSignal(name: string, inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?)
	return Comm.Client.GetSignal(self._instancesFolder, name, inboundMiddleware, outboundMiddleware)
end

--[=[
	@param inboundMiddleware ClientMiddleware?
	@param outboundMiddleware ClientMiddleware?
	@return table
	Returns an object which maps RemoteFunctions as methods
	and RemoteEvents as fields.
	```lua
	-- Server-side:
	serverComm:BindFunction("Test", function(player) end)
	serverComm:CreateSignal("MySignal")

	-- Client-side
	local obj = clientComm:BuildObject()
	obj:Test()
	obj.MySignal:Connect(function() end)
	```
]=]
function ClientComm:BuildObject(inboundMiddleware: ClientMiddleware?, outboundMiddleware: ClientMiddleware?)
	local obj = {}
	local rfFolder = self._instancesFolder:FindFirstChild("RF")
	local reFolder = self._instancesFolder:FindFirstChild("RE")
	if rfFolder then
		for _, rf in ipairs(rfFolder:GetChildren()) do
			if not rf:IsA("RemoteFunction") then
				continue
			end

			local f = self:GetFunction(rf.Name, inboundMiddleware, outboundMiddleware)
			obj[rf.Name] = function(_, ...)
				return f(Ser.SerializeArgsAndUnpack(...))
			end
		end
	end

	if reFolder then
		for _, re in ipairs(reFolder:GetChildren()) do
			if not re:IsA("RemoteEvent") then
				continue
			end

			obj[re.Name] = self:GetSignal(re.Name, inboundMiddleware, outboundMiddleware)
		end
	end

	return obj
end

--[=[
	Destroys the ClientComm object.
]=]
function ClientComm:Destroy() end
function ClientComm:__tostring()
	return "ClientComm"
end

Comm.ServerComm = ServerComm
Comm.ClientComm = ClientComm

table.freeze(Comm)
return Comm
