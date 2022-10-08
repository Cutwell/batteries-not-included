local g3d = require "g3d"
local collisions = require "g3d/collisions"
local primitives = require "primitives"

local Forcefield = {}
Forcefield.__index = Forcefield

function Forcefield:new(x,y,z)
    local self = setmetatable({}, Forcefield)
    local vectorMeta = {
    }
    self.position = setmetatable({x,y,z}, vectorMeta)
    self.normal = setmetatable({0,1,0}, vectorMeta)

    self.renderFlag = false

    self.model = g3d.newModel("assets/battery2.obj", "assets/battery2.png", nil, nil, {0.35,0.35,0.35})
    self.model:setTranslation(x, y, z)

    return self
end

function Forcefield:draw()
    if self.renderFlag then
        self.model:draw()
    end
end

function Forcefield:reset()
    self.renderFlag = false
end

function Forcefield:update(battery)
    -- if battery count is 0, hide forcefield
    if battery == 0 then
        self.renderFlag = false
    else
        self.renderFlag = true
    end
end

return Forcefield