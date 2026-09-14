-- Disposable imported-Crystal QA only. Exercises the actual battle screen's
-- submit method, with current cart companions and native damage calculation.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 if os.getenv('QA_2K')=='1' then love.window.setMode(2560,1440,{resizable=true});U.wait(20) end
 local Mon=require('src.battle.gen2.Mon')
 game.world.trySceneScript=function()return false end
 game.world.rollEncounter=function()return nil end
 game.mods.modOptions.double_battles={wild_doubles='always',gen2_doubles=true}
 assert(game.world:setMap('ROUTE_29',12,6,'down'))
 local lead=Mon.new(game.data,'CYNDAQUIL',18)
 Mon.stampOT(game.save,lead)
 lead.moves={{id='TACKLE',pp=35,maxPp=35}}
 game.save.party={lead}
 U.wait(120)
 -- The release must not install a development gift giver on any boot.
 for _,obj in ipairs(game.world.maps.NEW_BARK_TOWN.objects or {}) do
  assert(obj.name~='DSR_GEN2_TEST_GIVER','test gift NPC shipped')
 end
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
 screen:submit({kind='move',move='TACKLE'})
 assert(enemy.hp<before,'native screen attack was skipped')
 print('[doubles live] native submit damage',before,enemy.hp)
 for _=1,1800 do if screen.phase=='menu' then break end U.tap(game,'a');U.wait(3) end
 assert(screen.phase=='menu','first attack did not return to menu')
 enemy.hp=1
 screen:submit({kind='move',move='TACKLE'})
 assert(enemy.hp==0 and b.enemy==partner and b.enemy2==nil,'surviving foe not promoted')
 for _=1,1800 do if screen.phase=='menu' or b.over then break end U.tap(game,'a');U.wait(3) end
 assert(#game.save.party==1 and game.save.party[1]==lead,'battle injected a party member')
 assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/doubles_survivor.png'))
 print('[doubles live] PASS: native attack, survivor promotion, no foreign party; no test giver')
 love.event.quit()
end
