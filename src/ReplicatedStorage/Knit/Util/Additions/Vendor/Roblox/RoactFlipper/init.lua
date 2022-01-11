local GetBinding = require(script.GetBinding)
local UseGoal = require(script.UseGoal)
local UseImpulseSpring = require(script.UseImpulseSpring)
local UseInstant = require(script.UseInstant)
local UseLinear = require(script.UseLinear)
local UseMotor = require(script.UseMotor)
local UseSpring = require(script.UseSpring)

local RoactFlipper = {}

RoactFlipper.GetBinding = GetBinding
RoactFlipper.UseGoal = UseGoal
RoactFlipper.UseImpulseSpring = UseImpulseSpring
RoactFlipper.UseInstant = UseInstant
RoactFlipper.UseLinear = UseLinear
RoactFlipper.UseMotor = UseMotor
RoactFlipper.UseSpring = UseSpring

table.freeze(RoactFlipper)
return RoactFlipper
