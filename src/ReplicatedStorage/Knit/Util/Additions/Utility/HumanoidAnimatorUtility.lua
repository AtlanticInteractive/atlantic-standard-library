--[=[
	Utility functions involving [Animator] underneath a humanoid. These are used
	because the [Animator] is the preferred API surface by Roblox.

	@class HumanoidAnimatorUtility
]=]

local HumanoidAnimatorUtility = {}

--[=[
	Gets a humanoid animator for a given humanoid

	:::warning
	There is undefined behavior when using this on the client when the server
	does not already have an animator. Doing so may break replication. I'm not sure.
	:::

	@param humanoid Humanoid
	@return Animator
]=]
function HumanoidAnimatorUtility.GetOrCreateAnimator(Humanoid: Humanoid): Animator
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Name = "Animator"
		Animator.Parent = Humanoid
	end

	return Animator
end

--[=[
	Stops all animations from playing.

	@param humanoid Humanoid
	@param fadeTime number? -- Optional fade time to stop animations. Defaults to 0.1.
]=]
function HumanoidAnimatorUtility.StopAnimations(Humanoid: Humanoid, FadeTime: number?)
	for _, AnimationTrack in ipairs(HumanoidAnimatorUtility.GetOrCreateAnimator(Humanoid):GetPlayingAnimationTracks()) do
		AnimationTrack:Stop(FadeTime)
	end
end

--[=[
	Returns whether a track is being played.

	@param humanoid Humanoid
	@param track AnimationTrack
	@return boolean
]=]
function HumanoidAnimatorUtility.IsPlayingAnimationTrack(Humanoid: Humanoid, AnimationTrack: AnimationTrack)
	return table.find(HumanoidAnimatorUtility.GetOrCreateAnimator(Humanoid):GetPlayingAnimationTracks(), AnimationTrack) ~= nil
end

table.freeze(HumanoidAnimatorUtility)
return HumanoidAnimatorUtility
