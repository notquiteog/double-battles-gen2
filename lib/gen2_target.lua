-- Collect an opponent before handing the action to the native round adapter.
-- No PP, turn counters or combat state change until the player confirms.
local M={}
function M.targets(battle)
 local out={}
 for _,slot in ipairs({'enemy','enemy2'}) do
  local mon=battle and battle[slot]
  if mon and (mon.hp or 0)>0 then out[#out+1]=slot end
 end
 local d=battle and battle.doubles
 local ally=d and battle.player==d.player2 and 'player' or 'player2'
 local partner=d and d[ally]
 if partner and (partner.hp or 0)>0 then out[#out+1]=ally end
 return out
end
function M.install(State)
 if State.doublesGen2TargetHook then return end
 State.doublesGen2TargetHook=true
 local submit,update=State.submit,State.update
 local drawBottom=State.drawBottom
 if drawBottom then
  function State:drawBottom(ox,...)
   if self.phase~='db2_target' then return drawBottom(self,ox,...)end
   local Chrome=require('src.ui.gen2.Chrome')
   local Palette=require('src.render.GbcPalette')
   local previous=Palette.setBgp(self:exitFadeBgp())
   Chrome.box(0,12,20+(ox or 0),6)
   for i,slot in ipairs(self:doubleTargets())do
    local mon=self.battle.doubles[slot] or self.battle[slot]
    if slot==self.doubleTargetSlot then Chrome.cursorThrough(1,12+i,Chrome.DEFAULT_BOX_PALETTE)end
    local name=self:name(mon)
    Chrome.printThrough((slot:match('^player') and 'ALLY ' or 'FOE ')..name,2,12+i,Chrome.DEFAULT_BOX_PALETTE)
   end
   Chrome.printThrough('A:OK B:BACK',2,16,Chrome.DEFAULT_BOX_PALETTE)
   Palette.setBgp(previous)
  end
 end
 function State:doubleTargets() return M.targets(self.battle) end
 function State:submit(action)
  local b=self.battle
  if b and b.doubles and b.doubles.takeTurn and not b.over and (not self.link or self.doubleLink)
      and action and action.kind=='move' and not action.target then
   local targets=self:doubleTargets()
   if #targets>1 then
    self.doublePendingAction={}
    for k,v in pairs(action) do self.doublePendingAction[k]=v end
    self.doubleTargetReturn=self.phase=='moves' and 'moves' or 'menu'
    self.doubleTargetSlot=targets[1]
    self.doubleTargetFoe=nil
    self.phase='db2_target'
    return
   end
  end
  return submit(self,action)
 end
 function State:confirmDoubleTarget()
  local action=self.doublePendingAction
  if self.phase~='db2_target' or not action then return false end
  local targets=self:doubleTargets()
  local chosen
  for _,slot in ipairs(targets) do if slot==self.doubleTargetSlot then chosen=slot end end
  if not chosen then chosen=targets[1] end
  if not chosen then return false end
  action.target=chosen
  self.doublePendingAction=nil
  self.doubleTargetSlot=nil
  return submit(self,action)
 end
 function State:update(dt)
  if self.phase~='db2_target' then return update(self,dt) end
  self:updateAlarm();self:stepFrontAnim()
  self.arrowBlink=((self.arrowBlink or 0)+1)%32
  local input=self.game and self.game.input
  if not input then return end
  local targets=self:doubleTargets()
  if not targets[1] or not (self.battle.doubles and self.battle.doubles.takeTurn)
      or self.battle.over then
   self.doublePendingAction=nil;self.doubleTargetSlot=nil
   self.phase='menu'
   return
  end
  local index=1
  for i,slot in ipairs(targets) do if slot==self.doubleTargetSlot then index=i end end
  self.doubleTargetSlot=targets[index]
  if input:wasPressed('b') then
   self:playSfx('Sfx_ReadText2')
   self.doublePendingAction=nil;self.doubleTargetSlot=nil
   self.phase=self.doubleTargetReturn or 'moves'
  elseif input:wasPressed('up')then
   for _,slot in ipairs(targets)do if slot==self.doubleTargetFoe then self.doubleTargetSlot=slot;return end end
   self.doubleTargetSlot=targets[1]
  elseif input:wasPressed('down')then
   if self.doubleTargetSlot:match('^enemy')then self.doubleTargetFoe=self.doubleTargetSlot end
   for _,slot in ipairs(targets)do if slot:match('^player')then self.doubleTargetSlot=slot;break end end
  elseif input:wasPressed('left')or input:wasPressed('right')then
   if self.doubleTargetSlot:match('^enemy')then
    for _,slot in ipairs(targets)do if slot:match('^enemy')and slot~=self.doubleTargetSlot then self.doubleTargetSlot=slot;break end end
   end
  elseif input:wasPressed('a') then
   self:playSfx('Sfx_ReadText2');return self:confirmDoubleTarget()
  end
 end
end
return M
