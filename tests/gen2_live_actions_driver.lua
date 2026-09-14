-- Disposable imported-Crystal QA only. Exercises the actual battle screen's
-- submit method, with current cart companions and native damage calculation.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 if os.getenv('QA_2K')=='1' then love.window.setMode(2560,1440,{resizable=true});U.wait(20) end
 local V=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 if os.getenv('QA_DEPTH_STYLE')=='1' then assert(V.require('CommunityVisuals').crystalDepth(game.world.map),'HD-2D must be default') end
 local stage=V.require('OverworldBattle')
 local Mon=require('src.battle.gen2.Mon')
 local Doubles=dofile((os.getenv('DOUBLE_MOD_PATH') or 'mods/double_battles')..'/lib/doubles2.lua')
 -- Explicit pair fixture: production mod-owned encounters must stay singles.
 game.mods.events:on('battle.started',function(ev)
  local b=ev and ev.battle
  if b and not b.trainer and not b.doubles then
   local second=Mon.new(game.data,'SENTRET',3)
   b.enemyParty[2]=second;Doubles.decorate(b,nil,second)
  end
 end)
 game.world.trySceneScript=function()return false end
 game.world.rollEncounter=function()return nil end
 game.mods.modOptions.double_battles={wild_doubles='always',gen2_doubles=true}
 assert(game.world:setMap('ROUTE_29',12,6,'down'))
 local lead=Mon.new(game.data,'CYNDAQUIL',18)
 Mon.stampOT(game.save,lead)
 lead.moves={{id='TACKLE',pp=35,maxPp=35}}
 game.save.party={lead}
 U.wait(120)
 -- Sky Ride's restored test scientist must never grant gifts on boot.
 assert(#game.save.party==1 and game.save.party[1]==lead,'unrequested test gift changed the party')
 -- Force a same-species encounter fixture to catch overlapping pair art.
 local Encounter=require('src.battle.gen2.Encounter')
 local roll=Encounter.grassSlot
 Encounter.grassSlot=function()return {species='SENTRET',level=3} end
 assert(game.world:startBattle({wild=Mon.new(game.data,'SENTRET',8)}))
 Encounter.grassSlot=roll
 local screen
 for _=1,1800 do
  screen=game.stack:top()
  if screen and screen.battle and screen.phase=='menu' then break end
  U.tap(game,'a');U.wait(3)
 end
 assert(screen and screen.battle and screen.phase=='menu','battle menu unavailable')
 local b=screen.battle
 assert(b.enemy2,'encounter did not decorate')
 b.random=function(n)return n>1 and 1 or 0 end
 local enemy,partner=b.enemy,b.enemy2
 assert(screen:usesModernDoublesHud(),'modern doubles HUD not installed')
 local staged=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen2Staged')
 U.wait(10)
 assert(staged.drawn.enemy==enemy and staged.drawn.enemy2==partner,'both staged bodies must render')
 assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_menu.png'))
 screen.phase='moves';screen.moveIndex=1
 assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_moves.png'))
 screen.phase='menu'
 local before=enemy.hp
 screen:submit({kind='move',move='TACKLE',target='enemy'})
 assert(enemy.hp<before,'native screen attack was skipped')
 print('[doubles live] native submit damage',before,enemy.hp)
 local animationShot=false
 for _=1,1800 do
  if screen.phase=='menu' then break end
  if os.getenv('QA_TRANSITIONS')=='1' and screen.anim and screen.anim.bg and not animationShot then
   screen.anim.bg.scx=3 -- exercise the native small-canvas scanline path
   U.wait(1)
   assert(not screen.modernHudDeferred,'HUD capture flag leaked out of drawing')
   assert(stage.arena(),'stage vanished during attack')
   assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_animation.png'))
   animationShot=true
  end
  U.tap(game,'a');U.wait(3)
 end
 assert(screen.phase=='menu','first attack did not return to menu')
 enemy.hp=1
 screen:submit({kind='move',move='TACKLE',target='enemy'})
 assert(enemy.hp==0 and b.enemy==partner and b.enemy2==nil,'surviving foe not promoted')
 for _=1,1800 do if screen.phase=='menu' or b.over then break end U.tap(game,'a');U.wait(3) end
 assert(#game.save.party==1 and game.save.party[1]==lead,'battle injected a party member')
 assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_survivor.png'))
 if os.getenv('QA_TRANSITIONS')=='1' then
  assert(animationShot,'attack animation was not sampled')
  for _=1,1800 do if screen.phase=='menu' then break end U.tap(game,'a');U.wait(3) end
  b.enemy.hp=1
  screen:submit({kind='move',move='TACKLE',target='enemy'})
  assert(b.over,'finishing attack did not end battle')
  U.wait(3)
  assert(stage.arena() and stage.battle()==b,'stage released before result messages')
  assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_result.png'))
  for _=1,1800 do
   if not staged.holdsScene(game,b) then break end
   assert(stage.arena(),'stage vanished before native screen exit')
   U.tap(game,'a');U.wait(3)
  end
  U.wait(3);assert(not stage.battle(),'stage retained after overworld return')
  assert(game.world:startBattle({wild=Mon.new(game.data,'SENTRET',3)}))
  for _=1,1800 do
   screen=game.stack:top()
   if screen and screen.battle and screen.phase=='menu' then break end
   U.tap(game,'a');U.wait(3)
  end
  b=screen.battle;b.random=function(n)return n>1 and 1 or 0 end
  for attempt=1,5 do
   screen:submit({kind='run'})
   if b.over then break end
   for _=1,1800 do if screen.phase=='menu' then break end U.tap(game,'a');U.wait(3) end
  end
  assert(b.over,'escape fixture did not finish')
  U.wait(2);assert(stage.arena(),'stage released on escape result')
  assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_escape.png'))
  for _=1,1800 do
   if not staged.holdsScene(game,b) then break end
   assert(stage.arena(),'stage vanished during escape transition')
   U.tap(game,'a');U.wait(3)
  end
  U.wait(3);assert(not stage.battle(),'stage not released after escape')
  print('[doubles transitions] PASS: animation HUD, knockout and escape stage lifetime')
 end
 print('[doubles live] PASS: native attack, survivor promotion, no foreign party or automatic test gifts')
 love.event.quit()
end
