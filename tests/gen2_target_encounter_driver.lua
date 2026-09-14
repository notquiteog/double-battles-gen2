return function(game)
 io.stdout:setvbuf("no")
 local U=dofile('/home/admin/Apps/Gen1Recomp/source/tests/drivers/util.lua')
 local Mon=require('src.battle.gen2.Mon')
 local Encounter=require('src.battle.gen2.Encounter')
 local Field=require('src.world.gen2.FieldMoves')
 local w=game.world
 love.window.setMode(2560,1440,{resizable=true})
 game.mods.modOptions.double_battles={wild_doubles='always',gen2_doubles=true}
 game.mods.modOptions.overworld_wild_spawns.random_encounters=true
 w.trySceneScript=function()return false end;w.noWildEncounters=true
 assert(w:setMap('ROUTE_29',12,6,'down'))
 local lead=Mon.new(game.data,'CYNDAQUIL',18);Mon.stampOT(game.save,lead)
 lead.moves={{id='TACKLE',pp=35,maxPp=35}};game.save.party={lead}
 U.wait(160);game.stack:clear()
 local function menu()
  for _=1,1800 do
   local s=game.stack:top()
   if s and s.battle and s.phase=='menu' then return s end
   U.tap(game,'a');U.wait(3)
  end
  error('battle menu unavailable')
 end
 local function finish(s)
  s.battle.tryRun=function(b)b:endBattle('run');return true end
  s:submit({kind='run'})
  for _=1,1800 do
   if not w.battleActive and not (game.stack:top() and game.stack:top().battle) then break end
   U.tap(game,'a');U.wait(3)
  end
  U.wait(10);game.stack:clear()
 end
 for _,kind in ipairs({'spawn','fish'}) do
  local wild=Mon.new(game.data,'SENTRET',20);wild.hp=wild.hp-1;local hp=wild.hp
  assert(w:startBattle({wild=wild,battleType=kind=='fish' and 'fish' or nil}))
  local s=menu()
  assert(not s.battle.doubles and not s.battle.enemy2,'owned encounter doubled')
  assert(s.battle.enemy==wild and wild.hp==hp and wild.level==20,'supplied mon replaced')
  finish(s);print('[ownership]',kind,'PASS')
 end
 local map=w.map;local x,y
 for cy=0,map.def.height*2-1 do
  for cx=0,map.def.width*2-1 do
   local c=map:cellCollision(cx,cy)
   if map:isWalkableCell(cx,cy) and Field.canEncounterWildMon(map.def.environment,c,false)
      and Field.encounterTable(c)=='grass' then x,y=cx,cy;break end
  end
  if x then break end
 end
 assert(x,'no grass fixture');assert(w:setMap('ROUTE_29',x,y,'down'))
 U.wait(60);game.stack:clear()
 local triggers,slot=Encounter.triggers,Encounter.grassSlot
 Encounter.triggers=function()return true end
 Encounter.grassSlot=function()return {species='SENTRET',level=20} end
 w.wildCooldownStep=function()return false end;w.noWildEncounters=false
 print('[fixture] rolling native random',x,y);assert(w:tryWildEncounter(),'native random blocked');print('[fixture] rolled');w.noWildEncounters=true
 Encounter.triggers,Encounter.grassSlot=triggers,slot
 local s=menu();local b=s.battle;assert(b.enemy2,'native random did not double')
 local a,z=b.enemy,b.enemy2;b.random=function(n)return n>1 and 1 or 0 end
 local hp1,hp2,pp=a.hp,z.hp,lead.moves[1].pp
 s:chooseMenu('fight');s:chooseMove(1)
 assert(s.phase=='db2_target' and a.hp==hp1 and z.hp==hp2 and lead.moves[1].pp==pp)
 U.tap(game,'right');U.wait(2);assert(s.doubleTargetSlot=='enemy2')
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/target_second.png'))
 U.tap(game,'b');U.wait(2);assert(s.phase=='moves' and lead.moves[1].pp==pp)
 s:chooseMove(1);U.tap(game,'right');U.wait(2);U.tap(game,'a');U.wait(2)
 assert(z.hp<hp2 and a.hp==hp1,'second target not honored')
 s=menu();hp1,hp2=a.hp,z.hp
 s:chooseMenu('fight');s:chooseMove(1);assert(s.phase=='db2_target')
 U.tap(game,'a');U.wait(2);assert(a.hp<hp1 and z.hp==hp2,'first target not honored')
 s=menu();finish(s)
 print('[target input] PASS: native move menu, cancel without PP, damage to either selected opponent')
 assert(w:startBattle({wild=Mon.new(game.data,'SENTRET',20)}));s=menu()
 assert(not s.battle.enemy2,'origin leaked into next spawn');finish(s)
 print('[ownership] PASS: native scope cleared before next spawn')
 love.event.quit()
end
