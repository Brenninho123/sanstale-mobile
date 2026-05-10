local lg = love.graphics

camera = require "lib.camera"
anim8  = require "lib.anim8"
         require "errhand"
dialog = require "ui.dialog"
menu   = require "ui.menu"
sans   = require "game.sans"
music  = require "game.music"
rooms  = require "game.rooms"
save   = require "save"

local touchkeys = {}
local touches   = {}
local isMobile  = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local vpad      = {}

local _isDown = love.keyboard.isDown
love.keyboard.isDown = function(...)
    for i = 1, select("#", ...) do
        if touchkeys[select(i, ...)] then return true end
    end
    return _isDown(...)
end

local function buildVPad()
    local pad  = math.min(width, height) * 0.18
    local cx   = pad * 1.6
    local cy   = height - pad * 1.6
    vpad.dpad  = { x = cx, y = cy, size = pad }

    local bx   = width - pad * 0.7
    local by   = height - pad * 0.7
    local r    = pad * 0.42
    vpad.btnA  = { x = bx,          y = by, r = r }
    vpad.btnB  = { x = bx - pad,    y = by, r = r }
    vpad.btnM  = { x = width - r*1.4, y = r*1.4, r = r * 0.6 }
end

local function hitDpad(tx, ty)
    local d  = vpad.dpad
    local dx = tx - d.x
    local dy = ty - d.y
    if math.abs(dx) > d.size or math.abs(dy) > d.size then return nil end
    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and "right" or "left"
    else
        return dy > 0 and "down" or "up"
    end
end

local function hitCircle(btn, tx, ty)
    if not btn then return false end
    local dx = tx - btn.x
    local dy = ty - btn.y
    return dx*dx + dy*dy <= btn.r * btn.r
end

local function resolveKey(tx, ty)
    local k = hitDpad(tx, ty)
    if k then return k end
    if hitCircle(vpad.btnA, tx, ty) then return "z"      end
    if hitCircle(vpad.btnB, tx, ty) then return "x"      end
    if hitCircle(vpad.btnM, tx, ty) then return "m"      end
    return nil
end

local function pressKey(key)
    touchkeys[key] = (touchkeys[key] or 0) + 1
    love.keypressed(key)
    print("Touch press: " .. key)
end

local function releaseKey(key)
    touchkeys[key] = (touchkeys[key] or 1) - 1
    if touchkeys[key] <= 0 then touchkeys[key] = nil end
    love.keyreleased(key)
    print("Touch release: " .. key)
end

function collision(x1,y1,w1,h1, x2,y2,w2,h2)
    return x1 < x2+w2 and x2 < x1+w1 and y1 < y2+h2 and y2 < y1+h1
end

function love.load(arg)
    CONFIRM = {z=true, ["return"]=true}
    CANCEL  = {x=true, rshift=true}
    width   = lg.getWidth()
    height  = lg.getHeight()
    dialog:load()
    music:load()

    state = "menu"

    debugon = (arg[2] == "debug")
    if debugon then
        debugtext = lg.newText(dialog.fonts.determination, "DEBUG ON")
    end

    save.file = ".h€lP_00"
    save.load()

    playtime = playtime or 0
    music:play("startmenu", true)

    if isMobile then
        buildVPad()
        love.keyboard.setTextInput(false)
        print("Mobile mode initialized")
    end
end

function love.resize(w, h)
    width  = w
    height = h
    if isMobile then
        buildVPad()
        print("Virtual pad rebuilt: " .. w .. "x" .. h)
    end
end

function love.update(dt)
    if state == "overworld" then
        playtime = playtime + dt
        if not rooms.changing then
            sans:move(dt)
            sans:update(dt)
        end
        rooms:opupdate(dt)
        rooms[rooms.current]:update(dt)
    end
end

local function drawVPad()
    if not isMobile then return end
    lg.push("all")

    local d  = vpad.dpad
    local s  = d.size * 0.38
    lg.setColor(1, 1, 1, 0.30)
    lg.rectangle("fill", d.x - s/2,  d.y - d.size,        s, d.size * 0.82, 4, 4)
    lg.rectangle("fill", d.x - s/2,  d.y + d.size * 0.18, s, d.size * 0.82, 4, 4)
    lg.rectangle("fill", d.x - d.size,        d.y - s/2,  d.size * 0.82, s, 4, 4)
    lg.rectangle("fill", d.x + d.size * 0.18, d.y - s/2,  d.size * 0.82, s, 4, 4)

    local function drawBtn(btn, r, g, b, label)
        local active = touchkeys[label == "Z" and "z" or label == "X" and "x" or "m"]
        lg.setColor(r, g, b, active and 0.75 or 0.35)
        lg.circle("fill", btn.x, btn.y, btn.r)
        lg.setColor(1, 1, 1, 0.90)
        lg.printf(label, btn.x - btn.r, btn.y - btn.r * 0.45, btn.r * 2, "center")
    end

    drawBtn(vpad.btnA, 0.25, 0.75, 0.35, "Z")
    drawBtn(vpad.btnB, 0.75, 0.25, 0.25, "X")
    drawBtn(vpad.btnM, 0.6,  0.6,  0.6,  "M")

    lg.pop()
end

function love.draw(cameras)
    if cameras ~= false and state == "overworld" then
        camera:set()
    end
    if state == "menu" then
        menu:draw()
    elseif state == "overworld" then
        if not rooms[rooms.current].noscrollx then
            camera:setX(sans.x - width/2 + sans.width/2)
        end
        if not rooms[rooms.current].noscrolly then
            camera:setY(sans.y - height/2 + sans.height/2)
        end
        rooms[rooms.current]:draw()
        sans:draw()
        rooms:opdraw()
    end
    if cameras ~= false and state == "overworld" then
        camera:unset()
    end
    if debugon then
        lg.draw(debugtext, 0, height - debugtext:getHeight())
    end
    drawVPad()
end

function love.keypressed(k)
    if k == "escape" then
        love.event.quit()
    elseif k == "m" then
        if love.audio.getVolume() > 0 then
            love.audio.setVolume(0)
        else
            love.audio.setVolume(1)
        end
    elseif CONFIRM[k] then
        if state == "overworld" then
            sans:check()
        elseif state == "menu" then
            if not menu.resetti then
                if menu.resetted then
                    menu.resetted = false
                elseif menu.selected then
                    state = "overworld"
                    save.load()
                    music:play(rooms[rooms.current].music, true)
                else
                    menu.resetti = true
                end
            else
                if menu.resetsel then
                    menu.selected = true
                    menu.resetti  = false
                else
                    menu.resetti  = false
                    menu.resetted = true
                    print("Game reset")
                    sans.x, sans.y = 100, 100
                    rooms:load("sans")
                    playtime = 0
                    love.filesystem.remove(save.file)
                end
            end
        end
    elseif k == "right" or k == "left" then
        if state == "menu" then
            if not menu.resetti then
                menu.selected = k == "left"
            else
                menu.resetsel = k == "left"
            end
        end
    elseif k == "e" and debugon then
        error("ERROR INVOKED by pressing 'e'")
    elseif k == "s" and debugon then
        print("Force saved")
        save.save()
    elseif k == "lshift" and debugon then
        print("Super speed on")
        sans.speed = 1000
    end
end

function love.keyreleased(k)
    if k == "up" or k == "down" or k == "left" or k == "right" then
        sans.anim.paused = true
    elseif k == "lshift" and debugon then
        print("Super speed off")
        sans.speed = sans.def_speed
    end
end

function love.touchpressed(id, tx, ty)
    local key = resolveKey(tx, ty)
    if not key then return end
    touches[id] = key
    pressKey(key)
end

function love.touchmoved(id, tx, ty)
    local prev = touches[id]
    local next = resolveKey(tx, ty)
    if prev == next then return end
    if prev then releaseKey(prev) end
    if next then pressKey(next)   end
    touches[id] = next
end

function love.touchreleased(id)
    local key = touches[id]
    if key then
        releaseKey(key)
        touches[id] = nil
    end
end
