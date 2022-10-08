local g3d = require "g3d"
local vectors = require "g3d/vectors"

local Ray = {}
Ray.__index = Ray

function Ray.new()
    local self = setmetatable({}, Ray)
    
    self.model = g3d.newModel({
        {-1,0,-1},
        {1, 0,-1},
        {-1,0, 1},
        {1, 0, 1},
        {1, 0,-1},
        {-1,0, 1},
    }, "assets/sun.png")

    self.enabled = false
    self.decayMax = 0.5
    self.decay = self.decayMax

    return self
end

function Ray:update(dt, battery)
    if self.enabled and battery.renderFlag then
        self.decay = self.decay - (dt * 0.15)
        if self.decay < 0 then
            self.decay = 0
        end
    end
end

function Ray:setOriginDest(x1,y1,z1, x2,y2,z2)
    local v_x = (x1+x2)/2 - g3d.camera.position[1]
    local v_y = (y1+y2)/2 - g3d.camera.position[2]
    local v_z = (z1+z2)/2 - g3d.camera.position[3]
    local t_x,t_y,t_z = vectors.normalize(x1-x2, y1-y2, z1-z2)
    local n_x,n_y,n_z = vectors.normalize(vectors.crossProduct(v_x,v_y,v_z, t_x,t_y,t_z))
    local r = 0.05
    n_x, n_y, n_z = n_x*r, n_y*r, n_z*r

    self.model.mesh:setVertex(1, x1-n_x, y1-n_y, z1-n_z)
    self.model.mesh:setVertex(2, x1+n_x, y1+n_y, z1+n_z)
    self.model.mesh:setVertex(3, x2-n_x, y2-n_y, z2-n_z)
    self.model.mesh:setVertex(4, x2-n_x, y2-n_y, z2-n_z)
    self.model.mesh:setVertex(5, x2+n_x, y2+n_y, z2+n_z)
    self.model.mesh:setVertex(6, x1+n_x, y1+n_y, z1+n_z)
end


function Ray:draw(battery)
    if self.enabled and battery.renderFlag then
        self.model:draw()
    end
end

return Ray