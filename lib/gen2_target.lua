-- Collect an opponent before handing the action to the native round adapter.
-- No PP, turn counters or combat state change until the player confirms.
local M={}
function M.targets(battle)
 local out={}
 for _,slot in ipairs({'enemy','enemy2'}) do
  local mon=battle and battle[slot]
  if mon and (mon.hp or 0)>0 then out[#out+1]=slot end
 end
 return out
end
function M.install(State)
 if State.doublesGen2TargetHook then return end
 State.doublesGen2TargetHook=true
 local submit,update=State.submit,State.update
 function State:doubleTargets() return M.targets(self.battle) end
 function State:submit(action)
  local b=self.battle
  if b and b.doubles and b.doubles.takeTurn and not b.over and not self.link
      and action and action.kind=='move' and not action.target then
   local targets=self:doubleTargets()
   if #targets>1 then
    self.doublePendingAction={}
    for k,v in pairs(action) do self.doublePendingAction[k]=v end
    self.doubleTargetReturn=self.phase=='moves' and 'moves' or 'menu'
    self.doubleTargetSlot=targets[1]
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
  elseif input:wasPressed('left') or input:wasPressed('up') then
   self.doubleTargetSlot=targets[(index-2)%#targets+1]
  elseif input:wasPressed('right') or input:wasPressed('down') then
   self.doubleTargetSlot=targets[index%#targets+1]
  elseif input:wasPressed('a') then
   self:playSfx('Sfx_ReadText2');return self:confirmDoubleTarget()
  end
 end
end
return M
