-- Compact doubles presentation on the native battle panel. Input, message
-- timing, damage animation and party/bag screens remain engine-owned.
local M={}
local font
local allBattles
local fonts={}
local function text(value)
 return tostring(value or ''):gsub('<PK><MN>','POKEMON'):gsub('<LV>','Lv.')
  :gsub('<[^>]+>',''):gsub('[\r\n\v]',' ')
end
local function label(value,x,y,width,color)
 local G=love.graphics
 local s=text(value)
 if width then while #s>0 and font:getWidth(s)>width do s=s:sub(1,-2) end end
 G.setColor(unpack(color or {.13,.19,.22,1}));G.print(s,x,y)
end
local function panel(x,y,w,h,selected)
 local G=love.graphics
 G.setColor(.06,.10,.12,.22);G.rectangle('fill',x+.5,y+1,w,h,2,2)
 G.setColor(selected and .14 or .88,selected and .39 or .92,selected and .34 or .90,1)
 G.rectangle('fill',x,y,w,h,2,2)
 G.setColor(.28,.42,.40,1);G.setLineWidth(.4);G.rectangle('line',x,y,w,h,2,2)
end
local function guard(fn)
 local G=love.graphics
 G.push('all');G.setShader();G.setScissor()
 -- Use the full window for modern HUD placement, independently of the
 -- centered 160x144 handheld panel. Cap physical card/text size on desktops.
 local width,height=G.getDimensions()
 local scale=math.max(1,math.min(4,width/320,height/240))
 local dpi=math.ceil(scale)
 G.origin();G.scale(scale,scale)
 M.layout={width=width/scale,height=height/scale,scale=scale}
 if not fonts[dpi] then fonts[dpi]=G.newFont(7,'normal',dpi) end
 font=fonts[dpi];G.setFont(font)
 local ok,err=pcall(fn)
 G.pop()
 if not ok then error(err,0) end
end
function M.active(s)
 return s.battle and (s.battle.doubles or (allBattles and allBattles())) and not s.tutorial
end
local function card(s,slot,x,y,ally)
 local mon=s:activeMon(slot)
 if not mon then return end
 local hp=math.max(0,s:hudHp(mon,slot))
 local maximum=mon.maxHp or (mon.stats and mon.stats.hp) or 1
 local fraction=math.min(1,hp/math.max(1,maximum))
 panel(x,y,76,ally and 26 or 22,s.phase=='db2_target' and s.doubleTargetSlot==slot)
 label(s:name(mon),x+3,y+2,49)
 label('Lv.'..tostring(mon.level or 1),x+53,y+2,21)
 local status=s:statusTag(mon,slot)
 label(status or (ally and 'HP' or (s.battle.trainer and 'FOE' or 'WILD')),x+3,y+11,20)
 local G=love.graphics
 G.setColor(.20,.27,.29,1);G.rectangle('fill',x+24,y+12,48,3,1,1)
 if fraction>.5 then G.setColor(.20,.66,.46,1)
 elseif fraction>.2 then G.setColor(.93,.65,.23,1)
 else G.setColor(.87,.29,.28,1) end
 G.rectangle('fill',x+24,y+12,48*fraction,3,1,1)
 if ally then label(('%d / %d'):format(hp,maximum),x+24,y+16,48) end
end
function M.drawSide(s,side)
 guard(function()
  if not s:statusHUDVisible() or not s[side=='enemy' and 'showEnemyHud' or 'showPlayerHud']
     or s:hudCleared(side) then return end
  if side=='enemy' then
   card(s,'enemy',6,6,false)
   if s.battle.enemy2 then card(s,'enemy2',6,31,false) end
  else
   card(s,'player',M.layout.width-82,M.layout.height-(s.battle.player2 and 106 or 78),true)
   if s.battle.player2 then card(s,'player2',M.layout.width-82,M.layout.height-78,true) end
  end
 end)
end
function M.drawBottom(s)
 local phase=s.phase
 if phase~='menu' and phase~='moves' and phase~='resolving' and phase~='db2_target' then return false end
 if not s:bottomUIVisible() then return true end
 guard(function()
  love.graphics.translate((M.layout.width-160)/2,M.layout.height-148)
  panel(2,100,156,42)
  if phase=='menu' then
   for i,name in ipairs(s:menuLabels()) do
    local x=5+((i-1)%2)*77;local y=103+math.floor((i-1)/2)*18
    local selected=s.menuIndex==i
    panel(x,y,73,15,selected)
    -- Use the engine's labels/order so controller selection stays identical.
    label(name,x+5,y+3,64,selected and {1,1,1,1} or nil)
   end
  elseif phase=='db2_target' then
   label('CHOOSE TARGET   A: Confirm   B: Back',7,102,146)
   for i,slot in ipairs(s:doubleTargets()) do
    local mon=s:activeMon(slot)
    local x=5+(i-1)*77
    local selected=s.doubleTargetSlot==slot
    panel(x,114,73,24,selected)
    local color=selected and {1,1,1,1} or nil
    label(tostring(i)..': '..s:name(mon),x+3,116,67,color)
    label('Lv.'..tostring(mon.level or 1)..'  HP '..tostring(s:hudHp(mon,slot)),x+3,127,67,color)
   end
  elseif phase=='moves' then
   for i,move in ipairs(s:playerMoves()) do
    local def=s.game.data.moves[move.id] or {}
    local y=102+(i-1)*9.5
    local selected=s.moveIndex==i
    if selected then
     love.graphics.setColor(.14,.39,.34,1);love.graphics.rectangle('fill',5,y,150,9,1,1)
    end
    local color=selected and {1,1,1,1} or nil
    label((s.moveSwapIndex==i and '> ' or '')..(def.name or move.id),8,y+.5,83,color)
    label(tostring(def.type or '')..'  '..tostring(move.pp or 0)..' PP',94,y+.5,59,color)
   end
  else
   s:syncTyper()
   for i,line in ipairs(s:messageLines()) do
    if i>2 then break end
    label(line,8,107+(i-1)*12,140)
   end
   if s:messageArrowVisible() then label('v',147,130,7) end
  end
 end)
 return true
end
function M.install(State, enabled)
 allBattles=enabled
 if State.modernDoublesHudInstalled then return end
 State.modernDoublesHudInstalled=true
 State.usesModernDoublesHud=function(s)return M.active(s) end
 for _,side in ipairs({'enemy','player'}) do
  local name=side=='enemy' and 'drawEnemyHud' or 'drawPlayerHud'
  local old=State[name]
  State[name]=function(s,...)
   if M.active(s) then
    if not s.modernHudDeferred then return M.drawSide(s,side) end
    return
   end
   return old(s,...)
  end
 end
 local old=State.drawBottom
 State.drawBottom=function(s,...)
  if M.active(s) and s.modernHudDeferred then return end
  if M.active(s) and M.drawBottom(s) then return end
  return old(s,...)
 end
 -- Animation BG effects bake the panel into 160x144 before enlarging it.
 -- Keep window-space HUD out of that bake, then composite it once after FX.
 local body=State.drawSceneBody
 if body then
  State.drawSceneBody=function(s,...)
   if not M.active(s) then return body(s,...) end
   local previous=s.modernHudDeferred
   s.modernHudDeferred=true
   local ok,result=pcall(body,s,...)
   s.modernHudDeferred=previous
   if not ok then error(result,0) end
   if not previous then
    s:drawEnemyHud();s:drawPlayerHud();s:drawBottom(0)
   end
   return result
  end
 end
end
return M
