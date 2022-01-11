local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Knit = require(ReplicatedStorage.Knit)
Knit.Shared = ReplicatedStorage.Shared
Knit.Modules = StarterPlayerScripts.Modules

Knit.AddControllers(StarterPlayerScripts.Controllers)
Knit.Start():ThenCall(print, "Started Knit!"):Catch(warn)
