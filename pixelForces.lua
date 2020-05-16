local PixelForces = {}

--orders 
--0 Straight set
--1 Multiply
--2 Add

local function newForce(shader, timeLeft, properties, order)	
	local pixelForce = {shader = shader, properties = properties, order = order, timeLeft = timeLeft, space = {x1 = 0, y1 = 0, x2 = 1, y2 = 1}, spaceChange = {x1 = 0, y1 = 0, x2 = 0, y2 = 0}}
	if properties.minSpeed then
		pixelForce.properties.speedAccumulate = 0
	end
	return pixelForce
end

function PixelForces.setSpace(force, space, spaceChange)
	force.space = {x1 = space[1], y1 = space[2], x2 = space[3], y2 = space[4]}
	force.spaceChange = {x1 = spaceChange[1], y1 = spaceChange[2], x2 = spaceChange[3], y2 = spaceChange[4]}
	return force
end

function PixelForces.update(force, dt)
	force.space.x1 = force.space.x1 + force.spaceChange.x1*dt
	if force.space.x1 < 0 then
		force.space.x1 = 0
	end
	
	force.space.x2 = force.space.x2 + force.spaceChange.x2*dt
	if force.space.x2 > 1 then
		force.space.x2 = 1
	end
	
	if force.space.x1 > force.space.x2 then
		local avg = (force.space.x1 + force.space.x2)/2
		force.space.x1 = avg
		force.space.x2 = avg
	end
	
	force.space.y1 = force.space.y1 + force.spaceChange.y1*dt
	if force.space.y1 < 0 then
		force.space.y1 = 0
	end
	
	force.space.y2 = force.space.y2 + force.spaceChange.y2*dt
	if force.space.y2 > 1 then
		force.space.y2 = 1
	end
	
	if force.space.y1 > force.space.y2 then
		local avg = (force.space.y1 + force.space.y2)/2
		force.space.y1 = avg
		force.space.y2 = avg
	end
end

local function roundFloat(number)
	return math.floor(number + 0.5)
end

local function generateNoise(width, height, resolution)
	local noise = love.graphics.newCanvas(width, height)
	love.graphics.setCanvas(noise)
	
	local xOff = width*math.random()
	local yOff = height*math.random()
	
	local setCol = love.graphics.setColor
	local rectangle = love.graphics.rectangle
	for i = 0, width do
		for j = 0, height do
			local col = love.math.noise(i*resolution + xOff, j*resolution + yOff)
			setCol(col, col, col, 1)
			rectangle('fill', i, j, 1, 1)
		end
	end
	
	love.graphics.setCanvas()
	
	return noise
end

local windyTracksNoiseShader = love.graphics.newShader [[
	extern int searchSpace;
	
	vec4 effect(vec4 colour, Image noise, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cPixel = Texel(noise, texture_coords);
		
		bool valley = false;
		vec2 offset = vec2(0, 0);
		vec2 otherOff = vec2(0, 0);
		for (int i = -searchSpace; i <= 0; i++) {
			offset[0] = i/love_ScreenSize.x;
			otherOff[0] = -i/love_ScreenSize.x;
			for (int j = -searchSpace; j <= searchSpace; j++) {
				if (i == 0 && j == 0) {
					break;
				}
				offset[1] = j/love_ScreenSize.y;
				otherOff[1] = -j/love_ScreenSize.y;
				
				vec4 pixel1 = Texel(noise, texture_coords + offset);
				vec4 pixel2 = Texel(noise, texture_coords + otherOff);
				
				if (pixel1[0] >= cPixel[0] && pixel2[0] >= cPixel[0]) {
					valley = true;
					break;
				}
			}
		}
		
		number col = cPixel[0];
		if (valley) {
			col = 0;
		}
		
		return vec4(col, col, col, 1);
	}
]]
local function generateWindyTracks(width, height, resolution)
	local noise = generateNoise(width, height, resolution)
	
	local image = love.graphics.newCanvas(width, height)
	
	love.graphics.setCanvas(image)
	windyTracksNoiseShader:send("searchSpace", 4)
	love.graphics.setShader(windyTracksNoiseShader)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(noise, 0, 0)
	
	love.graphics.setShader()
	love.graphics.setCanvas()
	
	return image
end

local uniformAccelerationShader = love.graphics.newShader [[
	extern number maxSpeed;
	
	extern number angle1; //direction angle
	extern number accel; //acceleration
	
	vec4 effect(vec4 colour, Image oldSpeedMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cSpeed = Texel(oldSpeedMap, texture_coords);
		
		number rAccel = accel/(2*maxSpeed);
		
		return cSpeed + vec4(rAccel*cos(angle1), rAccel*sin(angle1), 0, 0);
	}
]]
function PixelForces.uniformAcceleration(directionAngle, acceleration, timeLeft)
	local properties = {angles = {directionAngle}, acceleration = acceleration, maxSpeed = true, minSpeed = acceleration/0.71}
	return newForce(uniformAccelerationShader, timeLeft, properties, 2)
end

local borderBounceShader = love.graphics.newShader [[
	extern number n1; //bounceFactor
	
	vec4 effect(vec4 colour, Image oldSpeedMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cSpeed = Texel(oldSpeedMap, texture_coords);
		
		if ((texture_coords[1] <= 1/love_ScreenSize.y && cSpeed[1] < 0.5) || (texture_coords[1] >= 1 - 1/love_ScreenSize.y && cSpeed[1] > 0.5)) {
			cSpeed[1] = 0.5 - n1*(cSpeed[1] - 0.5);
		}
		if ((texture_coords[0] <= 1/love_ScreenSize.x && cSpeed[0] < 0.5) || (texture_coords[0] >= 1 - 1/love_ScreenSize.x && cSpeed[0] > 0.5)) {
			cSpeed[0] = 0.5 - n1*(cSpeed[0] - 0.5);
		}
		
		return cSpeed;
	}
]]
function PixelForces.borderBounce(bounceFactor)
	local properties = {numbers = {bounceFactor}}
	return newForce(borderBounceShader, -1, properties, 1)
end

local explosionForceShader = love.graphics.newShader [[
	extern number maxSpeed;
	
	extern number n1; //strength
	extern number n2; //radius
	extern number n3; //x
	extern number n4; //y
	
	vec4 correctSpeedMagnitude(vec4 speed) {
		if ((mod(speed[0], 1) != speed[0]) || (mod(speed[1], 1) != speed[1])) {
			number angle = atan(speed[1] - 0.5, speed[0] - 0.5);
			speed[0] = 0.5 + 0.5*cos(angle);
			speed[1] = 0.5 + 0.5*sin(angle);
		}
		return speed;
	}
	
	vec4 effect(vec4 colour, Image oldSpeedMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cSpeed = Texel(oldSpeedMap, texture_coords);
		number strength = n1/(2*maxSpeed);
		number radius = n2;
		number x = n3;
		number y = n4;
		
		number distance = sqrt(pow(pixel_coords.x - x, 2) + pow(pixel_coords.y - y, 2));
		if (distance <= radius) {
			number angle = atan(pixel_coords.y - y, pixel_coords.x - x);
			number ratio = 1 - distance/radius;
			cSpeed = correctSpeedMagnitude(cSpeed + vec4(ratio*strength*cos(angle), ratio*strength*sin(angle), 0, 0));
		}
		
		return cSpeed;
	}
]]
function PixelForces.explosionForce(x, y, strength, radius)
	local properties = {numbers = {strength, radius, x, y}, maxSpeed = true}
	return newForce(explosionForceShader, 0, properties, 2)
end

local colourSortShader = love.graphics.newShader [[
	extern number maxSpeed;
	extern Image imageMap;
	
	extern number accel; //sortSpeed
	
	vec4 correctSpeedMagnitude(vec4 speed) {
		if ((mod(speed[0], 1) != speed[0]) || (mod(speed[1], 1) != speed[1])) {
			number angle = atan(speed[1] - 0.5, speed[0] - 0.5);
			speed[0] = 0.5 + 0.5*cos(angle);
			speed[1] = 0.5 + 0.5*sin(angle);
		}
		return speed;
	}
	
	vec4 effect(vec4 colour, Image oldSpeedMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cSpeed = Texel(oldSpeedMap, texture_coords);
		
		vec4 pixel = Texel(imageMap, texture_coords);
		number x = 1 - pixel[0];
		number y = 1 - pixel[1];
		
		number strength = accel/(2*maxSpeed);
		
		number distance = sqrt(pow(texture_coords.x - x, 2) + pow(texture_coords.y - y, 2));
		number angle = atan(y - texture_coords.y, x - texture_coords.x);
		number pullStrength = min(strength, distance);
		
		cSpeed = correctSpeedMagnitude(cSpeed + vec4(pullStrength*cos(angle), pullStrength*sin(angle), 0, 0));
		
		return cSpeed;
	}
]]
function PixelForces.colourSort(sortSpeed)
	local properties = {accel = sortSpeed, imageMap = true, maxSpeed = true}
	return newForce(colourSortShader, -1, properties, 2)
end

local windyWaysShader = love.graphics.newShader [[
	extern number maxSpeed;
	extern Image image1; //noiseMap
	extern number accel; //strength
	extern number n1; //windAngle
	extern number n2; //pushPointX(ifUsed)
	extern number n3; //pushPointY(ifUsed)
	
	vec4 correctSpeedMagnitude(vec4 speed) {
		if ((mod(speed[0], 1) != speed[0]) || (mod(speed[1], 1) != speed[1])) {
			number angle = atan(speed[1] - 0.5, speed[0] - 0.5);
			speed[0] = 0.5 + 0.5*cos(angle);
			speed[1] = 0.5 + 0.5*sin(angle);
		}
		return speed;
	}
	
	vec4 effect(vec4 colour, Image oldSpeedMap, vec2 texture_coords, vec2 pixel_coords)
    {
		vec4 cSpeed = Texel(oldSpeedMap, texture_coords);
		
		vec4 noisePixel = Texel(image1, texture_coords);
		number noise = noisePixel[0];
		
		number bestDiff = 0;
		vec2 bestOffset = vec2(0, 0);
		vec2 offset = vec2(0, 0);
		
		for (int i = -1; i<=1; i++) {
			offset[0] = i/love_ScreenSize.x;
			for (int j = -1; j<=1; j++) {
				offset[1] = j/love_ScreenSize.y;
				vec2 offsetCoords = texture_coords + offset;
				
				vec4 oNoisePixel = Texel(image1, texture_coords + offset);
				number oNoise = oNoisePixel[0];
				
				if (noise - oNoise > bestDiff) {
					bestOffset = offset;
					bestDiff = noise - oNoise;
				}
			}
		}
		
		number strength = accel/(2*maxSpeed);
		number angle = atan(bestOffset[1], bestOffset[0]);
		
		noise = sqrt(noise);
		
		number windPower = (1 - noise);
		number windAngle = n1;
		if (windAngle < 0) {
			windAngle = atan(pixel_coords[1] - n3, pixel_coords[0] - n2);
		} else {
			windAngle = -n1;
		}
		
		//cSpeed = vec4(0.5, 0.5, 0, 1);
		
		cSpeed = correctSpeedMagnitude(cSpeed + vec4(noise*strength*cos(angle) + windPower*strength*cos(windAngle), noise*strength*sin(angle) + windPower*strength*sin(windAngle), 0, 0));
		
		return cSpeed;
	}
]]
function PixelForces.windyWays(pixelCanvas, strength, angle, noiseResolution)
	local noise = generateWindyTracks(pixelCanvas.xSize, pixelCanvas.ySize, noiseResolution)
	
	local properties = {acceleration = strength, numbers = {angle}, images = {noise}, maxSpeed = true, minSpeed = strength}
	return newForce(windyWaysShader, -1, properties, 1)
end

function PixelForces.windyWaysFromPoint(pixelCanvas, strength, x, y, noiseResolution)
	local noise = generateWindyTracks(pixelCanvas.xSize, pixelCanvas.ySize, noiseResolution)
	
	local properties = {acceleration = strength, numbers = {-1, x, y}, images = {noise}, maxSpeed = true, minSpeed = strength}
	return newForce(windyWaysShader, -1, properties, 1)
end

return PixelForces