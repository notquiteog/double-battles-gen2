-- Secondary targets of one move, retaining native damage and Substitute/Bide.
local M={}
function M.targets(b,user,primary,kind)
 local out={}
 local own=user.isPlayer and 'player' or 'enemy'
 local foe=user.isPlayer and 'enemy' or 'player'
 -- Actor-relative order is identical on mirrored online peers.
 for _,slot in ipairs({foe,foe..'2',own,own..'2'})do
  local mon=b[slot]
  if mon and mon~=user and mon~=primary and mon.mon.hp>0
      and (kind=='others' or mon.isPlayer~=user.isPlayer)then out[#out+1]=mon end
 end
 return out
end
function M.ripple(b,user,primary,action,kind,targets)
 local move=action and b.data.moves[action.id]
 if not move or (move.power or 0)<=0 then return end
 local exploded=move.effect=='EXPLODE_EFFECT'
 if b.result or (user.mon.hp<=0 and not exploded)then return end
 for _,victim in ipairs(targets or M.targets(b,user,primary,kind))do
  -- Native Gen1 Fly/Dig is invulnerable, including against Earthquake.
  if victim.mon.hp>0 and not victim.invulnerable and b:accuracyRoll(move,user,victim)then
   local damage,info=b:computeDamage(user,victim,move,{rng=b.rng,explode=exploded})
   damage=math.floor((tonumber(damage)or 0)*.75)
   if damage>0 then
    local Strings=require('src.core.Strings')
    b:sayNext(Strings('It also hit\n%s!',victim.name))
    b.lastDamage=damage -- native shared Counter register
    local dealt=b:applyDamage(victim,damage)
    local Runtime=require('src.mods.Runtime')
    Runtime.emit('battle.damage_dealt',{battle=b,user=user,target=victim,move=move,
      damage=dealt,crit=info and info.crit,typeMult=info and info.typeMult})
    b:handleBuildingRage(victim)
    if victim.mon.hp<=0 then b:onFaint(victim)end
   end
  end
 end
end
return M
