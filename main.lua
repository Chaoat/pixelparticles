local PixelParticles = require('pixelParticles')
local PixelForces = require('pixelForces')
local profile = require('profile')

local debugSetting = nil
local running = true

local testCanvas
function love.load()
	math.randomseed(os.clock())
	
	testCanvas = PixelParticles.newCanvas(504, 304, 500)
	--PixelParticles.setOpenSides(testCanvas, {true, true}, {true, true})
	
	--PixelParticles.addImage(testCanvas, 250, 150, canvasFromImage("images/test1.png"))
	--PixelParticles.addImage(testCanvas, 250, 150, generateRandomPoints(testCanvas.xSize, testCanvas.ySize, 4000, {1, 234/255, 99/255, 1}, {0.5, 80/255, 20/255, 1}))
	
	--PixelParticles.addForce(testCanvas, PixelForces.explosionForce(250, 150, 200, 300))
	
	--PixelParticles.addForce(testCanvas, PixelForces.uniformAcceleration(math.pi/2, 100, -1))
	PixelParticles.addForce(testCanvas, PixelForces.borderBounce(0.5))
	--PixelParticles.addForce(testCanvas, PixelForces.colourSort(10))
	
	--PixelParticles.addForce(testCanvas, PixelForces.collectToImage(canvasFromImage("images/texTest2.png", testCanvas.xSize, testCanvas.ySize), 100, -1))
	
	PixelParticles.addForce(testCanvas, PixelForces.windyWaysFromPoint(testCanvas, 50, 250, 150, 1/50))
	--PixelParticles.addForce(testCanvas, PixelForces.setSpace(PixelForces.windyWays(testCanvas, 30, -0.1, 1/20), {0, 0, 1, 0.3}, {0, 0, 0, 0.02}))
	--PixelParticles.addForce(testCanvas, PixelForces.setSpace(PixelForces.uniformAcceleration(0.5, 30, -1), {0, 0, 1, 0.3}, {0, 0, 0, 0.02}))
	--PixelParticles.addForce(testCanvas, PixelForces.uniformAcceleration(0, 50, -1))
	
	PixelParticles.addPixelSource(testCanvas, 230, 130, 270, 170, {1, 234/255, 99/255, 1}, {0.5, 80/255, 20/255, 1}, 2000)
	
	
	profile.start()
end

function canvasFromImage(imageName, width, height)
	local image = love.graphics.newImage(imageName)
	if width == nil then
		width = image:getWidth()
	end
	if height == nil then
		height = image:getHeight()
	end
	local newCanvas = love.graphics.newCanvas(width, height)
	
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setCanvas(newCanvas)
	love.graphics.draw(image, 0, 0)
	love.graphics.setCanvas()
	
	return newCanvas
end

function generateRandomPoints(width, height, nPoints, col1, col2)
	if col1 == nil then
		col1 = {1, 1, 1, 1}
	end
	
	local rectangle, rand, setCol = love.graphics.rectangle, math.random, love.graphics.setColor
	
	local canvas = love.graphics.newCanvas(width, height)
	
	local cutoff = nPoints/(width*height)
	
	love.graphics.setCanvas(canvas)
	setCol(col1)
	for i = 1, width do
		for j = 1, height do
			randNumber = rand()
			if randNumber <= cutoff then
				if col2 then
					local ratio = randNumber/cutoff
					setCol(col1[1] + ratio*(col2[1] - col1[1]), col1[2] + ratio*(col2[2] - col1[2]), col1[3] + ratio*(col2[3] - col1[3]), col1[4] + ratio*(col2[4] - col1[4]))
				end
				rectangle('fill', i, j, 1, 1)
			end
		end
	end
	love.graphics.setCanvas()
	
	return canvas
end

local globalTimer = 0
function love.update(dt)
	if running then
		PixelParticles.update(testCanvas, dt)
		--PixelParticles.shiftCanvas(testCanvas, 1, 1)
		
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
		PixelParticles.addForce(testCanvas, PixelForces.explosionForce(x, y, 500, 300))
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
	
	--love.graphics.setColor(1, 1, 1, 0.3)
	--love.graphics.draw(TESTIMAGE)
end