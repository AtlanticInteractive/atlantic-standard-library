--[[
	Knit.CreateController(controller): Controller
	Knit.AddControllers(folder): Controller[]
	Knit.AddControllersDeep(folder): Controller[]
	Knit.GetService(serviceName): Service
	Knit.GetController(controllerName): Controller
	Knit.Start(): Promise<void>
	Knit.OnStart(): Promise<void>
--]]

local Players = game:GetService("Players")
local Comm = require(script.Parent.Util.Comm)
local Debug = require(script.Parent.Util.Additions.Debugging.Debug)
local Promise = require(script.Parent.Util.Promise)

local ClientComm = Comm.ClientComm

--[=[
	@interface ControllerDef
	.Name string
	.[any] any
	@within KnitClient
]=]
type ControllerDef = {
	Name: string,
	[any]: any,
}

--[=[
	@interface Controller
	.Name string
	.[any] any
	@within KnitClient
]=]
type Controller = {
	Name: string,
	[any]: any,
}

--[=[
	@interface Service
	.[any] any
	@within KnitClient
]=]
type Service = {
	[any]: any,
}

--[=[
	@interface KnitOptions
	.ServicePromises boolean -- Defaults to `true`
	@within KnitClient

	`ServicePromises` defaults to `true` and indicates if service methods use promises.
]=]
type KnitOptions = {
	ServicePromises: boolean,
}

local defaultOptions: KnitOptions = {
	ServicePromises = false;
}

local selectedOptions = nil

--[=[
	@class KnitClient
	@client
]=]
local KnitClient = {}

--[=[
	@prop Player Player
	@within KnitClient
	@readonly
	Reference to the LocalPlayer.
]=]
KnitClient.Player = Players.LocalPlayer

--[=[
	@prop Util Folder
	@within KnitClient
	@readonly
	References the Util folder. Should only be accessed when using Knit as
	a standalone module. If using Knit from Wally, modules should just be
	pulled in via Wally instead of relying on Knit's Util folder, as this
	folder only contains what is necessary for Knit to run in Wally mode.
]=]
KnitClient.Util = script.Parent.Util

local controllers: {[string]: Controller} = {}
local services: {[string]: Service} = {}
local servicesFolder = nil

local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local function BuildService(serviceName: string, folder: Instance): Service
	local service = ClientComm.new(folder, selectedOptions.ServicePromises):BuildObject()
	services[serviceName] = service
	return service
end

local function DoesControllerExist(controllerName: string): boolean
	local controller: Controller? = controllers[controllerName]
	return controller ~= nil
end

local function GetServicesFolder()
	if not servicesFolder then
		servicesFolder = script.Parent:WaitForChild("Services")
	end

	return servicesFolder
end

--[=[
	@param controllerDefinition ControllerDef
	@return Controller
	Creates a new controller.
]=]
function KnitClient.CreateController(controllerDef: ControllerDef): Controller
	Debug.Assert(type(controllerDef) == "table", "Controller must be a table; got %q", controllerDef)
	Debug.Assert(type(controllerDef.Name) == "string", "Controller.Name must be a string; got %q", controllerDef.Name)
	Debug.Assert(#controllerDef.Name > 0, "Controller.Name must be a non-empty string")
	Debug.Assert(not DoesControllerExist(controllerDef.Name), "Controller \"" .. controllerDef.Name .. "\" already exists")

	local controller = controllerDef :: Controller
	controllers[controller.Name] = controller
	return controller
end

--[=[
	@param parent Instance
	@return controllers: {Controller}
	Requires all the modules that are children of the given parent. This is an easy
	way to quickly load all controllers that might be in a folder.
	```lua
	Knit.AddControllers(somewhere.Controllers)
	```
]=]
function KnitClient.AddControllers(parent: Instance): {Controller}
	local addedControllers = {}
	for _, v in ipairs(parent:GetChildren()) do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

--[=[
	@param parent Instance
	@return controllers: {Controller}
	Requires all the modules that are descendants of the given parent.
]=]
function KnitClient.AddControllersDeep(parent: Instance): {any}
	local addedControllers = {}
	for _, v in ipairs(parent:GetDescendants()) do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

--[=[
	@param serviceName string
	@return Service?
	Returns a Service object which is a reflection of the remote objects
	within the Client table of the given service. Returns `nil` if the
	service is not found.

	:::caution
	Services are only exposed to the client if the service has remote-based
	content in the Client table. If not, the service will not be visible
	to the client. `KnitClient.GetService` will only work on services that
	expose remote-based content on their Client tables.
	:::
]=]
function KnitClient.GetService(serviceName: string): Service
	Debug.Assert(type(serviceName) == "string", "ServiceName must be a string; got %q", serviceName)
	local folder: Instance = Debug.Assert(GetServicesFolder():FindFirstChild(serviceName), "Could not find service \"" .. serviceName .. "\". Check the service name and that the service has client-facing methods/RemoteSignals/RemoteProperties.")
	return services[serviceName] or BuildService(serviceName, folder)
end

--[=[
	@param controllerName string
	@return Controller?
	Gets the controller by name. Throws an error if the controller
	is not found.
]=]
function KnitClient.GetController(controllerName: string): Controller
	Debug.Assert(type(controllerName) == "string", "ControllerName must be a string; got %q", controllerName)
	return Debug.Assert(controllers[controllerName], " Could not find controller \"" .. controllerName .. "\". Check to verify a controller with this name exists.")
end

--[=[
	@param options KnitOptions?
	@return Promise
	Starts Knit. Should only be called once per client.
	```lua
	Knit.Start():Then(function()
		print("Knit started!")
	end):Catch(warn)
	```

	By default, service methods exposed to the client will return promises.
	To change this behavior, set the `ServicePromises` option to `false`:
	```lua
	Knit.Start({ServicePromises = false}):Then(function()
		print("Knit started!")
	end):Catch(warn)
	```
]=]
function KnitClient.Start(options: KnitOptions?)
	if started then
		return Promise.Reject("Knit already started")
	end

	started = true
	if options == nil then
		selectedOptions = defaultOptions
	else
		Debug.Assert(type(options) == "table", "KnitOptions should be a table or nil; got %q", options)
		selectedOptions = options
	end

	return Promise.new(function(resolve)
		-- Init:
		local promisesStartControllers = {}
		for _, controller in next, controllers do
			if type(controller.KnitInit) == "function" then
				table.insert(promisesStartControllers, Promise.new(function(r)
					controller:KnitInit()
					r()
				end))
			end
		end

		resolve(Promise.All(promisesStartControllers))
	end):Then(function()
		-- Start:
		for _, controller in next, controllers do
			if type(controller.KnitStart) == "function" then
				task.spawn(controller.KnitStart, controller)
			end
		end

		startedComplete = true
		onStartedComplete:Fire()

		task.defer(function()
			onStartedComplete:Destroy()
		end)
	end)
end

--[=[
	@return Promise
	Returns a promise that is resolved once Knit has started. This is useful
	for any code that needs to tie into Knit controllers but is not the script
	that called `Start`.
	```lua
	Knit.OnStart():Then(function()
		local MyController = Knit.GetController("MyController")
		MyController:DoSomething()
	end):Catch(warn)
	```
]=]
function KnitClient.OnStart()
	if startedComplete then
		return Promise.Resolve()
	else
		return Promise.FromEvent(onStartedComplete.Event)
	end
end

return KnitClient
