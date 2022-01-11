local SyncedClock = {}
SyncedClock.ClassName = "SyncedClock"
SyncedClock.__index = SyncedClock

local function GetOptional(Options, Name, Default)
	if not Options or Options[Name] == nil then
		return Default
	else
		return Options[Name]
	end
end

function SyncedClock.new(Options: {ShouldLerp: boolean?}?)
	return setmetatable({
		ShouldLerp = GetOptional(Options, "ShouldLerp", true);

		Offset = nil;

		OffsetAccuracy = nil;

		OffsetLerpClockStart = nil;
		OffsetLerpClockEnd = nil;
		OffsetLerpValueStart = nil;
		OffsetLerpValueDiff = nil;
	}, SyncedClock)
end

function SyncedClock:GetOffset(CurrentTime): number
	CurrentTime = CurrentTime or os.clock()
	local OffsetLerpClockEnd = self.OffsetLerpClockEnd

	if OffsetLerpClockEnd then
		local OffsetLerpClockStart = self.OffsetLerpClockStart
		local OffsetLerpValueStart = self.OffsetLerpValueStart

		if OffsetLerpClockEnd < CurrentTime then
			self.OffsetLerpClockStart = nil
			self.OffsetLerpClockEnd = nil
			self.OffsetLerpValueStart = nil
			self.OffsetLerpValueDiff = nil
		elseif OffsetLerpClockStart > CurrentTime then
			return OffsetLerpValueStart
		else
			local LerpPercent = (CurrentTime - OffsetLerpClockStart) / (OffsetLerpClockEnd - OffsetLerpClockStart)
			return OffsetLerpValueStart + self.OffsetLerpValueDiff * LerpPercent
		end
	end

	return self.Offset
end

function SyncedClock:GetTime(CurrentTime)
	assert(self.Offset, "[NetworkClock] Time not synced yet")
	return (CurrentTime or os.clock()) + self:GetOffset(CurrentTime)
end

function SyncedClock:GetRawTime(CurrentTime)
	return (CurrentTime or os.clock()) + assert(self.Offset, "[NetworkClock] Time not synced yet")
end

function SyncedClock:GetAccuracy()
	return self.OffsetAccuracy
end

function SyncedClock:IsNewOffsetPreferred(Offset, Accuracy)
	if not self.Offset or Accuracy < self.OffsetAccuracy or math.abs(Offset - self.Offset) > (self.OffsetAccuracy + Accuracy) / 2 then
		return true
	end

	return false
end

function SyncedClock:TrySetOffset(Offset, Accuracy)
	Accuracy = Accuracy or 0

	if not self:IsNewOffsetPreferred(Offset, Accuracy) then
		return
	end

	if self.Offset and self.ShouldLerp then
		local CurrentTime = os.clock()

		-- Calculate the lerp time:
		-- Typically, lerping for the amount of time the offset changed is okay
		-- When the offset moves backwards, we have to lerp twice as long or time "stops"
		local BaseOffset = self:GetOffset(CurrentTime)
		local OffsetDifference = Offset - BaseOffset
		if OffsetDifference < 0 then
			local MinTime = math.abs(OffsetDifference) * 1.1
			local MaxTime = math.max(60, MinTime)
			self.OffsetLerpClockEnd = CurrentTime + math.min(math.abs(OffsetDifference) * 2, MaxTime)
		else
			self.OffsetLerpClockEnd = CurrentTime + math.abs(OffsetDifference)
		end

		self.OffsetLerpClockStart = CurrentTime
		self.OffsetLerpValueStart = BaseOffset
		self.OffsetLerpValueDiff = Offset - BaseOffset
	end

	self.Offset = Offset
	self.OffsetAccuracy = Accuracy
end

SyncedClock.__call = SyncedClock.GetTime
function SyncedClock:__tostring()
	return "SyncedClock"
end

export type SyncedClock = typeof(SyncedClock.new())
table.freeze(SyncedClock)
return SyncedClock
