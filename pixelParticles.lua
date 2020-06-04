local PixelForces = require("pixelForces")

local PixelParticles = {}

--MoveMap and SpeedMap go with the pixels, they move around with them.
--Need two maps for each then
--if the force has [2] == 1, then it is a valid force that should be used.

--Going to scan the adjacent pixels in the movementShader to find the pixel that needs to be moved.

--What about when two pixels try and move into the same position?
--Need some kind of remove map to go after.
--Move all the pixels, and write the position they were removed from for each pixel. Then write again to remove the pixels. Have to do another scan, but eh.

local initSpeedShader = love.graphics.newShader [[
	extern Image imageMap;
	
	vec4 effect(vec4 colour, Image lastSpeedMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cPixel = Texel(imageMap, texture_coords);
		vec4 speedPixel = Texel(lastSpeedMap, texture_coords);
		if (cPixel[3] > 0 && speedPixel[3] == 0) {
			return vec4(0.5, 0.5, 0, 1);
		}
		return speedPixel;
	}
]]

local moveMapShader = love.graphics.newShader [[
	extern Image speedMap;
	extern Image imageMap;
	
	vec4 effect(vec4 colour, Image lastMoveMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 currentMove = Texel(lastMoveMap, texture_coords);
		vec4 cPixel = Texel(imageMap, texture_coords);
		if (cPixel[3] > 0) {
			if (currentMove[3] == 1) {
				vec4 force = Texel(speedMap, texture_coords);
				
				number newX = currentMove[0];
				if (newX < 0.25) {
					newX = newX + 0.25;
				} else if (newX > 0.75) {
					newX = newX - 0.25;
				}
				newX = newX + (force[0] - 0.5)/2;
				
				number newY = currentMove[1];
				if (newY < 0.25) {
					newY = newY + 0.25;
				} else if (newY > 0.75) {
					newY = newY - 0.25;
				}
				newY = newY + (force[1] - 0.5)/2;
				
				//number newX = mod(currentMove[0], 0.5) + max(force[0] - 0.5, 0);
				//number newNegX = mod(currentMove[1], 0.5) + max(0.5 - force[0], 0);
				//number newY = mod(currentMove[2], 0.5) + max(force[1] - 0.5, 0);
				//number newNegY = mod(currentMove[3], 0.5) + max(0.5 - force[1], 0);
				
				return vec4(newX, newY, 0, 1);
			} else {
				return vec4(0.5, 0.5, 0, 1);
			}
		} else {
			//return vec4(0, 0, 0, 0);
		}
	}
]]

local forceShader = love.graphics.newShader [[
	extern Image imageMap;
	
	vec4 effect(vec4 colour, Image moveMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cPixel = Texel(imageMap, texture_coords);
		if (cPixel[3] > 0) {
			vec4 moves = Texel(moveMap, texture_coords);
			//moves = vec4(0.5, 0.5, 0, 1);
			//if (Texel(imageMap, texture_coords)[3] == 1) {
			//	moves[0] = 1;
			//}
			vec2 offset = vec2(0, 0);
			
			offset[0] = floor(moves[0] - 0.25) + ceil(moves[0] - 0.75);
			offset[1] = floor(moves[1] - 0.25) + ceil(moves[1] - 0.75);
			
			if ((offset[0] != 0) || (offset[1] != 0)) {
				vec4 newPixel = Texel(imageMap, texture_coords + vec2(offset[0]/love_ScreenSize.x, offset[1]/love_ScreenSize.y));
				
				return vec4(0.5 + offset[0]/2, 0.5 + offset[1]/2, 1, 1);
			}
		}
		return vec4(0, 0, 0, 0);
    }
]]

local movementShader = love.graphics.newShader [[
	extern Image forceMap;
	extern Image oldPositionMap; //love_Canvases[0]
	extern Image oldSpeedMap; //love_Canvases[1]
	extern Image oldMoveMap; //love_Canvases[2]
	//love_Canvases[3] is the deletionMap
	
	extern number fTRatio;
	
	vec4 correctSpeedMagnitude(vec4 speed) {
		if ((mod(speed[0], 1) != speed[0]) || (mod(speed[1], 1) != speed[1])) {
			number angle = atan(speed[1] - 0.5, speed[0] - 0.5);
			speed[0] = 0.5 + 0.5*cos(angle);
			speed[1] = 0.5 + 0.5*sin(angle);
		}
		return speed;
	}
	
	vec4 addAdjForces(vec2 texture_coords) {
		vec2 offset = vec2(0, 0);
		vec2 forces = vec2(0, 0);
		for (int i = -1; i<=1; i++) {
			offset[0] = i/love_ScreenSize.x;
			for (int j = -1; j<=1; j++) {
				offset[1] = j/love_ScreenSize.y;
				vec4 force = Texel(forceMap, texture_coords + offset);
				
				if (force[2] == 1) {
					vec2 direction = vec2(2*force[0] - 1, 2*force[1] - 1);
					if (abs(i + direction[0]) < 0.1 && abs(j + direction[1]) < 0.1) {
						vec4 sPixel = Texel(oldSpeedMap, texture_coords + offset);
						forces = forces + vec2((sPixel[0] - 0.5)*fTRatio, (sPixel[1] - 0.5)*fTRatio);
					}
				}
			}
		}
		return vec4(forces[0], forces[1], 0, 0);
	}
	
	vec2 scanForForce(vec2 texture_coords) {
		vec2 offset = vec2(0, 0);
		for (int i = -1; i<=1; i++) {
			offset[0] = i/love_ScreenSize.x;
			for (int j = -1; j<=1; j++) {
				offset[1] = j/love_ScreenSize.y;
				
				vec2 offsetCoords = texture_coords + offset;
				if (offsetCoords[0] <= 1 && offsetCoords[0] >= 0 && offsetCoords[1] <= 1 && offsetCoords[1] >= 0) {
					vec4 force = Texel(forceMap, offsetCoords);
					
					if (force[2] == 1) {
						vec2 direction = vec2(2*force[0] - 1, 2*force[1] - 1);
						if (abs(i + direction[0]) < 0.01 && abs(j + direction[1]) < 0.01) {
							return offset;
						}
					}
				}
			}
		}
		return vec2(0, 0);
	}
	
    void effect()
    {
		vec4 cPixel = Texel(oldPositionMap, VaryingTexCoord.xy);
		
		if (cPixel[3] == 0) {
			vec2 offset = scanForForce(VaryingTexCoord.xy);
			if (offset[0] != 0 || offset[1] != 0) {
				love_Canvases[0] = Texel(oldPositionMap, VaryingTexCoord.xy + offset);
				love_Canvases[1] = Texel(oldSpeedMap, VaryingTexCoord.xy + offset);
				love_Canvases[2] = Texel(oldMoveMap, VaryingTexCoord.xy + offset);
				love_Canvases[3] = vec4((offset[0]*love_ScreenSize.x + 1)/2, (offset[1]*love_ScreenSize.y + 1)/2, 1, 1);
				return;
			}
		} else {
			vec4 fPixel = Texel(forceMap, VaryingTexCoord.xy);
			vec4 speedPixel = Texel(oldSpeedMap, VaryingTexCoord.xy);
			if (fPixel[2] == 1) {
				speedPixel = vec4(0.5 + (speedPixel[0] - 0.5)*(1 - fTRatio), 0.5 + (speedPixel[1] - 0.5)*(1 - fTRatio), 0, 1);
			}
			speedPixel = correctSpeedMagnitude(speedPixel + addAdjForces(VaryingTexCoord.xy));
			love_Canvases[1] = speedPixel;
		}
		
		love_Canvases[0] = cPixel;
		//love_Canvases[1] = Texel(oldSpeedMap, VaryingTexCoord.xy);
		love_Canvases[2] = Texel(oldMoveMap, VaryingTexCoord.xy);
		love_Canvases[3] = vec4(0, 0, 0, 0);
    }
]]

local deletionShader = love.graphics.newShader [[
	extern Image deletionMap;
	extern Image oldPositionMap; //love_Canvases[0]
	extern Image oldSpeedMap; //love_Canvases[1]
	extern Image oldMoveMap; //love_Canvases[2]
	
	extern bool leftDelete;
	extern bool rightDelete;
	extern bool upDelete;
	extern bool bottomDelete;
	
	vec4 correctSpeedMagnitude(vec4 speed) {
		if ((mod(speed[0], 1) != speed[0]) || (mod(speed[1], 1) != speed[1])) {
			number angle = atan(speed[1] - 0.5, speed[0] - 0.5);
			speed[0] = 0.5 + 0.5*cos(angle);
			speed[1] = 0.5 + 0.5*sin(angle);
		}
		return speed;
	}
	
	bool canForDeletion(vec2 texture_coords) {
		vec2 offset = vec2(0, 0);
		for (int i = -1; i<=1; i++) {
			offset[0] = i/love_ScreenSize.x;
			for (int j = -1; j<=1; j++) {
				offset[1] = j/love_ScreenSize.y;
				vec2 offsetCoords = texture_coords + offset;
				
				if (offsetCoords[0] <= 1 && offsetCoords[0] >= 0 && offsetCoords[1] <= 1 && offsetCoords[1] >= 0) {
					vec4 deletion = Texel(deletionMap, offsetCoords);
					
					if (deletion[2] == 1) {
						vec2 direction = vec2(2*deletion[0] - 1, 2*deletion[1] - 1);
						if (abs(i + direction[0]) < 0.1 && abs(j + direction[1]) < 0.1) {
							return true;
						}
					}
				}
			}
		}
		return false;
	}
	
    void effect()
    {
		vec2 texture_coords = vec2(VaryingTexCoord[0], VaryingTexCoord[1]);
		
		if ((texture_coords[0] > 1 - 1/love_ScreenSize.x && leftDelete) || 
			(texture_coords[0] < 1/love_ScreenSize.x && rightDelete) || 
			(texture_coords[1] > 1 - 1/love_ScreenSize.y && upDelete) || 
			(texture_coords[1] < 1/love_ScreenSize.y && bottomDelete)) {
			love_Canvases[0] = vec4(0, 0, 0, 0);
			love_Canvases[1] = vec4(0, 0, 0, 0);
			love_Canvases[2] = vec4(0, 0, 0, 0);
		} else {
			vec4 cPixel = Texel(oldPositionMap, texture_coords);
			if (cPixel[3] > 0) {
				bool delete = canForDeletion(texture_coords);
				
				if (delete) {
					love_Canvases[0] = vec4(0, 0, 0, 0);
					love_Canvases[1] = vec4(0, 0, 0, 0);
					love_Canvases[2] = vec4(0, 0, 0, 0);
					return;
				} else {
					love_Canvases[1] = Texel(oldSpeedMap, texture_coords);
				}
			} else {
				vec4 dPixel = Texel(deletionMap, texture_coords);
				vec4 speedPixel = Texel(oldSpeedMap, texture_coords);
				
				if (dPixel[2] == 1) {
					vec2 offset = vec2(2*dPixel[0] - 1, 2*dPixel[1] - 1);
					
					vec4 oldSPixel = Texel(oldSpeedMap, texture_coords + offset);
					
					speedPixel = speedPixel + vec4(oldSPixel[0] - 0.5, oldSPixel[0] - 0.5, 0, 0);
				}
				
				love_Canvases[1] = speedPixel;
			}
			
			love_Canvases[0] = cPixel;
			//love_Canvases[1] = Texel(oldSpeedMap, texture_coords);
			love_Canvases[2] = Texel(oldMoveMap, texture_coords);
		}
    }
]]


function PixelParticles.newCanvas(xSize, ySize, maxSpeed)
	local displayCanvas = {love.graphics.newCanvas(xSize, ySize), love.graphics.newCanvas(xSize, ySize)}
	local images = {love.graphics.newCanvas(xSize, ySize), love.graphics.newCanvas(xSize, ySize)}
	local speedMaps = {love.graphics.newCanvas(xSize, ySize), love.graphics.newCanvas(xSize, ySize)}
	local moveMaps = {love.graphics.newCanvas(xSize, ySize), love.graphics.newCanvas(xSize, ySize)}
	
	local forceMap = love.graphics.newCanvas(xSize, ySize)
	local deletionMap = love.graphics.newCanvas(xSize, ySize)
	
	--images for actual image
	--forceMap to record what moves need to be made
	--speedMap to record speeds of each pixel
	--moveMap to record speeds of each pixel
	local pParticleCanvas = {displayCanvas = displayCanvas, images = images, speedMaps = speedMaps, moveMaps = moveMaps, forceMap = forceMap, deletionMap = deletionMap, particles = {}, xSize = xSize, ySize = ySize, timer = 0, speed = maxSpeed, fTRatio = 0.4, forces = {}, pixelSources = {}, speedLines = 0, openSides = {{false, false}, {false, false}}}
	
	return pParticleCanvas
end

function PixelParticles.setOpenSides(canvas, horizSides, vertSides)
	canvas.openSides = {horizSides, vertSides}
	return canvas
end

local function binaryInsert(list, element, comparitor)
	local elementWeight = element[comparitor]
	
	local first = 1
	local last = #list
	while first <= last do
		local i = math.ceil((last + first)/2)
		if list[i][comparitor] <= elementWeight then
			first = i + 1
		elseif list[i][comparitor] > elementWeight then
			last = i - 1
		end
	end
	table.insert(list, first, element)
	
	
	return first
end

local canvasShiftShader = love.graphics.newShader [[
	extern Image oldPositionMap; //love_Canvases[0]
	extern Image oldSpeedMap; //love_Canvases[1]
	extern Image oldMoveMap; //love_Canvases[2]
	
	extern int xShift;
	extern int yShift;
	
	void effect()
    {
		vec2 texture_coords = VaryingTexCoord.xy;
		
		vec2 shiftCoords = texture_coords + vec2(xShift/love_ScreenSize.x, yShift/love_ScreenSize.y);
		
		shiftCoords[0] = mod(shiftCoords[0], 1);
		shiftCoords[1] = mod(shiftCoords[1], 1);
		
		if (shiftCoords[0] > 0 && shiftCoords[0] < 1 && shiftCoords[1] > 0 && shiftCoords[1] < 1) {
			love_Canvases[0] = Texel(oldPositionMap, shiftCoords);
			love_Canvases[1] = Texel(oldSpeedMap, shiftCoords);
			love_Canvases[2] = Texel(oldMoveMap, shiftCoords);
		} else {
			love_Canvases[0] = vec4(0, 0, 0, 0);
			love_Canvases[1] = vec4(0, 0, 0, 0);
			love_Canvases[2] = vec4(0, 0, 0, 0);
		}
	}
]]
function PixelParticles.shiftCanvas(canvas, xShift, yShift)
	canvasShiftShader:send("oldPositionMap", canvas.images[1])
	canvasShiftShader:send("oldSpeedMap", canvas.speedMaps[1])
	canvasShiftShader:send("oldMoveMap", canvas.moveMaps[1])
	canvasShiftShader:send("xShift", xShift)
	canvasShiftShader:send("yShift", yShift)
	
	love.graphics.setShader(canvasShiftShader)
	love.graphics.setCanvas(canvas.images[2], canvas.speedMaps[2], canvas.moveMaps[2])
	love.graphics.clear()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(canvas.images[1], 0, 0)
	
	canvasShiftShader:send("oldPositionMap", canvas.images[2])
	canvasShiftShader:send("oldSpeedMap", canvas.speedMaps[2])
	canvasShiftShader:send("oldMoveMap", canvas.moveMaps[2])
	canvasShiftShader:send("xShift", 0)
	canvasShiftShader:send("yShift", 0)
	
	love.graphics.setCanvas(canvas.images[1], canvas.speedMaps[1], canvas.moveMaps[1])
	love.graphics.clear()
	love.graphics.draw(canvas.images[2], 0, 0)
	
	love.graphics.setShader()
	love.graphics.setCanvas()
end

function PixelParticles.addForce(pixelCanvas, force)
	binaryInsert(pixelCanvas.forces, force, "order")
	return force
end

function PixelParticles.addImage(particleCanvas, x, y, canvas)
	local imageData = canvas:newImageData()
	local width = imageData:getWidth()
	local height = imageData:getHeight()
	
	particleCanvas.images[1]:renderTo(function()
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(canvas, x - math.ceil(width/2), y - math.ceil(height/2))
	end)
end

function PixelParticles.addPixelSource(particleCanvas, x1, y1, x2, y2, lowCol, highCol, frequency)
	local canvas = love.graphics.newCanvas(x2 - x1, y2 - y1)
	local source = {x1 = x1, y1 = y1, x2 = x2, y2 = y2, canvas = canvas, lowCol = lowCol, highCol = highCol, frequency = frequency, timer = 0}
	table.insert(particleCanvas.pixelSources, source)
	return source
end

local spaceSpeedResetShader = love.graphics.newShader [[
	extern number x1;
	extern number y1;
	extern number x2;
	extern number y2;
	
	vec4 effect(vec4 colour, Image oldSpeeds, vec2 texCoords, vec2 pixel_coords)
    {
		if (texCoords[0] < x1 || texCoords[0] > x2 || texCoords[1] < y1 || texCoords[1] > y2) {
			return Texel(oldSpeeds, texCoords);
		} else {
			return vec4(0, 0, 0, 0);
		}
	}
]]
function PixelParticles.update(canvas, dt)
	canvas.timer = canvas.timer + dt
	love.graphics.setColor(1, 1, 1, 1)
	
	--Process pixel sources
	for i = 1, #canvas.pixelSources do
		local pixelSource = canvas.pixelSources[i]
		pixelSource.timer = pixelSource.timer + dt*pixelSource.frequency
		if pixelSource.timer > 0 then
			local nPixels = math.floor(pixelSource.timer)
			pixelSource.timer = pixelSource.timer - nPixels
			
			love.graphics.setCanvas(pixelSource.canvas)
			love.graphics.clear()
			
			for i = 1, nPixels do
				local pX = math.floor(math.random()*(pixelSource.x2 - pixelSource.x1 + 1))
				local pY = math.floor(math.random()*(pixelSource.y2 - pixelSource.y1 + 1))
				
				local colRatio = math.random()
				local col = {colRatio*pixelSource.lowCol[1] + (1 - colRatio)*pixelSource.highCol[1], colRatio*pixelSource.lowCol[2] + (1 - colRatio)*pixelSource.highCol[2], colRatio*pixelSource.lowCol[3] + (1 - colRatio)*pixelSource.highCol[3]}
				love.graphics.setColor(col)
				love.graphics.points(pX, pY)
			end
			
			love.graphics.setCanvas()
			PixelParticles.addImage(canvas, math.ceil((pixelSource.x1 + pixelSource.x2)/2), math.ceil((pixelSource.y1 + pixelSource.y2)/2), pixelSource.canvas)
		end
	end
	--
	
	--Run forces
	initSpeedShader:send("imageMap", canvas.images[1])
	love.graphics.setShader(initSpeedShader)
	love.graphics.setCanvas(canvas.speedMaps[2])
	love.graphics.clear()
	love.graphics.draw(canvas.speedMaps[1], 0, 0)
	love.graphics.setCanvas()
	
	local speedMapN = 2
	local i = #canvas.forces
	local tempDt = dt
	while i > 0 do
		local force = canvas.forces[i]
		tempDt = dt
		
		run = true
		if force.properties.minSpeed then
			force.properties.speedAccumulate = force.properties.speedAccumulate + dt
			if 1/128 < force.properties.speedAccumulate*force.properties.minSpeed/(2*canvas.speed) then
				tempDt = force.properties.speedAccumulate
				force.properties.speedAccumulate = 0
			end
		end
		
		if run then
			local fromSpeedMap = canvas.speedMaps[speedMapN]
			local toSpeedMap = canvas.speedMaps[speedMapN%2 + 1]
			
			speedMapN = speedMapN%2 + 1
			
			if force.properties.imageMap then
				force.shader:send("imageMap", canvas.images[1])
			end
			
			if force.properties.maxSpeed then
				force.shader:send("maxSpeed", canvas.speed)
			end
			
			PixelParticles.processGenericShaderProperties(force.shader, force.properties, tempDt)
			
			love.graphics.setShader(force.shader)
			love.graphics.setCanvas(toSpeedMap)
			love.graphics.clear()
			love.graphics.draw(fromSpeedMap, 0, 0)
			
			spaceSpeedResetShader:send("x1", force.space.x1)
			spaceSpeedResetShader:send("y1", force.space.y1)
			spaceSpeedResetShader:send("x2", force.space.x2)
			spaceSpeedResetShader:send("y2", force.space.y2)
			love.graphics.setShader(spaceSpeedResetShader)
			love.graphics.draw(fromSpeedMap, 0, 0)
			love.graphics.setShader()
		end
		
		PixelForces.update(force, dt)
		
		if force.timeLeft >= 0 then
			force.timeLeft = force.timeLeft - dt
			if force.timeLeft <= 0 then
				table.remove(canvas.forces, i)
				i = i - 2
			else
				i = i - 1
			end
		else
			i = i - 1
		end
	end
	
	if speedMapN == 2 then
		love.graphics.setShader()
		love.graphics.setCanvas(canvas.speedMaps[1])
		love.graphics.clear()
		love.graphics.draw(canvas.speedMaps[2], 0, 0)
	end
	--
	
	local setColor = love.graphics.setColor
	local changed = false
	while canvas.timer >= 1/canvas.speed do
		if not changed then
			changed = true
			if canvas.speedLines > 0 then
				local swapTemp = canvas.displayCanvas[1]
				canvas.displayCanvas[1] = canvas.displayCanvas[2]
				canvas.displayCanvas[2] = swapTemp
				
				love.graphics.setCanvas(canvas.displayCanvas[1])
				love.graphics.clear()
				setColor(1, 1, 1, canvas.speedLines)
				love.graphics.draw(canvas.displayCanvas[2], 0, 0)
			else
				love.graphics.setCanvas(canvas.displayCanvas[1])
				love.graphics.clear()
			end
		end
		canvas.timer = canvas.timer - 1/canvas.speed
		
		setColor(1, 1, 1, 1)
		
		--Calculate movement changes
		moveMapShader:send('speedMap', canvas.speedMaps[1])
		moveMapShader:send('imageMap', canvas.images[1])
		love.graphics.setShader(moveMapShader)
		
		love.graphics.setCanvas(canvas.moveMaps[2])
		love.graphics.clear(0, 0, 0, 0)
		love.graphics.draw(canvas.moveMaps[1], 0, 0)
		love.graphics.setCanvas()
		
		--First needs to be the real one, set that here
		love.graphics.setShader()
		love.graphics.setCanvas(canvas.moveMaps[1])
		love.graphics.clear(0, 0, 0, 0)
		love.graphics.draw(canvas.moveMaps[2], 0, 0)
		love.graphics.setCanvas()
		--
		
		--Calculate force map changes
		forceShader:send('imageMap', canvas.images[1])
		love.graphics.setShader(forceShader)
		
		love.graphics.setCanvas(canvas.forceMap)
		love.graphics.clear()
		love.graphics.draw(canvas.moveMaps[1], 0, 0)
		love.graphics.setCanvas()
		--
		
		--Move Particles
		movementShader:send('forceMap', canvas.forceMap)
		movementShader:send('oldPositionMap', canvas.images[1])
		movementShader:send('oldSpeedMap', canvas.speedMaps[1])
		movementShader:send('oldMoveMap', canvas.moveMaps[1])
		movementShader:send('fTRatio', canvas.fTRatio)
		love.graphics.setShader(movementShader)
		
		love.graphics.setCanvas(canvas.images[2], canvas.speedMaps[2], canvas.moveMaps[2], canvas.deletionMap)
		love.graphics.clear()
		love.graphics.draw(canvas.images[1], 0, 0)
		love.graphics.setCanvas()
		--
		
		--Delete Particles
		deletionShader:send('deletionMap', canvas.deletionMap)
		deletionShader:send('oldPositionMap', canvas.images[2])
		deletionShader:send('oldSpeedMap', canvas.speedMaps[2])
		deletionShader:send('oldMoveMap', canvas.moveMaps[2])
		
		deletionShader:send('leftDelete', canvas.openSides[1][1])
		deletionShader:send('rightDelete', canvas.openSides[1][2])
		deletionShader:send('upDelete', canvas.openSides[2][1])
		deletionShader:send('bottomDelete', canvas.openSides[2][2])
		
		love.graphics.setShader(deletionShader)
		
		love.graphics.setCanvas(canvas.images[1], canvas.speedMaps[1], canvas.moveMaps[1])
		love.graphics.clear()
		love.graphics.draw(canvas.images[2], 0, 0)
		love.graphics.setCanvas()
		--
		
		if canvas.speedLines ~= 0 then
			love.graphics.setCanvas(canvas.displayCanvas[1])
			love.graphics.draw(canvas.images[1], 0, 0)
		end
	end
	
	if canvas.speedLines == 0 and changed then
		love.graphics.setCanvas(canvas.displayCanvas[1])
		love.graphics.draw(canvas.images[1], 0, 0)
	end
	
	love.graphics.setShader()
	love.graphics.setCanvas()
end

function PixelParticles.processGenericShaderProperties(shader, properties, dt)
	if properties.angles then
		for j = 1, #properties.angles do
			shader:send("angle" .. j, properties.angles[j])
		end
	end
	
	if properties.numbers then
		for j = 1, #properties.numbers do
			shader:send("n" .. j, properties.numbers[j])
		end
	end
	
	if properties.images then
		for j = 1, #properties.images do
			shader:send("image" .. j, properties.images[j])
		end
	end
	
	if properties.acceleration then
		shader:send("accel", properties.acceleration*dt)
	end
end

function PixelParticles.drawCanvas(partCanvas, x, y, scale, debugDraw)
	if debugDraw then
		love.graphics.setColor(1, 0, 0, 0.2)
		love.graphics.rectangle("fill", x, y, scale*partCanvas.xSize, scale*partCanvas.ySize)
	end
	
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(partCanvas.displayCanvas[1], x, y, 0, scale, scale)
	
	love.graphics.setColor(1, 1, 1, 0.6)
	if debugDraw == "speed" then
		love.graphics.draw(partCanvas.speedMaps[1], x, y, 0, scale, scale)
	elseif debugDraw == "move" then
		love.graphics.draw(partCanvas.moveMaps[1], x, y, 0, scale, scale)
	elseif debugDraw == "force" then
		love.graphics.draw(partCanvas.forceMap, x, y, 0, scale, scale)
	elseif debugDraw == "delete" then
		love.graphics.draw(partCanvas.deletionMap, x, y, 0, scale, scale)
	end
	
	--Test draw all particles
	for i = 1, #partCanvas.particles do
		local particle = partCanvas.particles[i]
		love.graphics.setColor(0, 0, 1, 0.5)
		love.graphics.points(particle.rx + 0.5, particle.ry + 0.5)
	end
	--
	
	--love.graphics.setBlendMode("alpha", "premultiplied")
	--love.graphics.setColor(1, 1, 1, 1)
	--love.graphics.draw(partCanvas.forceMap, 0, 0)
	--love.graphics.setBlendMode("alpha")
end

return PixelParticles