Player = class('Player')

function Player:initialize(x, y, color, peerIndex)
	local x, y = x or math.random(0, love.graphics.getWidth()), y or math.random(0, love.graphics.getHeight())
	self.position = vector(x, y)
	self.prevPosition = vector(x, y)
	self.lastSentPos = vector(x, y)

	self.velocity = vector(0, 0)
	self.prevVelocity = vector(0, 0)
	self.lastSentVel = vector(0, 0)

	self.radius = 15
	self.speed = 280
	self.color = color or {math.random(0, 225), math.random(0, 225), math.random(0, 225)}

	-- this is the goal position to be tweened towards
	-- on the client, it slowly moves it to where the server says it should be
	self.goalX = self.position.x
	self.goalY = self.position.y

	self.showRealPos = false
	self.autono = false

	self.rotateX = 0
	self.rotateY = 0

	self.circleSize = math.random(5, 15)

	-- this is the value of a player in the array of players, as determined by the server
	-- there is an issue with peerIndex and disconnect
	self.peerIndex = peerIndex or 0

	self.lerpTween = nil -- stores the tween for interpolation of a non-client player

	-- import variables from super shooter
    self.oldVelocity = vector(0, 0)
    self.friction = 5
    self.acceleration = vector(0, 0)
    self.heat = 0
    self.shotsPerSecond = 4
    self.rateOfFire = (1/self.shotsPerSecond)
    self.canShoot = true
    self.bulletVelocity = 325
    self.bulletDamage = 40
    self.bulletDropoffAmount = 15
    self.bulletDropoffDistance = 100
    self.damageMultiplier = 1.0
    self.touchDamage = 0
    self.bulletLife = 1.5
    self.bulletRadius = 5
    self.healthRegen = 1
    self.regenWaitAfterHurt = 10
    self.maxHealth = 125
    self.health = self.maxHealth
    self.waveEndRegen = 20
    self.damageResistance = 0.0
    self.criticalChance = 0.01
    self.criticalMultiplier = 2.0

    self.offScreenDamage = self.maxHealth/20
    self.regenTimer = 0

    self.x, self.y = self.position:unpack()
end

-- client function to enable autonomous movement
function Player:setAutono()
	self.autono = not self.autono

	self.rotateX = self.position.x
	self.rotateY = self.position.y
end

-- used by client for a local player
function Player:inputUpdate(time, dt)
    self.width, self.height = self.radius*2, self.radius*2
    self.x, self.y = self.position:unpack()

    self.acceleration = vector(0, 0)
	self.velocity = vector(0, 0)

	if self.autono then
		local dx = math.cos(time * self.circleSize)
		local dy = math.sin(time * self.circleSize)

		self.velocity.x = dx * self.speed
		self.velocity.y = dy * self.speed
	end

	if love.keyboard.isDown('w', 'up')    then self.velocity.y = -self.speed end
	if love.keyboard.isDown('s', 'down')  then self.velocity.y =  self.speed end
	if love.keyboard.isDown('a', 'left')  then self.velocity.x = -self.speed end
	if love.keyboard.isDown('d', 'right') then self.velocity.x =  self.speed end

	--if self.velocity.x ~= 0 and self.velocity.y ~= 0 then -- diagonal movement is multipled to be the same overall speed
	--	self.velocity.x, self.velocity.y = self.velocity.x * 0.70710678118, self.velocity.y * 0.70710678118
	--end

	if love.mouse.isDown(1) and self.canShoot then
		if time > .25 then -- prevents a bullet from being shot when the game starts
			if self.heat <= 0 then
				--local mx, my = game.camera:mousePosition() -- find where the mouse is in the game
				mx, my = love.mouse.getPosition()
                target = vector(mx, my)

                game:sendBullet(self.position, target, self.velocity)
                -- this will predict the bullet, but the server verifies it
                --[[
                local bullet = game:addBullet(Bullet:new(
                    self.position,
                    target,
                    self.velocity
                ))
                bullet:setSource(self)
                -- critical hits
                if math.random() <= self.criticalChance then
                    bullet:setDamage(self.bulletDamage * self.damageMultiplier * self.criticalMultiplier)
                    bullet.critical = true
                else
                    bullet:setDamage(self.bulletDamage * self.damageMultiplier)
                    bullet.critical = false
                end
                bullet:setSpeed(self.bulletVelocity)
                bullet:setRadius(self.bulletRadius)
                bullet:setLife(self.bulletLife)
                bullet.dropoffDistance = self.bulletDropoffDistance
                bullet.dropoffAmount = self.bulletDropoffAmount

				]]
				self.heat = self.rateOfFire

                --signal.emit('playerShot', self, bullet)
			end
		end
	end

    if self.heat > 0 then
        self.heat = self.heat - dt
    end

    self.rateOfFire = (1/self.shotsPerSecond)

    self.regenTimer = self.regenTimer - dt
    if self.regenTimer <= 0 then
        self.health = self.health + self.healthRegen * dt
	end

    --if self.health <= 0 then
    --    game:remove(self)
        --signal.emit('playerDeath')
    if self.health > self.maxHealth then
        self.health = self.maxHealth
    end

    self.maxHealth = math.max(1, self.maxHealth)

    if math.abs(self.x) >= game.worldSize.x/2 or math.abs(self.y) >= game.worldSize.y/2 then
        self.health = self.health - self.offScreenDamage * dt * (1 - self.damageResistance)
        --signal.emit('playerHurt')
    end
end

-- used by the client to set the interpolation tween
-- the player will move towards the specified location
function Player:setTween(goalX, goalY)
	self.goalX = goalX
	self.goalY = goalY

	if self.lerpTween then
		self.lerpTween:stop()
	end

	local dist = vector(goalX - self.position.x, goalY - self.position.y):len()
	local time = dist / self.speed

	self.lerpTween = flux.to(self.position, time, {x = goalX, y = goalY})
end

-- used by the client for only the local player. The client can predict where his 
-- used by the server to predict player movement - dead-reckoning
function Player:movePrediction(dt)
	-- verlet integration, much more accurate than euler integration for constant acceleration and variable timesteps
    --self.acceleration = self.acceleration:normalized() * self.speed
    --self.oldVelocity = self.velocity
    --self.velocity = self.velocity + (self.acceleration - self.friction*self.velocity) * dt
    --self.position = self.position + (self.oldVelocity + self.velocity) * 0.5 * dt
    --self.velocity = self.acceleration * dt
    self.position = self.position + self.velocity * dt

    self.x, self.y = self.position:unpack()
end

function Player:draw(showRealPos)
	showRealPos = showRealPos or false

	love.graphics.setColor(self.color)

	--love.graphics.rectangle('fill', self.position.x - self.width/2, self.position.y - self.height/2, self.width, self.height)
    love.graphics.circle("fill", self.position.x, self.position.y, self.radius)
    
	if showRealPos then
		love.graphics.setColor(255, 0, 0, 165)
		love.graphics.rectangle('fill', self.goalX, self.goalY, self.width, self.height)
	end
	love.graphics.setColor(255, 255, 255)
end