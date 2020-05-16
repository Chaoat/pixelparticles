local PixelParticles = require('pixelParticles')
local PixelForces = require('pixelForces')
local profile = require('profile')

local debugSetting = nil
local running = true

local testCanvas
function love.load()
	math.randomseed(os.clock())
	
	testCanvas = PixelParticles.newCanvas(504, 304, 200)
	--PixelParticles.setOpenSides(testCanvas, {true, true}, {true, true})
	
	PixelParticles.addImage(testCanvas, 250, 150, canvasFromImage("images/test2.png"))
	
	--PixelParticles.addForce(testCanvas, PixelForces.uniformAcceleration(math.pi/2, 100, -1))
	PixelParticles.addForce(testCanvas, PixelForces.borderBounce(0.5))
	--PixelParticles.addForce(testCanvas, PixelForces.colourSort(10))
	
	--PixelParticles.addForce(testCanvas, PixelForces.windyWaysFromPoint(testCanvas, 50, 250, 150, 1/50))
	--PixelParticles.addForce(testCanvas, PixelForces.setSpace(PixelForces.windyWays(testCanvas, 30, -0.1, 1/20), {0, 0, 1, 0.3}, {0, 0, 0, 0.02}))
	--PixelParticles.addForce(testCanvas, PixelForces.setSpace(PixelForces.uniformAcceleration(0.5, 30, -1), {0, 0, 1, 0.3}, {0, 0, 0, 0.02}))
	--PixelParticles.addForce(testCanvas, PixelForces.uniformAcceleration(0, 50, -1))
	
	
	profile.start()
end

function canvasFromImage(imageName)
	local image = love.graphics.newImage(imageName)
	local newCanvas = love.graphics.newCanvas(image:getWidth(), image:getHeight())
	
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setCanvas(newCanvas)
	love.graphics.draw(image, 0, 0)
	love.graphics.setCanvas()
	
	return newCanvas
end

local globalTimer = 0
function love.update(dt)
	if running then
		PixelParticles.update(testCanvas, dt)
		--PixelParticles.shiftCanvas(testCanvas, 1, 1)
	end
	
	globalTimer = globalTimer + dt
	if globalTimer > 10 then
		profile.stop()
		print(profile.report(100))
		globalTimer = -999
	end
end

function love.mousepressed(x, y, key)
	if key == 1 then
		PixelParticles.addForce(testCanvas, PixelForces.explosionForce(x, y, 100, 30))
	end
end

function love.keypressed(key, scancode, isrepeat)
	PixelParticles.update(testCanvas, 0)
	
	if key == "f1" then
		debugSetting = nil
	elseif key == "f2" then
		debugSetting = "speed"
	elseif key == "f3" then
		debugSetting = "move"
	elseif key == "f4" then
		debugSetting = "force"
	elseif key == "f5" then
		debugSetting = "delete"
	elseif key == "space" then
		if running then
			running = false
		else
			running = true
		end
	end
end

function love.draw()
	PixelParticles.drawCanvas(testCanvas, 0, 0, 1, debugSetting)
	
	--love.graphics.setColor(1, 0, 0, 0.3)
	--love.graphics.draw(TESTIMAGE)
end