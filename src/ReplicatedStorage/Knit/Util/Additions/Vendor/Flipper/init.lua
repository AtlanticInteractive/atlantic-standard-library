local ImpulseSpring = require(script.ImpulseSpring)

local Flipper = {}

Flipper.SingleMotor = require(script.SingleMotor)
Flipper.GroupMotor = require(script.GroupMotor)

Flipper.ImpulseSpring = ImpulseSpring
Flipper.Instant = require(script.Instant)
Flipper.Linear = require(script.Linear)
Flipper.QuentySpring = ImpulseSpring
Flipper.Spring = require(script.Spring)

Flipper.IsMotor = require(script.IsMotor)

return Flipper
