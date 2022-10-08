local g3d = require "g3d"
local collisions = require "g3d/collisions"

local Menu = {}
Menu.__index = Menu

function Menu:new(x, y, z, func, option1, texture1, option2, texture2)
    local self = setmetatable({}, Menu)
    local vectorMeta = {
    }
    self.position = setmetatable({x,y,z}, vectorMeta)
    self.normal = setmetatable({0,1,0}, vectorMeta)
    self.collisionBox = {0.5, 0.8, 0.5}
    self.optionCue = love.audio.newSource("assets/powerup_pickup.wav", "static") -- audio cue for option selection
    self.renderTimer = 0
    self.renderTimerMax = 2 -- wait 5 seconds before rendering after using option

    self.option1 = option1
    self.option2 = option2
    self.texture1 = texture1
    self.texture2 = texture2

    self.func = func

    self.model = g3d.newModel(self.option1, self.texture1, nil, nil, {0.6,0.6,0.6})
    self.model:setTranslation(x, y, z)

    self.rotateTimer = 0

    return self
end

function Menu:draw()
    if self.renderTimer <= 0 then
        self.model:draw()
    end
end

function Menu:update(dt, music, battery, player)
    -- countdown timer till render
    if self.renderTimer > 0 then
        self.renderTimer = self.renderTimer - dt

        if self.renderTimer <= 0 then
            if self:playerCollision(player) then
                self.renderTimer = 2    -- add extra 2 seconds for player to move away from menu
            else
                self.renderTimer = 0
            end
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

    -- check if player is colliding with battery
    if self.renderTimer <= 0 and self:playerCollision(player) then
        -- play audio cue
        self.optionCue:play()

        -- run menu option function
        if self.func == "music" then
            music:pause()

            if music.paused then 
                self.model = g3d.newModel(self.option2, self.texture2, nil, nil, {0.6, 0.6, 0.6}) 
            else
                self.model = g3d.newModel(self.option1, self.texture1, nil, nil, {0.6, 0.6, 0.6})
            end
        end
        if self.func == "difficulty" then
            if battery.difficultyEnabled then
                battery.difficulty = 1
                battery.difficultyEnabled = false
                self.model = g3d.newModel(self.option2, self.texture2, nil, nil, {0.6, 0.6, 0.6}) 
            else 
                battery.difficultyEnabled = true
                self.model = g3d.newModel(self.option1, self.texture1, nil, nil, {0.6, 0.6, 0.6})
            end
        end
        
        self.model:setTranslation(self.position[1], self.position[2], self.position[3])
        self.renderTimer = self.renderTimerMax
    end
end

function Menu:toggle(option)
    
end

function Menu:playerCollision(player)
    -- check if player xyz is within collision box offsets from battery xyz
    if (player.position[1] > self.position[1] - self.collisionBox[1] and player.position[1] < self.position[1] + self.collisionBox[1]) and
       (player.position[2] > self.position[2] - self.collisionBox[2] and player.position[2] < self.position[2] + self.collisionBox[2]) and
       (player.position[3] > self.position[3] - self.collisionBox[3] and player.position[3] < self.position[3] + self.collisionBox[3]) then
        return true
    else
        return false
    end
end

return Menu