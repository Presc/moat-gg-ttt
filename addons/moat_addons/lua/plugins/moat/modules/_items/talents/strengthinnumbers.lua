
TALENT.ID = 37
TALENT.Suffix = "the Neighborhood"
TALENT.Name = 'Strength In Numbers'
TALENT.NameColor = Color(181, 123, 0)
TALENT.Description = "Damage is increased by %s_^ for every person within %s^ feet, your special teammates add %s_^ instead, up to a maximum of %s_^"
TALENT.Tier = 2
TALENT.LevelRequired = {min = 15, max = 25}

TALENT.Modifications = {}
TALENT.Modifications[1] = {min = 2, max = 6} -- Normal damage increase
TALENT.Modifications[2] = {min = 20, max = 40} -- Range
TALENT.Modifications[3] = {min = 6, max = 10} -- Special teammate damage increase
TALENT.Modifications[4] = {min = 20, max = 35} -- Max damage increase

TALENT.Melee = true
TALENT.NotUnique = true

if (SERVER) then
	function TALENT:ScalePlayerDamage(victim, attacker, dmginfo, hitgroup, talent_mods)
		local extraDmg 	= (self.Modifications[1].min + ((self.Modifications[1].max - self.Modifications[1].min) * math.min(1, talent_mods[1]))) / 100
		local range 	=  self.Modifications[2].min + ((self.Modifications[2].max - self.Modifications[2].min) * math.min(1, talent_mods[2]))
		range = range * range

		local bonusDmg 	= (self.Modifications[3].min + ((self.Modifications[3].max - self.Modifications[3].min) * math.min(1, talent_mods[3]))) / 100
		local maxDmg 	=  self.Modifications[4].min + ((self.Modifications[4].max - self.Modifications[4].min) * math.min(1, talent_mods[4]))

		local dmg = 1
		local attPos = attacker:GetPos()
		local isTraitor = attacker:GetTraitor()
		local isDetective = attacker:GetDetective()
		-- It's faster to loop through all players then to find all ents in sphere
		for _, pl in ipairs(player.GetAll()) do
			if (not IsValid(pl)) then continue end
			if (not pl:Alive()) then continue end
			if (attPos:DistToSqr(pl:GetPos()) > range) then continue end
			
			local b = extraDmg
			if (isTraitor and pl:GetTraitor()) then
				b = bonusDmg
			elseif (isDetective and pl:GetDetective()) then
				b = bonusDmg
			end
			
			dmg = dmg + b
		end

		dmg = math.min(dmg, maxDmg)
		dmginfo:ScaleDamage(dmg)
	end
end