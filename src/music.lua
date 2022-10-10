local g3d = require "g3d"

local Music = {}
Music.__index = Music

function Music:new()
    local self = setmetatable({}, Music)
    
    -- load music
    self.intro = love.audio.newSource("assets/shooterSynthwave/intro.wav", "static")
    self.track1 = love.audio.newSource("assets/shooterSynthwave/track1.wav", "static")
    self.track2 = love.audio.newSource("assets/shooterSynthwave/track2.wav", "static")

    self.current = self.intro
    self.current:play()
    self.current:setLooping(true)
    self.current:setVolume(1)

    self.paused = false

    return self
end

function Music:reset()
    -- stop current track
    self.current:stop()
    -- reset to intro
    self.current = self.intro
    -- play intro
    self.current:play()
    -- set loop
    self.current:setLooping(true)
    -- reset volume for all tracks
    self.intro:setVolume(1)
    self.track1:setVolume(1)
    self.track2:setVolume(1)
    self.current:setVolume(1)
end

function Music:pause()
    if self.paused then
        self.current:play()
        self.paused = false
        self.current:setLooping(true)
    else
        self.current:pause()
        self.paused = true
    end
end

function Music:update(dt, battery)
    if not self.paused and battery.batteryCount > 0 then
        if self.current == self.intro then
            self:shuffle()
        end

        -- if track has finished, reset to another random track
        if not self.current:isPlaying() then
            self:shuffle()
        end

        -- if timer has run out, fade out current track
        if battery.timer <= 0 and self.current:isPlaying() then
            self.current:setVolume(self.current:getVolume() - dt * 0.5)
        end
    end
end

function Music:shuffle()
    -- stop current track
    self.current:stop()

    -- select track 1 or 2
    local track = math.random(1, 2)
    if track == 1 then
        self.current = self.track1
    else
        self.current = self.track2
    end

    -- play track
    self.current:play()
    self.current:setLooping(true)
    self.current:setVolume(1)
end

return Music