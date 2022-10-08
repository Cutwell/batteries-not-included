local g3d = require "g3d"
local collisions = require "g3d/collisions"
local primitives = require "primitives"

local Battery = {}
Battery.__index = Battery

function Battery:new(x,y,z)
    local self = setmetatable({}, Battery)
    local vectorMeta = {
    }
    self.position = setmetatable({x,y,z}, vectorMeta)
    self.normal = setmetatable({0,1,0}, vectorMeta)
    self.batteryCount = 0
    self.collisionBox = {0.4, 0.8, 0.4}
    self.maxTimer = 15
    self.timer = self.maxTimer
    self.timerIncrement = 5 -- time added per battery
    self.gameoverFlag = false
    self.pickupCue = love.audio.newSource("assets/pickup.wav", "static") -- audio cue for battery collection
    self.gameoverCue = love.audio.newSource("assets/Ambient_5.wav", "static") -- audio cue for game over
    self.warningCue = love.audio.newSource("assets/beep.wav", "static") -- audio cue for low battery
    self.warningCooldown = 0
    self.renderFlag = false
    self.collisionModels = {}

    self.model = g3d.newModel("assets/battery.obj", "assets/battery.png", nil, nil, {0.35,0.35,0.35})
    self.model:setTranslation(x, y, z)

    self.rotateTimer = 0
    self.attempts = 0

    self.searching = false
    self.player_x, self.player_y, self.player_z = 0,0,0

    -- increase difficulty over time by increasing drain on timer per second (so 1 second becomes 1*difficultyMultiplier seconds)
    self.difficultyMultiplier = 1
    self.gameTimer = 0
    self.difficultyEnabled = true

    return self
end

function Battery:addCollisionModel(model)
    table.insert(self.collisionModels, model)
    return model
end

function Battery:collisionTest(mx,my,mz)
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


function Battery:draw()
    if self.renderFlag then
        self.model:draw()
    end
end

function Battery:reset()
    self.difficultyMultiplier = 1
    self.gameTimer = 0
    self.timer = self.maxTimer
    self.batteryCount = 0
    self.gameoverFlag = false
    self.position[1], self.position[2], self.position[3] = 1,-0.5,0.4
    -- update battery model position
    self.model:setTranslation(self.position[1], self.position[2], self.position[3])
end

function Battery:update(dt, player, map, ray, powerup)
    if self.gameoverFlag then
        -- stop raycasting + hide powerup, so hidden battery below world isn't raytraced to
        ray.enabled = false
        powerup.renderFlag = false
        return
    end

    -- increment self.gameTimer
    self.gameTimer = self.gameTimer + dt
    -- update difficulty multiplier (1 + self.gameTimer/60 = double difficulty every minute, 1 + self.gameTimer/(60*60) = double difficulty every hour)
    
    if self.batteryCount > 0 and self.difficultyEnabled then
        self.difficultyMultiplier = 1 + self.gameTimer/120 -- double difficulty every 2 minutes, increasing over time
    end

    -- decrement warning cooldown by dt
    self.warningCooldown = self.warningCooldown - (dt * self.difficultyMultiplier)
    if self.warningCooldown < 0 then
        self.warningCooldown = 0
    end

    if not self.searching then
        -- check if time left is less than 10 percent left or 5 seconds (whichever is greater)
        if (self.timer/self.maxTimer) < 0.1 or self.timer < 5 and self.timer > 0 then
            -- play warning sound
            if self.warningCooldown == 0 then
                self.warningCue:play()
                self.warningCooldown = 1
            end
        end

        -- increment rotate timer by dt
        self.rotateTimer = self.rotateTimer + dt * 0.01
        -- constrain rotate timer to 0-5
        if self.rotateTimer > 5 then
            self.rotateTimer = 0
        end
        -- normalise rotate timer to 0-1
        local normalisedRotation = self.rotateTimer / 5
        -- rotate battery based on rotate timer
        self.model:setRotation(0, normalisedRotation * 360, 0)

        -- if player on tutorial step 5, spawn battery
        if player.tutorial_progression == 5 then
            self.renderFlag = true
        end

        -- start game after collected first battery
        if self.batteryCount > 0 then
            self.timer = self.timer - (dt * self.difficultyMultiplier) -- make it count down

            -- set tutorial progression to 6
            player.tutorial_progression = 6
        end

        if self.timer < 0 then
            self.timer = -1 -- keep timer at -1 to hide countdown after game
            -- stop rendering battery (hide it off screen)
            self.model:setTranslation(0, 100, 0)
            self.gameoverFlag = true
            self.gameoverCue:play()
        end
    end    

    -- check if player is colliding with battery
    if not self.searching and self.renderFlag and self:playerCollision(player) then
        -- play audio cue
        self.pickupCue:play()

        -- increment battery count
        self.batteryCount = self.batteryCount + 1

        -- record current player coords so new spawn has line of sight
        self.player_x, self.player_y, self.player_z = player.position[1], player.position[2], player.position[3]

        -- award bonus time
        self.timer = self.timer + self.timerIncrement
        -- constrain max timer to 10 seconds
        if self.timer > self.maxTimer then self.timer = self.maxTimer end
        
        -- halt battery rendering till new spawn location is found
        self.searching = true
        self.renderFlag = false
    end
end

function Battery:search(player, map, ray, powerup)
    if self.attempts > 4 then
        -- if spawning from player position fails takes too long, spawn in line of sight of known valid position
        self.player_x, self.player_y, self.player_z = 2,-1,-0.4
        self.attempts = 0
    end

    local x,y,z = self.player_x, self.player_y, self.player_z
    local prev_x, prev_y, prev_z = x, y, z

    local nx, ny, nz

    -- generate random coordinates
    nx = math.random(-8, 8)
    ny = math.random(-3, -0.5)
    nz = math.random(-8, 8)

    -- move battery from player to random coordinates in small steps
    local step = 0.1

    while x ~= nx or y ~= ny or z ~= nz do
        -- move towards coordinates by step
        if x < nx then x = x + step end
        if x > nx then x = x - step end
        if y < ny then y = y + step end
        if y > ny then y = y - step end
        if z < nz then z = z + step end
        if z > nz then z = z - step end

        self.position[1], self.position[2], self.position[3] = x, y, z

        -- update battery model position
        self.model:setTranslation(self.position[1], self.position[2], self.position[3])

        -- check if battery is colliding with map
        bestLength, bx,by,bz, bnx,bny,bnz = self:collisionTest(0,0,0)

        -- if battery is colliding with map, reset search
        if bestLength then
            -- check prev_ distance from player is greater than 2
            if math.sqrt((prev_x - self.player_x)^2 + (prev_y - self.player_y)^2 + (prev_z - self.player_z)^2) > 2 then
                -- if there is a previous position, move battery to that position and accept it
                self.position[1], self.position[2], self.position[3] = prev_x, prev_y, prev_z

                -- update battery model position
                self.model:setTranslation(self.position[1], self.position[2], self.position[3])

                ray:setOriginDest(self.position[1], self.position[2], self.position[3], player.position[1], player.position[2], player.position[3])

                ray.decay = ray.decayMax
                
                -- end search, render
                self.searching = false
                self.renderFlag = true

                self.attempts = 0

                break
            else
                self.attempts = self.attempts + 1
                -- retry next update
                break
            end

        else
            -- if battery is not colliding with map, save current position as a validated position
            prev_x, prev_y, prev_z = x, y, z
        end

        -- if battery within step range of coordinates, exit
        if math.abs(x - nx) < step and math.abs(y - ny) < step and math.abs(z - nz) < step then
            break
        end
    end
end

function Battery:playerCollision(player)
    -- check if player xyz is within collision box offsets from battery xyz
    if (player.position[1] > self.position[1] - self.collisionBox[1] and player.position[1] < self.position[1] + self.collisionBox[1]) and
       (player.position[2] > self.position[2] - self.collisionBox[2] and player.position[2] < self.position[2] + self.collisionBox[2]) and
       (player.position[3] > self.position[3] - self.collisionBox[3] and player.position[3] < self.position[3] + self.collisionBox[3]) then
        return true
    else
        return false
    end
end

return Battery