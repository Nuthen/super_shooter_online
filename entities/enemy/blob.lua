Blob = class('Blob', Enemy)

function Blob:initialize(position, index)
    Enemy.initialize(self, position, index)
    self.originalColor = {231, 76, 60, 255}
    self.sides = 4
    self.radius = 15

    self.hue = 12
    self.saturation = 100
    self.lightness = 50
    self:randomizeAppearance(1, 3, 5, 0.1)

    local radiusOrig = 15

    self.speed = math.sqrt(760 * 1/(self.radius/radiusOrig)) * 20
    self.touchDamage = 25 * (self.radius/radiusOrig)

    self.position = position
    self.health = 100
    self.maxHealth = 100
    self.healthRadius = self.radius*self.health/self.maxHealth

    self.knockbackResistance = -.1
end

function Blob:update(dt, time, players)
    Enemy.update(self, dt, time, players)

    -- calculate the closest player. inefficient to do this in multiple areas, fix that
    local closestPlayer = nil
    local closestDist = 0

    -- finds the player closest to the enemy and stores it in closest player
    for k, player in pairs(players) do
        local dist = math.sqrt((self.position.x - player.position.x)^2 + (self.position.y - player.position.y)^2)
        if not closestPlayer or dist < closestDist then
            closestPlayer = player
            closestDist = dist
        end
    end

    local player = closestPlayer
    --

    self.moveTowardsPlayer = player.position - self.position

    self.acceleration = (self.moveTowardsPlayer + self.moveAway):normalized() * self.speed
end

function Blob:handleCollision(collision)

end
