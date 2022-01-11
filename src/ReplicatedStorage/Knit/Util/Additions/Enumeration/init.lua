local Enumeration = require(script.Enumeration)

Enumeration.ContainerStatus = {
	Success = 100;
	NotReady = 200;
}

Enumeration.DataStoreHandler = {"ForceLoad", "Steal", "Repeat", "Cancel"}

return Enumeration
