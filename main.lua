io.stdout:setvbuf("no")

local lg = love.graphics
lg.setDefaultFilter("nearest")

local g3d = require "g3d"
local Player = require "player"
local vectors = require "g3d/vectors"
local primitives = require "primitives"
local Battery = require "battery"
local Ray = require "ray"
local Powerup = require "powerup"
local Music = require "music"
local Menu = require "menu"

local map, background, player, battery, arcadeCabinet, powerup, music, settings
local canvas
local accumulator = 0
local frametime = 1/60
local rollingAverage = {}

local debugFont = love.graphics.newFont(14)

local tutorial_textures = {
    love.graphics.newImage("assets/tutorial/billboard_1.png"),
    love.graphics.newImage("assets/tutorial/billboard_2.png"),
    love.graphics.newImage("assets/tutorial/billboard_3.png"),
    love.graphics.newImage("assets/tutorial/billboard_4.png"),
    love.graphics.newImage("assets/tutorial/billboard_5.png"),
    love.graphics.newImage("assets/tutorial/billboard_6.png"),
}

local score_textures = {
    love.graphics.newImage("assets/numbers/0.png"),
    love.graphics.newImage("assets/numbers/1.png"),
    love.graphics.newImage("assets/numbers/2.png"),
    love.graphics.newImage("assets/numbers/3.png"),
    love.graphics.newImage("assets/numbers/4.png"),
    love.graphics.newImage("assets/numbers/5.png"),
    love.graphics.newImage("assets/numbers/6.png"),
    love.graphics.newImage("assets/numbers/7.png"),
    love.graphics.newImage("assets/numbers/8.png"),
    love.graphics.newImage("assets/numbers/9.png"),
}

local battery_textures = {
    love.graphics.newImage("assets/battery/5b.png"),
    love.graphics.newImage("assets/battery/5.png"),
    love.graphics.newImage("assets/battery/4.png"),
    love.graphics.newImage("assets/battery/3.png"),
    love.graphics.newImage("assets/battery/2.png"),
    love.graphics.newImage("assets/battery/1.png"),
}
local battery_texture_zero = love.graphics.newImage("assets/battery/6.png")

local banner = love.graphics.newImage("assets/banner.png")

local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

function love.load()
    lg.setBackgroundColor(0.25,0.5,1)

    -- map
    map = g3d.newModel("assets/factory6.obj", "assets/factory6.png", nil, nil, {-1,-1,1})
    map:setTranslation(0,0,0)

    -- background
    background = g3d.newModel("assets/sphere.obj", "assets/starfield.png", {0,0,0}, nil, {500,500,500})

    -- forcefield
    forcefield = g3d.newModel("assets/forcefield.obj", "assets/forcefield.png", {0,0,0}, {0,0,0}, {-1, -1, 1})
    forcefield:setTranslation(0,-100,0)


    -- player
    player = Player:new(2,-1,-0.4)
    player:addCollisionModel(map)
    player:addCollisionModel(forcefield)

    -- battery
    battery = Battery:new(1,-0.5,0.4)
    battery:addCollisionModel(map)
    battery:addCollisionModel(arcadeCabinet)

    -- arcade cabinet
    arcadeCabinet = g3d.newModel("assets/arcade.obj", "assets/arcade.png", {2,0,0.4}, {0,0,0}, {0.8,0.8,0.8})
    player:addCollisionModel(arcadeCabinet)

    -- ray
    ray = Ray:new()
    ray:setOriginDest(0, 100, 0, 0, 100, 0)

    -- powerup
    powerup = Powerup:new(2,-1,-0.4)
    powerup:addCollisionModel(map)
    powerup:addCollisionModel(arcadeCabinet)

    -- music handler
    music = Music:new()
    --music:pause()-- pause while testing other sounds

    -- menu
    musicmenu = Menu:new(0, -0.5, -13, "music", "assets/menu/music.obj", "assets/menu/music.png", "assets/menu/nomusic.obj", "assets/menu/nomusic.png")

    difficultymenu = Menu:new(-2, -0.5, -13, "difficulty", "assets/menu/fast.obj", "assets/menu/fast.png", "assets/menu/slow.obj", "assets/menu/slow.png")

    -- settings sign
    settings = g3d.newModel("assets/menu/settings.obj", "assets/menu/settings.png", {0,0,0}, {0,0,0}, {0.5, 0.5, 0.5})
    settings:setTranslation(-2, -2, -13)

    --canvas = {lg.newCanvas(1024,576), depth=true}
    canvas = {lg.newCanvas(1024,576), depth=true}
end

function love.update(dt)
    -- rolling average so that abrupt changes in dt
    -- do not affect gameplay
    -- the math works out (div by 60, then mult by 60)
    -- so that this is equivalent to just adding dt, only smoother
    table.insert(rollingAverage, dt)
    if #rollingAverage > 60 then
        table.remove(rollingAverage, 1)
    end
    local avg = 0
    for i,v in ipairs(rollingAverage) do
        avg = avg + v
    end

    -- fixed timestep accumulator
    accumulator = accumulator + avg/#rollingAverage
    while accumulator > frametime do
        accumulator = accumulator - frametime
        
        player:update(dt)
    end

    -- update battery
    battery:update(dt, player, map, ray, powerup)

    -- powerup update
    powerup:update(dt, player, ray, battery)

    -- update between frames if searching
    if battery.searching then
        battery:search(player, map, ray, powerup)
    end

    if powerup.searching then
        powerup:search(player, ray, battery)
    end

    if battery.batteryCount > 0 and battery.timer > 0 then
        forcefield:setTranslation(0,0,0)
    else
        forcefield:setTranslation(0,-100,0)
    end

    -- update ray
    ray:update(dt, battery)

    -- update music
    music:update(dt, battery)

    -- update menu
    musicmenu:update(dt, music, battery, player)
    difficultymenu:update(dt, music, battery, player)

    -- interpolate player between frames
    -- to stop camera jitter when fps and timestep do not match
    player:interpolate(accumulator/frametime)
    background:setTranslation(g3d.camera.position[1],g3d.camera.position[2],g3d.camera.position[3])
end

function love.keypressed(k)
    if k == "escape" then love.event.push("quit") end
    if k == "f1" then
        --love.window.setFullscreen(not love.window.getFullscreen())
        if love.window.getFullscreen() then
            screenWidth, screenHeight = 1024, 576
            love.window.setMode(1024, 576, {fullscreen=false})
            canvas = {lg.newCanvas(1024,576), depth=true}
        else
            love.window.setMode(0, 0, {fullscreen=true})
            screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
            canvas = {lg.newCanvas(screenWidth, screenHeight), depth=true}
        end
    end
    if k == "r" then
        battery:reset()
        powerup:reset()
        player:reset()
    end
end

function love.resize(w,h)
    Camera.aspectRatio = love.graphics.getWidth()/love.graphics.getHeight()
    G3DShader:send("projectionMatrix", GetProjectionMatrix(Camera.fov, Camera.nearClip, Camera.farClip, Camera.aspectRatio))
end

function love.mousemoved(x,y, dx,dy)
    g3d.camera.firstPersonLook(dx,dy)
end

local function setColor(r,g,b,a)
    lg.setColor(r/255, g/255, b/255, a and a/255)
end

function love.draw()
    lg.setCanvas(canvas)
    lg.clear(0,0,0,0)

    g3d.camera.updateViewMatrix(g3d.shader)
    g3d.camera.updateProjectionMatrix(g3d.shader)
    
    --lg.setDepthMode("lequal", true)

    love.graphics.setShader(map.shader)
    --local lightPosition = player.position
    --map.shader:send("lightPosition", {lightPosition[1], lightPosition[2], lightPosition[3]})
    map.shader:send("modelMatrix", map.matrix)
    love.graphics.draw(map.mesh)
    love.graphics.setShader()

    -- draw battery
    battery:draw()

    -- draw powerup
    powerup:draw()

    --map:draw()
    background:draw()

    arcadeCabinet:draw()

    -- draw menu
    musicmenu:draw()
    difficultymenu:draw()
    settings:draw()

    -- draw forcefield
    forcefield:draw()

    lg.setColor( 164 / 255, 219 / 255, 232 / 255, ray.decay)
    ray:draw(battery)
    lg.setColor(1,1,1)

    drawTimer()

    -- draw to arcade cabinet depending on gamestate
    if battery.timer <= 0 then
        drawScoreboard(2,1.3,0.4)
    else
        drawArcade(2,1.3,0.4)
    end

    -- debug
    --lg.print("ORB xyz: "..battery.position[1]..", "..battery.position[2]..", "..battery.position[2], 10, 10)

    lg.setColor(1,1,1)

    lg.setCanvas()
    lg.draw(canvas[1], screenWidth/2, screenHeight/2, 0, 1,-1, screenWidth/2, screenHeight/2)

    -- PRINT AFTER THIS POINT FOR CORRECT ORIENTATION
    -- debug info
    --lg.print("FPS: "..love.timer.getFPS().." difficulty: "..(math.ceil(battery.difficultyMultiplier*1000)/1000).." timer: "..(math.ceil(battery.timer*1000)/1000).." game time: "..(math.ceil(battery.gameTimer*1000)/1000), 10, 10)
    --lg.print("X"..player.position[1].." Y"..player.position[2].." Z"..player.position[3], 10, 10)
    --local musicpausedstr, difficultystr
    --if music.paused then musicpausedstr = "yes"  else musicpausedstr = "no"  end
    --if battery.difficultyEnabled then difficultystr = "fast" else difficultystr = "slow" end
    --lg.print("Menu: music: "..musicpausedstr.." difficulty: "..difficultystr, 10, 10)
    --lg.print("menu1 renderTimer: "..musicmenu.renderTimer..", menu2 renderTimer: "..difficultymenu.renderTimer, 10, 30)

    -- draw tutorial in top corner (mirror arcade screen)
    --drawBanner()

    --lg.print(collectgarbage("count"))
end

function drawTimer()
    --local fontSpacing = 2
	local w,h = 400, 160
	local x,y = 20, 20--576 - 20 - h
	--local str = "+"..math.floor( battery.timer )
	--
	---- bg
	--lg.setColor( 25 / 255, 30 / 255, 60 / 255 )
	--lg.rectangle( "fill", x,y, w,h )
	--
	---- bar
	--lg.setColor( 215 / 255, 45 / 255, 45 / 255 )
	--lg.rectangle( "fill", x,y, w * battery.timer / battery.maxTimer, h )
	--
	--lg.setColor( 1,1,1 )
	--lg.print( str, x + fontSpacing,y )

    if battery.batteryCount > 0 then

        local scale = 0.2 * (screenWidth/1024)

        if battery.timer < 1 then
            -- draw empty bar
            lg.draw(battery_texture_zero, x,y, 0, scale, scale)
        else
            local idx = battery.timer / (battery.maxTimer / 6)
            -- round idx up to nearest 1
            idx = math.ceil(idx)
            -- draw battery image at idx
            lg.draw(battery_textures[idx], x,y, 0, scale, scale)
        end
    else
        -- battery for tutorial
        if player.tutorial_progression  < 5 then
            lg.draw(battery_textures[6], x,y, 0, 0.2, 0.2)
        else
            lg.draw(battery_textures[1], x,y, 0, 0.2, 0.2)
        end
    end
    
end

function drawArcade(x,y,z)
    if battery.batteryCount == 0 then
        -- draw in front of arcade cabinet
        lg.setColor( 1, 1, 1 )
        primitives.updateRectangleTexture(tutorial_textures[player.tutorial_progression+1])
        primitives.rectangle(x-0.004, y-1.95, z+0.05, 0, 0, 0, 0.6, 0.6, 1)

        lg.setColor( 215 / 255, 45 / 255, 45 / 255 )
        --primitives.rectangle(0,0,0.2, 0, 0, 0, 1, 1, 1)
        local loadingbar = x+0.296-(math.min((player.tutorial_progression_steps_max - player.tutorial_progression_steps), 1)*0.6)
        primitives.line(x+0.296,y-1.7,z+0.05, loadingbar,y-1.7,z+0.05)
    else
        -- use bar as copy of timer
        lg.setColor( 1, 1, 1 )
        primitives.updateRectangleTexture(tutorial_textures[6])
        primitives.rectangle(x-0.004, y-1.95, z+0.05, 0, 0, 0, 0.6, 0.6, 1)

        lg.setColor( 215 / 255, 45 / 255, 45 / 255 )
        --primitives.rectangle(0,0,0.2, 0, 0, 0, 1, 1, 1)
        local loadingbar = x+0.296-(math.min((battery.timer/battery.maxTimer), 1)*0.6)
        primitives.line(x+0.296,y-1.7,z+0.05, loadingbar,y-1.7,z+0.05)
    end
end

function drawBanner()
    if battery.batteryCount == 0 then
        local x, y = 20, 20
        local scale = 0.2 * (screenWidth/1024)

        -- draw banner image
        lg.draw(banner, x,y, 0)

        -- draw text
        lg.setColor( 1, 1, 1 )
        lg.print("Tutorial", x+20, y+20)

        -- draw current tutorial step progress bar
        lg.setColor( 215 / 255, 45 / 255, 45 / 255 )
        local loadingbar = x+0.296-(math.min((player.tutorial_progression_steps_max - player.tutorial_progression_steps), 1)*0.6)
        lg.rectangle("fill", x,y, loadingbar, 20)
        
        -- reset colour
        lg.setColor( 1, 1, 1 )
    end
end

function drawScoreboard(x,y,z)
    local score = battery.batteryCount

    -- constrain to max 99 score (2 digits)
    if score > 99 then score = 99 end

    -- convert to string
    local scoreString = ""
    while score > 0 do
        scoreString = string.char(48 + score % 10)..scoreString
        score = math.floor(score / 10)
    end

    -- pad left with zeros to 2 digits
    while #scoreString < 2 do
        scoreString = "0"..scoreString
    end

    local digit1 = tonumber(string.sub(scoreString, 1, 1))+1
    local digit2 = tonumber(string.sub(scoreString, 2, 2))+1

    local model1 = g3d.newModel("assets/board.obj", score_textures[digit1])
    local model2 = g3d.newModel("assets/board.obj", score_textures[digit2])
    local message = g3d.newModel("assets/board.obj", "assets/scoreboard_message.png")

    lg.setColor( 1, 1, 1 )
    primitives.rectangle(x-0.15, y-1.99, z+0.05, 0, 0, 0, 0.3, 0.48, 0.6, model1)
    primitives.rectangle(x+0.15, y-1.99, z+0.05, 0, 0, 0, 0.3, 0.48, 0.6, model2)
    primitives.rectangle(x, y-1.7, z+0.05, 0, 0, 0, 0.6, 0.12, 0.6, message)
end