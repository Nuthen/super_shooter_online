game = {}

inspect = require "lib.inspect"
require "entities.input"

function game:add(obj, tabl, index)
    index = index or #tabl

    if tabl == nil then
        tabl = objects
    end
    for i, v in pairs(tabl) do
        assert(v ~= obj)
    end
    table.insert(tabl, index, obj)

    local r = obj.maxRadius or obj.radius -- takes the maxRadius if it exists (for objects with changing radius), otherwise just the radius
    self.world:add(obj, obj.position.x - r, obj.position.y - r, r*2, r*2)

    return obj
end
function game:addBullet(obj)
    return self:add(obj, bullets)
end

function game:remove(obj, tabl)
    if tabl == nil then
        tabl = objects
    end
    for i, v in ipairs(tabl) do
        if v == obj then
            table.remove(tabl, i)
            break
        end
    end
    self.world:remove(obj)    
end

function game:removeBullet(obj)
    self:remove(obj, bullets)
end

function game:sendBullet(position, target, velocity)
    self.client:emit("addBullet", {xPos = position.x, yPos = position.y, xTar = target.x, yTar = target.y, xVel = velocity.x, yVel = velocity.y})
end

function game:init()
    self.players = {}
    self.enemies = {}
    self.bullets = {}

    self.ownPlayerIndex = 0

    self.client = socket.Client:new("localhost", 22122, true)
    self.client.timeout = 8
    print('--- game ---')
    
    self.client:on("connect", function(data)
        self.client:emit("identify", self.username)
    end)

    self.users = {}
    self.client:on("userlist", function(data)
        self.users = data
        print(inspect(data))
    end)

    self.client:on("error", function(data)
        error(data)
    end)

    self.client:on("newPlayer", function(data)
        local connectId = data.index
        local player = Player:new(data.x, data.y, data.color, connectId)
        table.insert(self.players, connectId, player)  -- changed here to debug
    end)

    self.client:on("index", function(data)
        self.ownPlayerIndex = data
    end)

    self.client:on("movePlayer", function(data)
        local player = self.players[data.index]
        if data.index ~= self.ownPlayerIndex then
            player:setTween(data.x, data.y)
        else
            --player.position.x = data.x
            --player.position.y = data.y
            player.goalX = data.x
            player.goalY = data.y
        end
    end)

    self.client:on("newEnemy", function(data)
        self:newEnemy(Blob, data.x, data.y, data.index)
    end)

    self.client:on("newBullet", function(data)
        local position = vector(data.xPos, data.yPos)
        local target = vector(data.xTar, data.yTar)
        local velocity = vector(data.xVel, data.yVel)
        local index = data.index -- this won't work right if bullets get removed
        local bullet = self:newBullet(position, target, velocity, index)
        local sourceId = data.sourceId
        bullet:setSource(self.players[sourceId])
    end)

    self.client:on("moveEnemy", function(data)
        local enemy = self.enemies[data.index]
        if enemy then
            --enemy:setTween(data.x, data.y)

            local dist = vector(enemy.position.x - data.x, enemy.position.y - data.y):len()
            if dist > self.enemyTolerance then
                enemy.position.x = data.x
                enemy.position.y = data.y
                enemy.velocity.x = data.vx
                enemy.velocity.y = data.vy
            end

            --local deg = data.deg
            --enemy.velocity.x = math.cos(math.rad(data.deg)) * enemy.speed
            --enemy.velocity.y = math.sin(math.rad(data.deg)) * enemy.speed
        end

        self.client:log("moveEnemy", data.x ..' '.. data.y ..' '.. data.vx ..' '.. data.vy)
        --self.client:log("moveEnemy", data.x ..' '.. data.y ..' '.. data.deg)
    end)

    self.chatting = false
    self.chatInput = Input:new(0, 0, 400, 100, font[24])
    self.chatInput:centerAround(love.graphics.getWidth()/2, love.graphics.getHeight()/2-150)
    self.chatInput.border = {127, 127, 127}

    self.timer = 0
    self.tick = 1/60
    self.tock = 0

    self.showRealPos = false

    -- collision detection
    self.worldSize = vector(3000, 2000)

    self.cellSize = 200
    self.world = bump.newWorld(self.cellSize)

    self.enemyTolerance = 100 -- distance where client will ignore an enemy position from the server
end

function game:newEnemy(enemyType, x, y, index)
    local enemy = enemyType:new(vector(x, y), index)
    local r = enemy.radius
    --self:add(enemy, index, self.enemies)
    self.enemies[index] = enemy
    local obj = enemy
    local r = obj.maxRadius or obj.radius -- takes the maxRadius if it exists (for objects with changing radius), otherwise just the radius
    self.world:add(obj, obj.position.x - r, obj.position.y - r, r*2, r*2)
end

function game:newBullet(position, target, velocity, index)
    local bullet = Bullet:new(position, target, velocity)
    self.bullets[index] = bullet

    local obj = bullet
    local r = obj.maxRadius or obj.radius -- takes the maxRadius if it exists (for objects with changing radius), otherwise just the radius
    self.world:add(obj, obj.position.x - r, obj.position.y - r, r*2, r*2)

    return bullet
end

function game:enter(prev, hostname, username)
    self.client.hostname = hostname
    self.client:connect()
    
    self.username = username
end

function game:quit()
    -- if client is not disconnected, the server won't remove it until the game closes
    self.client:disconnect()
end

function game:keypressed(key, code)
    if key == 'f1' then
        self.showRealPos = not self.showRealPos
    end

    if key == 'f2' then
        local clientId = self.client.connectId
        local player = self.players[self.ownPlayerIndex]  -- changed here to debug
        player:setAutono()
    end

    if key == 'space' then
        self.client:emit("addEnemy", { })
    end

    if key == 'r' then
        self.client:emit("resetEnemy", { })
    end
end

function game:keyreleased(key, code)

end

function game:mousereleased(x, y, button)

end

function game:textinput(text)

end

function game:update(dt)
    self.timer = self.timer + dt
    self.tock = self.tock + dt
    
    -- only do an input update for your own player
    local clientId = self.client.connectId
    local player = self.players[self.ownPlayerIndex]  -- changed here to debug
    if player then
        player:inputUpdate(self.timer, dt)
        player:movePrediction(dt)
    end

    --for k, enemy in pairs(self.enemies) do
    --    enemy:update(dt, game.timer, self.players, self.world)
        --enemy:movePrediction(dt)
        --enemy:setTween(enemy.position.x, enemy.position.y)
    --end

    --if player.health >= 0 then
        --local toUpdate = {objects, bullets}
        local toUpdate = {self.enemies, self.bullets}
        for i, tabl in ipairs(toUpdate) do
            for j, obj in ipairs(tabl) do
                -- update object positions
                obj:update(dt, self.time, self.players)

                local r = math.max(1, obj.radius) -- bump requires the radius to be at least 1
                self.world:update(obj, obj.position.x - r, obj.position.y - r, r*2, r*2)

                -- check for object collisions
                local ax, ay, cols, len = self.world:check(obj, obj.position.x - r, obj.position.y - r)
                obj.moveAway = vector(0, 0)
                for i=1, len do
                    obj:handleCollision(cols[i])
                    if obj._handleCollision then
                        obj:_handleCollision(cols[i])
                    end
                end
            end

            -- remove objects that are marked to be destroyed
            for j = #tabl, 1, -1 do
                local obj = tabl[j]
                --if obj.destroy then
                --  self:remove(obj, tabl)
                --end
            end
        end
    --end

    self.client:update(dt)

    if self.tock >= self.tick then
        self.tock = 0

        if player then
            local xPos = math.floor(player.position.x*1000)/1000
            local yPos = math.floor(player.position.y*1000)/1000
            local xVel = math.floor(player.velocity.x*1000)/1000
            local yVel = math.floor(player.velocity.y*1000)/1000

            if xPos ~= player.lastSentPos.x or yPos ~= player.lastSentPos.y or xVel ~= player.lastSentVel.x or yVel ~= player.lastSentVel.y then
                self.client:emit("entityState", {x = xPos, y = yPos, vx = xVel, vy = yVel})

                player.lastSentPos.x, player.lastSentPos.y = xPos, yPos
                player.lastSentVel.x, player.lastSentVel.y = yVel, xVel
            end
        end
    end
end

function game:draw()
    love.graphics.setColor(255, 255, 255)

    for k, player in pairs(self.players) do
        player:draw(self.showRealPos)
    end

    for k, enemy in pairs(self.enemies) do
        enemy:draw()
    end

    for k, bullet in pairs(self.bullets) do
        bullet:draw()
    end

    love.graphics.setColor(255, 255, 255)

    love.graphics.print('FPS: '..love.timer.getFPS(), 300, 5)

    love.graphics.setFont(font[20])
    love.graphics.print("client : " .. self.username, 5, 5)

    love.graphics.print("You are currently playing with:", 5, 40)

    for i, user in ipairs(self.users) do
        love.graphics.print(i .. ". " .. user, 5, 40+25*i)
    end

    love.graphics.print("You are #"..self.ownPlayerIndex, 5, 500)

    -- print each player's name
    local j = 1
    for k, player in pairs(self.players) do
        love.graphics.print('#'..player.peerIndex, 100, 40+25*j)
        j = j + 1
    end

    -- print the ping
    local ping = self.client.server:round_trip_time() or -1
    love.graphics.print('Ping: '.. ping .. 'ms', 140, 40+25)

    -- print the amount of data sent
    local sentData = self.client.host:total_sent_data()
    sentDataSec = sentData/self.timer
    sentData = math.floor(sentData/1000) / 1000 -- MB
    sentDataSec = math.floor(sentDataSec/10) / 100 -- KB/s
    love.graphics.print('Sent Data: '.. sentData .. ' MB', 46, 420)
    love.graphics.print('| ' .. sentDataSec .. ' KB/s', 250, 420)

    local packetsSentSec = packetsSent / self.timer
    packetsSentSec = math.floor(packetsSentSec*10000)/10000
    love.graphics.print('Sent Packets: '.. packetsSent, 370, 420)
    love.graphics.print('| ' .. packetsSentSec .. ' packet/s', 594, 420)

    -- print the amount of data received
    local receivedData = self.client.host:total_received_data()
    receivedDataSec = receivedData/self.timer
    receivedData = math.floor(receivedData/1000) / 1000 -- converted to MB and rounded some
    receivedDataSec = math.floor(receivedDataSec/10) / 100 -- should be in KB/s
    love.graphics.print('Received Data: '.. receivedData .. ' MB', 5, 450)
    love.graphics.print('| ' .. receivedDataSec .. ' KB/s', 250, 450)

    local packetsReceivedSec = packetsReceived / self.timer
    packetsReceivedSec = math.floor(packetsReceivedSec*10000)/10000
    love.graphics.print('Received Packets: '.. packetsReceived, 370, 450)
    love.graphics.print('| ' .. packetsReceivedSec .. ' packet/s', 594, 450)

    love.graphics.print("Enemies: " .. #self.enemies, 450, 25)
end
