local g3d = require "g3d"

-- TODO:
-- on-the-fly stepDownSize calculation based on normal vector of triangle
-- mario 64 style sub-frames for more precise collision checking

local function getSign(number)
    return (number > 0 and 1) or (number < 0 and -1) or 0
end

local function round(number)
    if number then
        return math.floor(number*1000 + 0.5)/1000
    end
    return "nil"
end

local Player = {}
Player.__index = Player

function Player:new(x,y,z)
    local self = setmetatable({}, Player)
    local vectorMeta = {
    }
    self.position = setmetatable({x,y,z}, vectorMeta)
    self.speed = setmetatable({0,0,0}, vectorMeta)
    self.lastSpeed = setmetatable({0,0,0}, vectorMeta)
    self.normal = setmetatable({0,1,0}, vectorMeta)
    self.radius = 0.2
    self.onGround = false
    self.stepDownSize = 0.075
    self.isSliding = false
    self.wasSliding = false
    self.collisionModels = {}
    self.regularJump = love.audio.newSource("assets/sounds/Jump_4.wav", "static")
    self.slideJump = love.audio.newSource("assets/sounds/Jump_9.wav", "static")
    self.slam = love.audio.newSource("assets/sounds/slam.wav", "static")
    self.swoosh = love.audio.newSource("assets/sounds/swooosh.wav", "static")
    self.footsteps = love.audio.newSource("assets/sounds/footsteps.wav", "static")
    self.slide = love.audio.newSource("assets/sounds/slide.wav", "static")
    self.footsteps_clock = 0
    self.tutorial_progression = 0
    self.tutorial_progression_steps = 0
    self.tutorial_progression_steps_max = 1
    self.cameraPitch = g3d.camera.getDirectionPitch()
    self.isSlamming = false
    self.sliding = 0 -- sliding counter to ease in and out of sliding

    return self
end

function Player:addCollisionModel(model)
    table.insert(self.collisionModels, model)
    return model
end

-- collide against all models in my collision list
-- and return the collision against the closest one
function Player:collisionTest(mx,my,mz)
    local bestLength, bx,by,bz, bnx,bny,bnz

    for _,model in ipairs(self.collisionModels) do
        local len, x,y,z, nx,ny,nz = model:capsuleIntersection(
            self.position[1] + mx,
            self.position[2] + my - 0.15,
            self.position[3] + mz,
            self.position[1] + mx,
            self.position[2] + my + 0.5,
            self.position[3] + mz,
            0.2
        )

        if len and (not bestLength or len < bestLength) then
            bestLength, bx,by,bz, bnx,bny,bnz = len, x,y,z, nx,ny,nz
        end
    end

    return bestLength, bx,by,bz, bnx,bny,bnz
end

function Player:reset()
    self.isSliding = false
    self.wasSliding = false
    self.isSlamming = false
    self.sliding = 0

    self.tutorial_progression = 5
    self.tutorial_progression_steps = 0

    self.speed = {0,0,0}
    self.lastSpeed = {0,0,0}

    self.position[1], self.position[2], self.position[3] = 2,-1,-0.4
    for i=1, 3 do
        g3d.camera.position[i] = self.position[i]
    end

    g3d.camera.lookInDirection()
end

function Player:moveAndSlide(mx,my,mz)
    local len,x,y,z,nx,ny,nz = self:collisionTest(mx,my,mz)

    self.position[1] = self.position[1] + mx
    self.position[2] = self.position[2] + my
    self.position[3] = self.position[3] + mz

    local ignoreSlopes = ny and ny < -0.7

    if len then
        local speedLength = math.sqrt(mx^2 + my^2 + mz^2)

        if speedLength > 0 then
            local xNorm, yNorm, zNorm = mx / speedLength, my / speedLength, mz / speedLength
            local dot = xNorm*nx + yNorm*ny + zNorm*nz
            local xPush, yPush, zPush = nx * dot, ny * dot, nz * dot

            -- modify output vector based on normal
            my = (yNorm - yPush) * speedLength
            if ignoreSlopes then my = 0 end

            if not ignoreSlopes then
                mx = (xNorm - xPush) * speedLength
                mz = (zNorm - zPush) * speedLength
            end
        end

        -- rejections
        self.position[2] = self.position[2] - ny * (len - self.radius)

        if not ignoreSlopes then
            self.position[1] = self.position[1] - nx * (len - self.radius)
            self.position[3] = self.position[3] - nz * (len - self.radius)
        end
    end

    return mx, my, mz, nx, ny, nz
end

function Player:update(dt)
    -- collect inputs
    local moveX,moveY = 0,0
    local speed = 0.018
    local friction = 0.75
    local gravity = 0.005
    local jump = 1/6.8
    local maxFallSpeed = 0.25
    local sliding = false

    -- check if camera pitch has changed
    local cameraPitch = g3d.camera.getDirectionPitch()
    if cameraPitch ~= self.cameraPitch then
        self.cameraPitch = cameraPitch

        if self.tutorial_progression == 0 then
            -- increment step progression by 0.1
            self.tutorial_progression_steps = self.tutorial_progression_steps + 0.011
            
            -- check if tutorial step progression is complete
            if self.tutorial_progression_steps >= self.tutorial_progression_steps_max then
                self.tutorial_progression_steps = 0
                self.tutorial_progression = 1   -- next tutorial step
            end
        end
    end

    -- decrement footstep clock
    self.footsteps_clock = self.footsteps_clock - dt
    if self.footsteps_clock < 0 then
        self.footsteps_clock = 0
    end

    -- check if player has moved with wasd
    if love.keyboard.isDown("w") or love.keyboard.isDown("a") or love.keyboard.isDown("s") or love.keyboard.isDown("d") then
        if self.tutorial_progression == 2 then
            -- increment step progression by 0.1
            self.tutorial_progression_steps = self.tutorial_progression_steps + 0.011

            -- check if tutorial step progression is complete
            if self.tutorial_progression_steps >= self.tutorial_progression_steps_max then
                self.tutorial_progression_steps = 0
                self.tutorial_progression = 3   -- next tutorial step
            end
        end

        -- if footstep clock is 0 and on the ground, play footstep sound
        if self.footsteps_clock == 0 and self.onGround then
            self.footsteps:play()
            self.footsteps_clock = 0.1
        end
    end

    -- friction
    self.speed[1] = self.speed[1] * friction
    self.speed[3] = self.speed[3] * friction

    -- gravity
    self.speed[2] = math.min(self.speed[2] + gravity, maxFallSpeed)

    -- add tutorial skip by pressing number key to set tutorial progression
    if love.keyboard.isDown("1") then
        self.tutorial_progression = 0
        self.tutorial_progression_steps = 0
    elseif love.keyboard.isDown("2") then
        self.tutorial_progression = 1
        self.tutorial_progression_steps = 0
    elseif love.keyboard.isDown("3") then
        self.tutorial_progression = 2
        self.tutorial_progression_steps = 0
    elseif love.keyboard.isDown("4") then
        self.tutorial_progression = 3
        self.tutorial_progression_steps = 0
    elseif love.keyboard.isDown("5") then
        self.tutorial_progression = 4
        self.tutorial_progression_steps = 0
    elseif love.keyboard.isDown("6") then
        self.tutorial_progression = 5
        self.tutorial_progression_steps = 0
    end

    if love.keyboard.isDown("w") then moveY = moveY - 1 end
    if love.keyboard.isDown("a") then moveX = moveX - 1 end
    if love.keyboard.isDown("s") then moveY = moveY + 1 end
    if love.keyboard.isDown("d") then moveX = moveX + 1 end
    if love.keyboard.isDown("space") and not love.keyboard.isDown("lctrl") and self.onGround then
        -- progress tutorial if on 1
        if self.tutorial_progression == 1 then
            -- increment step progression by 0.1
            self.tutorial_progression_steps = self.tutorial_progression_steps + 0.51

            -- check if tutorial step progression is complete
            if self.tutorial_progression_steps >= self.tutorial_progression_steps_max then
                self.tutorial_progression_steps = 0
                self.tutorial_progression = 2   -- next tutorial step
            end
        end

        if love.keyboard.isDown("lshift") then
            self.slideJump:play()
            self.speed[2] = self.speed[2] - jump * 0.7
        else
            self.regularJump:play()
            self.speed[2] = self.speed[2] - jump
        end
    end

    -- slam
    if love.keyboard.isDown("lctrl") and not self.onGround then
        -- progress tutorial if on 4
        if self.tutorial_progression == 4 and not self.isSlamming then
            -- increment step progression by 0.1
            self.tutorial_progression_steps = self.tutorial_progression_steps + 0.51

            self.isSlamming = true

            -- check if tutorial step progression is complete
            if self.tutorial_progression_steps >= self.tutorial_progression_steps_max then
                self.tutorial_progression_steps = 0
                self.tutorial_progression = 5   -- next tutorial step
            end
        end
        
        self.speed[2] = maxFallSpeed
        -- play slam noise
        if not self.isSlamming then
            self.isSlamming = true
            self.swoosh:play()
        end
    end

    -- check if player is on ground
    if self.onGround then
        if self.isSlamming then
            -- stop slamming, play sound to show player has landed
            self.isSlamming = false
            self.slam:play()
        end
    end

    -- boost
    if love.keyboard.isDown("lshift") then
        -- progress tutorial if on 3 and player is moving whilst holding shift
        if self.tutorial_progression == 3 then
            -- increment step progression by 0.1
            self.tutorial_progression_steps = self.tutorial_progression_steps + 0.011

            -- check if tutorial step progression is complete
            if self.tutorial_progression_steps >= self.tutorial_progression_steps_max then
                self.tutorial_progression_steps = 0
                self.tutorial_progression = 4   -- next tutorial step
            end
        end

        moveY = moveY - 1
        self.sliding = 0.2
    else
        -- decrement slide when not holding shift to gradually stop sliding
        self.sliding = self.sliding - 0.02

        if self.sliding < 0 then
            self.sliding = 0
        end
    end

    -- if player is on ground and sliding, make sure slide sound is playing
    if self.onGround and self.sliding > 0 then
        self.slide:play()
        self.slide:setLooping(true)
    else
        self.slide:stop()
    end

    -- update speed according to ease in/out of slide
    self.speed[1] = self.speed[1] * (self.sliding + 1)
    self.speed[3] = self.speed[3] * (self.sliding + 1)

    -- do some trigonometry on the inputs to make movement relative to camera's direction
    -- also to make the player not move faster in diagonal directions
    if moveX ~= 0 or moveY ~= 0 then
        local angle = math.atan2(moveY,moveX)
        local direction = g3d.camera.getDirectionPitch()
        local directionX, directionZ = math.cos(direction + angle)*speed, math.sin(direction + angle + math.pi)*speed

        self.speed[1] = self.speed[1] + directionX
        self.speed[3] = self.speed[3] + directionZ
    end

    local _, nx, ny, nz

    -- vertical movement and collision check
    _, self.speed[2], _, nx, ny, nz = self:moveAndSlide(0, self.speed[2], 0)

    -- ground check
    local wasOnGround = self.onGround
    self.onGround = ny and ny < -0.7

    -- smoothly walk down slopes
    if not self.onGround and wasOnGround and self.speed[2] > 0 then
        local len,x,y,z,nx,ny,nz = self:collisionTest(0,self.stepDownSize,0)
        local mx, my, mz = 0,self.stepDownSize,0
        if len then
            -- do the position change only if a collision was actually detected
            self.position[2] = self.position[2] + my

            local speedLength = math.sqrt(mx^2 + my^2 + mz^2)

            if speedLength > 0 then
                local xNorm, yNorm, zNorm = mx / speedLength, my / speedLength, mz / speedLength
                local dot = xNorm*nx + yNorm*ny + zNorm*nz
                local xPush, yPush, zPush = nx * dot, ny * dot, nz * dot

                -- modify output vector based on normal
                my = (yNorm - yPush) * speedLength
            end

            -- rejections
            self.position[2] = self.position[2] - ny * (len - self.radius)
            self.speed[2] = 0
            self.onGround = true
        end
    end

    -- wall movement and collision check
    self.speed[1], _, self.speed[3], nx, ny, nz = self:moveAndSlide(self.speed[1], 0, self.speed[3])


    for i=1, 3 do
        self.lastSpeed[i] = self.speed[i]
        g3d.camera.position[i] = self.position[i]
    end

    if self.sliding > 0 then
        g3d.camera.position[2] = g3d.camera.position[2] + 0.4
    end

    g3d.camera.lookInDirection()
end

function Player:interpolate(fraction)
    -- interpolate in every direction except down
    -- because gravity/floor collisions mean that there will often be a noticeable
    -- visual difference between the interpolated position and the real position

    for i=1, 3 do
        if i ~= 2 then
            g3d.camera.position[i] = self.position[i] + self.speed[i]*fraction
        end
    end

    g3d.camera.lookInDirection()
end

return Player
