packetsSent = 0
packetsReceived = 0

-- libraries
bump = require 'lib.bump'
class = require 'lib.middleclass'
vector = require 'lib.vector'
state = require 'lib.state'
serialize = require 'lib.ser'
signal = require 'lib.signal'
bitser = require 'lib.bitser'
socket = require 'lib.sock'
flux = require 'lib.flux'
husl = require 'lib.husl'

-- gamestates
require 'states.client'
require 'states.connect'
require 'states.host'

-- entities
--require 'entities.player'
--require 'entities.enemy'

-- entities
require 'entities.entity'
require 'entities.bullet'
require 'entities.player'
require 'entities.enemy.enemy'
require 'entities.enemy.blob'
require 'entities.enemy.healer'
require 'entities.enemy.tank'
require 'entities.enemy.sweeper'
require 'entities.enemy.ninja'

function love.load(arg)
    _font = 'assets/font/OpenSans-Regular.ttf'
    _fontBold = 'assets/font/OpenSans-Bold.ttf'
    _fontLight = 'assets/font/OpenSans-Light.ttf'

    font = setmetatable({}, {
        __index = function(t,k)
            local f = love.graphics.newFont(_font, k)
            rawset(t, k, f)
            return f
        end 
    })

    fontBold = setmetatable({}, {
        __index = function(t,k)
            local f = love.graphics.newFont(_fontBold, k)
            rawset(t, k, f)
            return f
        end
    })

    fontLight = setmetatable({}, {
        __index = function(t,k)
            local f = love.graphics.newFont(_fontLight, k)
            rawset(t, k, f)
            return f
        end 
    })
    
    love.graphics.setFont(font[14])

    state.registerEvents()

    if arg[2] == "host" then
        love.window.setTitle("Server")

        if arg[3] and arg[4] then -- x and y window position
            local x, y = arg[3], arg[4]
            local display = 1
            if arg[5] then -- display number
                display = arg[5]
            end
            love.window.setPosition(x, y, display)
        end

        state.switch(host)
    else
        local name = arg[3]
        love.window.setTitle("Client")

        if arg[4] and arg[5] then -- x and y window position
            local x, y = arg[4], arg[5]
            local display = 1
            if arg[6] then -- display number
                display = arg[6]
            end
            love.window.setPosition(x, y, display)
        end

        state.switch(connect, name)
    end

    math.randomseed(os.time()/10)
end

function love.keypressed(key, code)
    if key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, mbutton)
    
end

function love.textinput(text)

end

function love.resize(w, h)

end

function love.update(dt)
    flux.update(dt)
end

function love.draw()

end
