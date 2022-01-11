local ServerStorage = game:GetService("ServerStorage")
local BaseReplicaService = require(ServerStorage.Modules.Vendor.ReplicaService)

export type Replica<Value> = BaseReplicaService.Replica<Value>
export type ClassToken = {Class: string} & {[any]: any}
type Replication = string | {[Player]: boolean} | Player

export type ReplicaParameters = {
	ClassToken: ClassToken,
	Data: {[any]: any}?,
	Parent: Replica<any>?,
	Replication: Replication?,
	Tags: {[any]: any}?,
	WriteLib: ModuleScript?,
}

return false
