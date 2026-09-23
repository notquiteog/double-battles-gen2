-- Local paired command collection. The native menu reads battle.player, so
-- bind the selected ally only while choosing. Restore canonical slots before
-- any turn, and keep art/HUD reads on their canonical slot identities.
local M={}
function M.install(State)
 if State.doublesLocalCommands then return end
 State.doublesLocalCommands=true
 local function active(s)
  local b=s.battle;return b and b.doubles and b.doubles.takeTurn and not b.over and not s.link
 end
 local function restore(s)
  local b=s.battle;local d=b and b.doubles
  if d then b.player,b.player2=d.player,d.player2;b.playerIndex=d.index.player;b.stages.player=d.stages.player end
 end
 local function select(s,slot)
  restore(s);s.doubleCommandSlot=slot
  local b=s.battle;local d=b.doubles
  if slot=='player2'then b.player,b.player2=d.player2,d.player;b.playerIndex=d.index.player2;b.stages.player=d.stages.player2 end
  local mon=b.player;local locked=mon and b:lockedInMove(mon)
  s.phase=locked and 'locked-in'or'menu';s.moveIndex=1
 end
 local function installTurn(s)
  local b=s.battle;local d=b.doubles
  if d.localCommandOwner==s then return end
  d.localCommandOwner=s
  local turn=b.takeTurn
  b.takeTurn=function(self,actions)
   if actions and actions.kind then
    local chosen=s.doubleChosen or{};chosen[s.doubleCommandSlot or'player']=actions;actions=chosen
   end
   restore(s);s.doubleChosen=nil;s.doubleCommandSlot=nil
   return turn(self,actions)
  end
 end
 local submit=State.submit
 function State:submit(action)
  if not active(self)or not action or not action.kind then return submit(self,action)end
  installTurn(self)
  local b=self.battle;local d=b.doubles;local slot=self.doubleCommandSlot or'player'
  local chosen=self.doubleChosen or{}
  if action.kind=='switch'then
   local mon=b.party[action.index];local other=slot=='player'and'player2'or'player'
   if mon==d[other]or(chosen[other]and chosen[other].kind=='switch'and chosen[other].index==action.index)then
    self.message="That POKéMON is already selected.";self.messageTimer=45;self.phase='resolving';return
   end
  end
  chosen[slot]=action;self.doubleChosen=chosen
  if slot=='player'and action.kind~='run'and d.player2 and d.player2.hp>0 then select(self,'player2');return end
  restore(self);self.doubleChosen=nil;self.doubleCommandSlot=nil
  return submit(self,chosen)
 end
 local update=State.update
 function State:update(dt)
  if active(self)then
   installTurn(self)
   if self.doubleCommandSlot=='player2'and self.phase=='menu'and self.game.input:wasPressed('b')then
    self.doubleChosen=nil;select(self,'player');return
   end
  elseif self.doubleCommandSlot then restore(self);self.doubleChosen=nil;self.doubleCommandSlot=nil end
  return update(self,dt)
 end
 local activeMon=State.activeMon
 function State:activeMon(side)
  local b=self.battle;local shown=self.shownMon and self.shownMon[side]
  if shown==nil and b and b.doubles and self.doubleCommandSlot then return b.doubles[side]end
  return activeMon(self,side)
 end
 local useItem=State.useItem
 function State:useItem(id)
  if active(self)then
   installTurn(self)
   local b=self.battle;local item=self.game.data.items[id]
   if b.wild and item and item.pocket=='BALL'then
    local remaining={};for _,slot in ipairs({'enemy','enemy2'})do local mon=b.doubles[slot];if mon and mon.hp>0 then remaining[#remaining+1]=slot end end
    if #remaining>1 then
     self.message='Only one wild POKéMON can remain before catching.';self.messageTimer=60;self.phase='resolving';return
    end
    if remaining[1]=='enemy2'then
     local d=b.doubles;d.enemy,d.enemy2=d.enemy2,d.enemy;d.index.enemy,d.index.enemy2=d.index.enemy2,d.index.enemy
     d.stages.enemy,d.stages.enemy2=d.stages.enemy2,d.stages.enemy
     b.enemy,b.enemy2=d.enemy,d.enemy2;b.enemyIndex=d.index.enemy;b.stages.enemy=d.stages.enemy
     if self.shownMon then self.shownMon.enemy,self.shownMon.enemy2=self.shownMon.enemy2,self.shownMon.enemy end
    end
   end
  end
  return useItem(self,id)
 end
 return M
end
return M
