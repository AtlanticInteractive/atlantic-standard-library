local Fmt = require(script.Parent.Fmt)

local Logger = {}
Logger.ClassName = "Logger"
Logger.__index = Logger

--[[**
	Creates a new Logger.
	@param [t:string] Prefix The prefix for the log messages.
	@param [t:boolean?] IsEnabled Whether or not the logger is enabled by default.
	@returns [t:Logger]
**--]]
function Logger.new(Prefix: string, IsEnabled: boolean?)
	return setmetatable({
		Enabled = not not IsEnabled;
		Prefix = Prefix;
	}, Logger)
end

--[[**
	Sets whether or not the Logger is enabled.
	@param [t:boolean] Enabled Whether or not the logger is enabled.
	@returns [t:Logger]
**--]]
function Logger:SetEnabled(Enabled: boolean)
	self.Enabled = Enabled
	return self
end

--[[**
	Sets the prefix of the log messages.
	@param [t:string] Prefix The new prefix.
	@returns [t:Logger]
**--]]
function Logger:SetPrefix(Prefix: string)
	self.Prefix = Prefix
	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[TRACE/Prefix]: FormatString` using `print`. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Trace(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Result = pcall(Fmt, FormatString, ...)
		if Success then
			print("[TRACE/" .. self.Prefix .. "]:", Result)
		else
			print("[TRACE/" .. self.Prefix .. "]:", FormatString, ...)
		end
	end

	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[DEBUG/Prefix]: FormatString` using `print`. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Debug(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Result = pcall(Fmt, FormatString, ...)
		if Success then
			print("[DEBUG/" .. self.Prefix .. "]:", Result)
		else
			print("[DEBUG/" .. self.Prefix .. "]:", FormatString, ...)
		end
	end

	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[INFO/Prefix]: FormatString` using `print`. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Info(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Result = pcall(Fmt, FormatString, ...)
		if Success then
			print("[INFO/" .. self.Prefix .. "]:", Result)
		else
			print("[INFO/" .. self.Prefix .. "]:", FormatString, ...)
		end
	end

	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[WARNING/Prefix]: FormatString` using `warn`. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Warning(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Result = pcall(Fmt, FormatString, ...)
		if Success then
			warn("[WARNING/" .. self.Prefix .. "]:", Result)
		else
			warn("[WARNING/" .. self.Prefix .. "]:", FormatString, ...)
		end
	end

	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[WARNING/Prefix]: FormatString` using `warn`. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Warn(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Result = pcall(Fmt, FormatString, ...)
		if Success then
			warn("[WARNING/" .. self.Prefix .. "]:", Result)
		else
			warn("[WARNING/" .. self.Prefix .. "]:", FormatString, ...)
		end
	end

	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[ERROR/Prefix]: FormatString` using `error` on a separate thread. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Error(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Value = pcall(Fmt, FormatString, ...)
		if Success then
			task.defer(error, string.format("[ERROR/" .. self.Prefix .. "]: %s", Value), 2)
		else
			local Length = select("#", ...)
			local Array = table.create(Length + 1, FormatString)
			for Index = 1, Length do
				Array[Index + 1] = tostring(select(Index, ...))
			end

			task.defer(error, string.format("[ERROR/" .. self.Prefix .. "]: %s", table.concat(Array, " ")))
		end
	end

	return self
end

--[[**
	If the logger is enabled, this will print a message with the format `[FATAL/Prefix]: FormatString` using `error` on a separate thread. The arguments are formatted using Fmt.
	@param [t:string] FormatString The message to print.
	@param [t:...any?] ... The arguments to format with.
	@returns [t:Logger]
**--]]
function Logger:Fatal(FormatString: string, ...)
	if self.Enabled then
		FormatString = tostring(FormatString)
		local Success, Value = pcall(Fmt, FormatString, ...)
		if Success then
			error(string.format("[ERROR/" .. self.Prefix .. "]: %s", Value), 2)
		else
			local Length = select("#", ...)
			local Array = table.create(Length + 1, FormatString)
			for Index = 1, Length do
				Array[Index + 1] = tostring(select(Index, ...))
			end

			error(string.format("[ERROR/" .. self.Prefix .. "]: %s", table.concat(Array, " ")))
		end
	end

	return self
end

function Logger:__tostring()
	return "Logger"
end

export type Logger = typeof(Logger.new("LoggerName"))
table.freeze(Logger)
return Logger
