local g3d = require "g3d"
local collisions = require "g3d/collisions"
local primitives = require "primitives"

local Powerup = {}
Powerup.__index = Powerup

function Powerup:new(x,y,z)
    local self = setmetatable({}, Powerup)
    local vectorMeta = {
    }
    self.position = setmetatable({x,y,z}, vectorMeta)
    self.normal = setmetatable({0,1,0}, vectorMeta)
    self.collisionBox = {0.5, 0.8, 0.5}
    self.pickupCue = love.audio.newSource("assets/sounds/powerup_pickup.wav", "static") -- audio cue for battery collection
    self.spawnCue = love.audio.newSource("assets/sounds/powerup_spawn.wav", "static") -- audio cue for battery collection
    self.renderFlag = false
    self.collisionModels = {}

    self.model = g3d.newModel("assets/battery2.obj", "assets/battery2.png", nil, nil, {0.35,0.35,0.35})
    self.model:setTranslation(x, y, z)

    self.rotateTimer = 0

    self.searching = false
    self.player_x, self.player_y, self.player_z = 0,0,0

    self.powerupTimer = 0
    self.powerupMaxTimer = 10   -- give player 10 seconds of powerup

    -- delay spawn of powerup by 40 seconds to stay competitive
    self.spawnDelayMax = 20
    self.spawnDelay = self.spawnDelayMax

    self.attempts = 0

    self.originalPosition = {x,y,z}

    return self
end

function Powerup:addCollisionModel(model)
    table.insert(self.collisionModels, model)
    return model
end

function Powerup:collisionTest(mx,my,mz)
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


function Powerup:draw()
    if self.renderFlag then
        self.model:draw()
    end
end

function Powerup:reset()
    self.powerupTimer = 0
    self.spawnDelay = self.spawnDelayMax
    self.renderFlag = false
    -- move powerup offscreen
    self.model:setTranslation(self.originalPosition[1], self.originalPosition[2], self.originalPosition[3])
    self.position = self.originalPosition
end

function Powerup:update(dt, player, ray, battery)
    -- if player has started the game, look to spawn the powerup
    if battery.batteryCount > 0 and battery.timer > 0 and not self.searching then
        self.spawnDelay = self.spawnDelay - dt
        if self.spawnDelay <= 0 then
            self.spawnDelay = 0

            if not self.searching then
                if not self.renderFlag then
                    self.spawnCue:play()    -- play spawn cue once when powerup is spawned
                end

                self.renderFlag = true
            end
        end
    end

    -- decrement powerupTimer by dt
    self.powerupTimer = self.powerupTimer - dt
    if self.powerupTimer < 0 then
        self.powerupTimer = 0
        ray.enabled = false -- end powerup once timer runs out
    end

    if not self.searching then
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
    end

    -- check if player is colliding with battery
    if not self.searching and self.renderFlag and self:playerCollision(player) then
        -- play audio cue
        self.pickupCue:play()

        -- award bonus time
        self.powerupTimer = self.powerupMaxTimer
        
        -- halt battery rendering till new spawn location is found
        self.searching = true
        self.renderFlag = false

        -- trace ray from current player position to battery position
        ray:setOriginDest(player.position[1], player.position[2], player.position[3], battery.position[1], battery.position[2], battery.position[3])

        -- enable ray rendering
        ray.enabled = true
    end
end

function Powerup:search(player, ray, battery)
    if self.attempts > 4 then
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
                
                -- end search, render after spawn delay
                self.searching = false
                self.spawnDelay = self.spawnDelayMax

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

function Powerup:playerCollision(player)
    -- check if player xyz is within collision box offsets from battery xyz
    if (player.position[1] > self.position[1] - self.collisionBox[1] and player.position[1] < self.position[1] + self.collisionBox[1]) and
       (player.position[2] > self.position[2] - self.collisionBox[2] and player.position[2] < self.position[2] + self.collisionBox[2]) and
       (player.position[3] > self.position[3] - self.collisionBox[3] and player.position[3] < self.position[3] + self.collisionBox[3]) then
        return true
    else
        return false
    end
end

return Powerup