return function(mod)
 local Healthbox=require('src.core.game3.battle.healthbox')
 local Battle=require('src.core.game3.battle')
 local Anim=require('src.core.game3.battle.anim')
 local Font=require('src.ui.game3.frlg_font')
 local Pokemon=require('src.core.game3.pokemon')
 local Status=require('src.core.game3.summary_data')
 local native=Healthbox.draw
 Healthbox.draw=function(side,battler,opts)
  local st=opts and opts.st or Battle.getState()
  local handle=mod.find and mod.find('BATTLE_ART_VOXEL_FORK')
  local ex=handle and handle.exports;local presentation=ex and ex.battlePresentation
  if presentation and presentation.nativeHudOwned and presentation.nativeHudOwned()then return native(side,battler,opts)end
  if presentation and presentation.modernUIEnabled and not presentation.modernUIEnabled()then return native(side,battler,opts)end
  if not(st and mod.options:get('modern_hud')and battler and battler.mon)then return native(side,battler,opts)end
  local id=tonumber(side)or(side=='enemy'and 1 or 0)
  local stage=Anim.stage and Anim.stage();local hb=stage and stage.healthbox and(stage.healthbox[id]or stage.healthbox[side])
  if hb and hb.visible==false then return end
  if hb and hb.levelUpBlend then return native(side,battler,opts)end
  local c=Healthbox.center(st,id);local x=c.x-32+(hb and hb.ox or 0)+(opts and opts.ox or 0)
  local y=c.y-16+(hb and hb.oy or 0)+(opts and opts.oy or 0)
  local mon=battler.mon;local _,hp,max=Anim.displayHpRatio(id,battler);hp=tonumber(hp)or mon.hp or 0;max=math.max(1,tonumber(max)or mon.maxHp or 1)
  local ratio=math.max(0,math.min(1,hp/max));local code=Status.statusAilment({status=battler.status or mon.status or mon.status1,hp=mon.hp});local status=({'PSN','PRZ','SLP','FRZ','BRN','PKRS','FNT'})[code]or''
  local name=tostring(mon.nickname and mon.nickname~=''and mon.nickname or mon.name or Pokemon.name(mon.species)):sub(1,12)
  love.graphics.push('all');love.graphics.setShader();love.graphics.setColor(.055,.10,.16,.97);love.graphics.rectangle('fill',x,y,108,22,3)
  love.graphics.setColor(.30,.48,.60,1);love.graphics.rectangle('line',x+.5,y+.5,107,21,3)
  local colors={fg={.96,.97,1,1},shadow={.055,.10,.16,1}}
  Font.draw(name,x+4,y+1,{small=true,colors=colors})
  Font.draw('L'..tostring(mon.level or 1),x+82,y+1,{small=true,colors=colors})
  love.graphics.setColor(.13,.20,.25,1);love.graphics.rectangle('fill',x+4,y+13,70,4)
  love.graphics.setColor(ratio<.2 and .95 or .2,ratio<.2 and .25 or ratio<.5 and .65 or .85,.35,1)
  love.graphics.rectangle('fill',x+4,y+13,70*ratio,4)
  Font.draw(status~=''and status or tostring(math.floor(hp)),x+79,y+10,{small=true,colors=colors})
  love.graphics.pop()
 end
end
