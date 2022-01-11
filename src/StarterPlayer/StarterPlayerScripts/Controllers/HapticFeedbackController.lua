local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HapticService = game:GetService("HapticService")

local Knit = require(ReplicatedStorage.Knit)
local Promise = require(ReplicatedStorage.Knit.Util.Promise)

local HapticFeedbackController = Knit.CreateController({
	Name = "HapticFeedbackController";
})

function HapticFeedbackController:SetVibrationMotor(UserInputType: Enum.UserInputType, VibrationMotor: Enum.VibrationMotor, Amplitude: number, ...)
	if not HapticService:IsVibrationSupported(UserInputType) or not HapticService:IsMotorSupported(UserInputType, VibrationMotor) then
		return false
	end

	HapticService:SetMotor(UserInputType, VibrationMotor, Amplitude, ...)
	return true
end

function HapticFeedbackController:SetSmallVibration(UserInputType: Enum.UserInputType, Amplitude: number)
	return self:SetVibrationMotor(UserInputType, Enum.VibrationMotor.Small, Amplitude)
end

function HapticFeedbackController:SetLargeVibration(UserInputType: Enum.UserInputType, Amplitude: number)
	return self:SetVibrationMotor(UserInputType, Enum.VibrationMotor.Large, Amplitude)
end

function HapticFeedbackController:SmallVibrate(UserInputType: Enum.UserInputType, Length: number?, PossibleAmplitude: number?)
	local Amplitude = PossibleAmplitude or 1
	if self:SetSmallVibration(UserInputType, Amplitude) then
		local ResetMotor = Promise.Delay(Length or 0.1)
		ResetMotor:Finally(function()
			self:SetSmallVibration(UserInputType, 0)
		end)

		return ResetMotor
	else
		return Promise.Resolve()
	end
end

function HapticFeedbackController:LargeVibrate(UserInputType: Enum.UserInputType, Length: number?, PossibleAmplitude: number?)
	local Amplitude = PossibleAmplitude or 1
	if self:SetLargeVibration(UserInputType, Amplitude) then
		local ResetMotor = Promise.Delay(Length or 0.1)
		ResetMotor:Finally(function()
			self:SetLargeVibration(UserInputType, 0)
		end)

		return ResetMotor
	else
		return Promise.Resolve()
	end
end

return HapticFeedbackController
