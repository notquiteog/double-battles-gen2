-- Bind native queued scripts to the two actors that generated their event.
-- Native runners, sound hooks, timers and gameplay remain unchanged.
local M={}
local function pack(...)return{n=select('#',...),...}end
local function active(s)return s.battle and s.battle.doubles and not s.tutorial end
local slots={player=true,player2=true,enemy=true,enemy2=true}
local function valid(s,a)
 if not(active(s)and type(a)=='table'and slots[a.player]and slots[a.enemy]
  and a.player~=a.enemy and a.playerMon and a.enemyMon)then return false end
 return s:activeMon(a.player)==a.playerMon and s:activeMon(a.enemy)==a.enemyMon
end
function M.install(State,View)
 if State.nativeMoveSlotsInstalled then return end
 State.nativeMoveSlotsInstalled=true
 local current=setmetatable({},{__mode='k'})
 local runners=setmetatable({},{__mode='k'})
 local pending=setmetatable({},{__mode='k'})
 local views=setmetatable({},{__mode='k'})
 local function checked(s,a)
  local ok,result=pcall(valid,s,a);return ok and result and a or nil
 end
 function State:nativeAnimationActors()
  local record=self.anim and runners[self.anim]
  if not record or self.afterSendOut or self.battle~=record.screen.battle then return end
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
   runners[s.anim]=a and{screen=s,actors=a}or nil
   if a and s.animView then views[s.animView]=s end
  end
  return unpack(result,1,result.n)
 end
 local advance=State.advanceQueue
 State.advanceQueue=function(s,...)
  local event=s.queue and s.queue[1]
  local old=current[s];current[s]=checked(s,event and event.nativeAnimationActors)
  local result=pack(pcall(advance,s,...))
  if s.pendingAfterAnim and s.anim then
   local record=runners[s.anim];pending[s.pendingAfterAnim]=record and record.actors or nil
  end
  current[s]=old
  if not result[1]then error(result[2],0)end
  return unpack(result,2,result.n)
 end
 local follow=State.startPendingAfterAnim
 State.startPendingAfterAnim=function(s,...)
  local old=current[s];current[s]=checked(s,pending[s.pendingAfterAnim])
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
