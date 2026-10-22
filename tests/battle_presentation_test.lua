local update = assert(loadfile('lib/battle_presentation.lua'))()
local frames = {0, 0, 0, 0}
local battle = {phase='db_target', turn=7, game={mods={exports={}}}}
local calls=0
local provider = {updateBattlePresentation=function(b,dt)
  assert(b==battle and dt==.1); calls=calls+1
  for i=1,4 do frames[i]=frames[i]+1 end
end}
battle.game.mods.exports.art=provider
battle.game.mods.exports.alias=provider
battle.game.mods.exports.failed={updateBattlePresentation=function()error('unavailable')end}
battle.game.mods.exports.unrelated=true
for _,phase in ipairs({'db_target','db_switch_target'})do
  battle.phase=phase;update(battle,.1)
end
assert(calls==2,'each custom target phase must tick presentation once')
for i=1,4 do assert(frames[i]==2,'both allied and enemy slots must keep animating')end
assert(battle.turn==7,'target prompt must not advance battle logic')
for _,phase in ipairs({'menu','moveSelect','animate','text'})do
  battle.phase=phase;update(battle,.1)
end
assert(calls==2,'native phase already advances presentation')
battle.phase='db_target';battle.game.mods=nil;update(battle,.1)
update(nil,.1)
print('PASS independent target presentation: four slots, no duplicate/native tick, absent/failing providers')
