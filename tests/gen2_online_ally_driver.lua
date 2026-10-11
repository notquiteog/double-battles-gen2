return function(game)
 io.stdout:setvbuf('no')
 require('src.render.Pipelines').setLevel('voxel',0)
 local Mon=require('src.battle.gen2.Mon');local H=require('src.link.Handshake');local L=require('src.link.LinkBattle2');local P=require('src.link.Protocol')
 local provider=assert(game.mods.exports.double_battles.online)
 local function party(species,level)local p={};for i=1,3 do p[i]=Mon.new(game.data,species,level);p[i].moves={{id='TACKLE',pp=35,maxPp=35}}end;return P.packParty2(p)end
 local p,e=party('BULBASAUR',50),party('RATTATA',10)
 local hello=H.hello(game,'battle');local verdict=H.checkCompat(hello,hello)
 local function screen(host)
  local net={send=function()end,update=function()end,poll=function()return{}end,close=function()end}
  return assert((host and L.newHost or L.newGuest)(game,net,{myParty=host and p or e,theirParty=host and e or p,seed=177,theirName='QA',verdict=verdict,strict=H.strict(verdict),keepNetOpen=true}))
 end
 local a,b=screen(true),screen(false);local x,y=assert(provider.attach(a)),assert(provider.attach(b))
 local U=dofile('tests/drivers/util.lua')
 love.window.setMode(640,576,{resizable=false})
 game.mods.modOptions.MODERN_POKEMON_UI={modernBattleUI=false}
 game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('OverworldBattle').setting:sync(false)
 game.save.options.battleBg='white'
 a.phase='moves';a.showPlayerTrainer=false;a.showEnemyTrainer=false;a.showEnemyHud=true;a.showPlayerHud=true;a.slideFrame=72
 game.stack.states={a};a:submit({kind='move',move='TACKLE'})
 assert(a.phase=='db2_target')
 for _,step in ipairs({{'right','enemy2'},{'down','player2'},{'left','player2'},{'up','enemy2'}})do
  U.tap(game,step[1]);U.wait(2);assert(a.doubleTargetSlot==step[2],step[1])
 end
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/native-target.png'))
 U.tap(game,'down');U.wait(2)
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/native-ally.png'))
 U.tap(game,'b');U.wait(2);assert(a.phase=='moves')
 game.stack.states={}
 local function picks(api)
  local p={false,false};for _,i in ipairs(api.slots())do p[i]={kind='move',move=1,target=1}end;return p
 end
 for turn=1,10 do
  local pa,pb=picks(x),picks(y);if turn==1 then pa[1].target=4;pa[2].target=3;pb[1].target=4;pb[2].target=3 end;assert(x.resolve(pa,pb));assert(y.resolve(pb,pa))
  local sa,sb=x.signature(true),y.signature(false)
  if sa~=sb then print('HOST',sa);print('GUEST',sb);error('hash mismatch '..turn)end
  print('[double core] turn',turn,a.battle.over,b.battle.over)
  if a.battle.over then break end
 end
 assert(a.battle.over and b.battle.over,'battle did not finish')
 love.event.quit()
 print('[double core] PASS canonical paired turns, damage, bench replacement and completion')
end
