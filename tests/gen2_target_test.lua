local Target=dofile('lib/gen2_target.lua')
local pressed,submitted={},{}
local State={submit=function(self,a) submitted[#submitted+1]=a;self.phase='resolving' end,
 update=function(self) self.nativeUpdates=(self.nativeUpdates or 0)+1 end,
 updateAlarm=function()end,stepFrontAnim=function()end,playSfx=function()end}
Target.install(State)
local s=setmetatable({phase='moves',battle={doubles={takeTurn=true},enemy={hp=20},enemy2={hp=30}},
 game={input={wasPressed=function(_,key)return pressed[key] end}}},{__index=State})
local function press(k)pressed={[k]=true};s:update(1/60);pressed={} end
s:submit({kind='move',move='TACKLE'})
assert(s.phase=='db2_target' and #submitted==0)
press('right');assert(s.doubleTargetSlot=='enemy2');press('b')
assert(s.phase=='moves' and #submitted==0 and not s.doublePendingAction)
s:submit({kind='move',move='TACKLE'});press('right');press('a')
assert(#submitted==1 and submitted[1].target=='enemy2' and s.phase=='resolving')
s.phase='moves';s:submit({kind='move',move='TACKLE'});press('a')
assert(#submitted==2 and submitted[2].target=='enemy')
s.phase='moves';s:submit({kind='move',move='TACKLE'});press('right');s.battle.enemy2.hp=0;press('a')
assert(submitted[3].target=='enemy','stale target must fall back to living foe')
s.phase='moves';s:submit({kind='move',move='TACKLE'});assert(#submitted==4,'one foe skips prompt')
s.battle.enemy2.hp=20;s.phase='menu';s:submit({kind='run'});assert(#submitted==5)
s.phase='moves';s.link={};s:submit({kind='move',move='TACKLE'});assert(#submitted==6,'link owns its input')
print('Gen2 target selection: both slots, cancel, fainted target, singles, run and link PASS')

-- Teammates occupy a separate row; horizontal input never selects self.
s.link=nil;s.battle.enemy2.hp=30
local lead,partner={hp=30},{hp=30}
s.battle.player=lead;s.battle.doubles.player=lead;s.battle.doubles.player2=partner
s.phase='moves';s:submit({kind='move',move='TACKLE'})
press('right');press('down');assert(s.doubleTargetSlot=='player2')
press('left');assert(s.doubleTargetSlot=='player2')
press('up');assert(s.doubleTargetSlot=='enemy2')
press('down');press('a');assert(submitted[#submitted].target=='player2')
s.battle.player=partner;s.phase='moves';s:submit({kind='move',move='TACKLE'})
press('down');assert(s.doubleTargetSlot=='player');press('b')
lead.hp=0;s.phase='moves';s:submit({kind='move',move='TACKLE'})
press('down');assert(s.doubleTargetSlot=='enemy','fainted partner excluded')
print('Gen2 ally row, canonical partner commands and remembered foe PASS')
