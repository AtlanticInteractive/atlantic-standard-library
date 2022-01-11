local Context = {}

function Context.new(Base, KeyPath, Config, Active, RegistryKey)
	return {
		Active = Active;
		Base = Base;
		Config = Config;
		KeyPath = KeyPath;
		RegistryKey = RegistryKey;
	}
end

table.freeze(Context)
return Context
