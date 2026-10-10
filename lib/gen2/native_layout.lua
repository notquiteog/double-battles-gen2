-- Native 160x144 doubles composition. Reuse ROM HUD tiles, palettes and
-- sprite/animation drawing; only the additional battle's layout changes.
local M={}
local function active(s)return s.battle and s.battle.doubles and not s.tutorial end
local function transformed(x,y,scale,ox,oy,fn)
 local g=love.graphics;g.push('all');g.translate(x,y);g.scale(scale,scale);g.translate(-ox,-oy)
 local ok,result=pcall(fn);g.pop();if not ok then error(result,0)end;return result
end
function M.install(State)
 if State.nativeDoubleLayoutInstalled then return end
 State.nativeDoubleLayoutInstalled=true
 -- Optional scene renderers can paint native backplates in exactly this
 -- layout without depending on the doubles package or guessing its slots.
 State.drawNativeDoublesBackplates=function(s,drawBox)
  if not active(s) then return false end
  for _,side in ipairs({'enemy','player'})do
   local enemy=side=='enemy'
   for index=1,2 do
    if s:activeMon(index==1 and side or side..'2')then
     transformed(enemy and 2 or 90,enemy and(2+(index-1)*24)or(46+(index-1)*25),
      enemy and .75 or .625,enemy and 8 or 80,enemy and 0 or 56,
      function()drawBox(enemy and 0 or 9,enemy and 0 or 6,enemy and 13 or 11,enemy and 4 or 7)end)
    end
   end
  end
  return true
 end
 local picture=State.drawPic
 State.drawPic=function(s,mon,back,...)
  if not active(s) or(back and s.showPlayerTrainer)or(not back and s.showEnemyTrainer)then return picture(s,mon,back,...)end
  local side=back and 'player'or'enemy';local other=s:activeMon(side..'2')
  local args={...};local scale=back and .75 or .625
  local cx=back and (State.PLAYER_PIC_TILE_X+State.PLAYER_PIC_TILES/2)*8
   or(State.ENEMY_PIC_TILE_X+State.ENEMY_PIC_TILES/2)*8
  local bottom=back and(State.PLAYER_PIC_TILE_Y+State.PLAYER_PIC_TILES)*8
   or(State.ENEMY_PIC_TILE_Y+State.ENEMY_PIC_TILES)*8
  if other and(other.hp or 0)>0 then
   transformed(back and 61 or 139,back and 90 or 44,scale,cx,bottom,function()return picture(s,other,back,unpack(args))end)
  end
  return transformed(back and 21 or 100,back and 94 or 39,scale,cx,bottom,function()return picture(s,mon,back,unpack(args))end)
 end
 for _,side in ipairs({'enemy','player'})do
  local name=side=='enemy'and'drawEnemyHud'or'drawPlayerHud';local original=State[name]
  State[name]=function(s,...)
   if not active(s)then return original(s,...)end
   local args={...}
   local function card(slot,index)
    local mon=s:activeMon(slot);if not mon then return end
    -- Each ROM HUD reads its own displayed HP/status identity, even though
    -- the original method's literal slot name is the leading battler.
    local proxy=setmetatable({ballRows={},shownLevel=slot==side and s.shownLevel or mon.level,
     shownExp=slot==side and s.shownExp or(s.expPixels and s:expPixels(mon,mon.level,mon.experience)or 0)}, {__index=s})
    proxy.activeMon=function(_,key)return s:activeMon(key==side and slot or key)end
    proxy.hudHp=function(_,m,key)return s:hudHp(m,key==side and slot or key)end
    proxy.statusTag=function(_,m,key)return s:statusTag(m,key==side and slot or key)end
    local enemy=side=='enemy'
    return transformed(enemy and 2 or 90,enemy and(2+(index-1)*24)or(46+(index-1)*25),
     enemy and .75 or .625,enemy and 8 or 80,enemy and 0 or 56,
     function()return original(proxy,unpack(args))end)
   end
   card(side,1);card(side..'2',2)
  end
 end
end
return M
