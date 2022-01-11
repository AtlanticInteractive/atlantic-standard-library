local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Knit)
Knit.Shared = ReplicatedStorage.Shared
Knit.Modules = ServerStorage.Modules

Knit.AddServices(ServerStorage.Services)
Knit.Start():ThenCall(print, "Started Knit!"):Catch(warn)
