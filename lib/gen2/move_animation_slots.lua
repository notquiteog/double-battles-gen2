-- Bind native queued scripts to the two actors that generated their event.
-- Native runners, sound hooks, timers and gameplay remain unchanged.
local M={}
local function pack(...)return{n=select('#',...),...}end
local function active(s)return s.battle and s.battle.doubles and not s.tutorial end
local slots={player=true,player2=true,enemy=true,enemy2=true}
function M.install(State,View)
 if State.nativeMoveSlotsInstalled then return end
 State.nativeMoveSlotsInstalled=true
 local current=setmetatable({},{__mode='k'})
 local runners=setmetatable({},{__mode='k'})
 local pending=setmetatable({},{__mode='k'})
 local views=setmetatable({},{__mode='k'})
 local origins=setmetatable({},{__mode='k'})
 local function origin(mon)return origins[mon]or mon end
 local function resolve(s,a)
  if not(active(s)and type(a)=='table'and slots[a.player]and slots[a.enemy]
   and a.player~=a.enemy and a.playerMon and a.enemyMon)then return end
  local p,e=s:activeMon(a.player),s:activeMon(a.enemy)
  if not p or not e or origin(p)~=origin(a.playerMon)or origin(e)~=origin(a.enemyMon)then return end
  if p==a.playerMon and e==a.enemyMon then return a end
  return{player=a.player,enemy=a.enemy,playerMon=p,enemyMon=e}
 end
 local function checked(s,a)
  local ok,result=pcall(resolve,s,a);return ok and result or nil
 end
 -- Only the original public queue method establishes display-copy provenance.
 -- Do not infer identity from matching species or inspect a proxy's metatable.
 local push=State.push
 if type(push)=='function'then
  State.push=function(s,event,...)
   local before=s.shownMon and event and s.shownMon[event.side]
   local result=pack(push(s,event,...))
   if active(s)and event and event.mon and(event.kind=='transform'or event.kind=='identity')then
    local shown=s.shownMon and s.shownMon[event.side]
    if type(shown)=='table'and shown~=before and shown~=event.mon then origins[shown]=origin(event.mon)end
   end
   return unpack(result,1,result.n)
  end
 end
 function State:nativeAnimationActors()
  local record=self.anim and runners[self.anim]
  if not record or self.afterSendOut or self~=record.screen or self.battle~=record.battle then return end
  return checked(record.screen,record.actors)
 end
 local function sideFor(s,side)
  local a=current[s]or s:nativeAnimationActors()
  if a then
   if a.player==side then return'player'end
   if a.enemy==side then return'enemy'end
  end
  return side=='player2'and'player'or side=='enemy2'and'enemy'or side
 end
 local turn=State.turnFor
 State.turnFor=function(s,side,...)return turn(s,active(s)and sideFor(s,side)or side,...)end
 local after=State.afterAnimFor
 State.afterAnimFor=function(s,side,...)return after(s,active(s)and sideFor(s,side)or side,...)end
 local start=State.startAnim
 State.startAnim=function(s,key,opts,...)
  local a=checked(s,current[s])
  local receiver=s
  if a then
   -- The original startAnim closure owns cry/flying readers. Give it a
   -- detached public context so the partner, not the lead, supplies them.
   local battle=setmetatable({player=a.playerMon,enemy=a.enemyMon},{__index=s.battle})
   receiver=setmetatable({battle=battle,activeMon=function(_,side)
    return s:activeMon(a[side]or side)
   end},{__index=s,__newindex=s})
  end
  local result=pack(start(receiver,key,opts,...))
  if result[1]and s.anim then
   runners[s.anim]=a and{screen=s,battle=s.battle,actors=a}or nil
   if a and s.animView then views[s.animView]=s end
  end
  return unpack(result,1,result.n)
 end
 local advance=State.advanceQueue
 State.advanceQueue=function(s,...)
  local event=s.queue and s.queue[1]
  local old=current[s];local a=checked(s,event and event.nativeAnimationActors)
  current[s]=a
  local projected
  if a and event.kind=='damage'and(event.side==a.player or event.side==a.enemy)then
   -- The original queue reader only knows player/enemy when it selects a
   -- standalone hit script. Preserve the real target for HP/HUD updates,
   -- but explicitly supply that script and its real source context.
   projected={};for k,v in pairs(event)do projected[k]=v end
   local target=event.side==a.player and'player'or'enemy'
   if projected.animSide==nil then
    projected.animSide=target=='player'and a.enemy or a.player
   end
   if projected.anim==nil and not projected.animMove then
    projected.anim=target=='player'and'ANIM_PLAYER_DAMAGE'or'ANIM_ENEMY_DAMAGE'
   end
   s.queue[1]=projected
  end
  local result=pack(pcall(advance,s,...))
  if projected and s.queue and s.queue[1]==projected then s.queue[1]=event end
  if s.pendingAfterAnim and s.anim then
   pending[s.pendingAfterAnim]=runners[s.anim]
  end
  current[s]=old
  if not result[1]then error(result[2],0)end
  return unpack(result,2,result.n)
 end
 local follow=State.startPendingAfterAnim
 State.startPendingAfterAnim=function(s,...)
  local record=pending[s.pendingAfterAnim]
  local old=current[s];current[s]=record and record.screen==s and record.battle==s.battle and checked(s,record.actors)or nil
  local result=pack(pcall(follow,s,...));current[s]=old
  if not result[1]then error(result[2],0)end
  return unpack(result,2,result.n)
 end
 for _,name in ipairs({'animPicState','hudCleared'})do
  local original=State[name]
  State[name]=function(s,side,...)
   local a=s:nativeAnimationActors()
   if a then
    if side==a.player then side='player'
    elseif side==a.enemy then side='enemy'
    else return nil end
   end
   return original(s,side,...)
  end
 end
 if View and type(View.drawObjects)=='function'then
  local objects=View.drawObjects
  View.drawObjects=function(view,runner,battle,...)
   local s=views[view];local a=s and s.anim==runner and s:nativeAnimationActors()
   if a and battle==s.battle then
    battle=setmetatable({player=a.playerMon,enemy=a.enemyMon},{__index=battle})
   end
   return objects(view,runner,battle,...)
  end
 end
end
return M
