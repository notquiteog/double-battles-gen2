return function(game)
 io.stdout:setvbuf('no')
 local U=dofile('tests/drivers/util.lua')
 require('src.render.Pipelines').setLevel('voxel',0)
 local Mon=require('src.battle.gen2.Mon');local H=require('src.link.Handshake');local L=require('src.link.LinkBattle2');local P=require('src.link.Protocol')
 local provider=assert(game.mods.exports.double_battles.online)
 local function party(species,level)local p={};for i=1,3 do p[i]=Mon.new(game.data,species,level);p[i].moves={{id='SURF',pp=15,maxPp=15}}end;return P.packParty2(p)end
 local p,e=party('PSYDUCK',35),party('PSYDUCK',35)
 local hello=H.hello(game,'battle');local verdict=H.checkCompat(hello,hello)
 local function screen(host)
  local net={send=function()end,update=function()end,poll=function()return{}end,close=function()end}
  return assert((host and L.newHost or L.newGuest)(game,net,{myParty=host and p or e,theirParty=host and e or p,seed=177,theirName='QA',verdict=verdict,strict=H.strict(verdict),keepNetOpen=true}))
 end
 local a,b=screen(true),screen(false);local x,y=assert(provider.attach(a)),assert(provider.attach(b))
 local function picks(api)
  local p={false,false};for _,i in ipairs(api.slots())do p[i]={kind='move',move=1,target=1}end;return p
 end
 for turn=1,40 do
  local pa,pb=picks(x),picks(y);assert(x.resolve(pa,pb));assert(y.resolve(pb,pa))
  local sa,sb=x.signature(true),y.signature(false)
  if sa~=sb then print('HOST',sa);print('GUEST',sb);error('hash mismatch '..turn)end
  print('[double spread] turn',turn,a.battle.over,b.battle.over);U.wait(1)
  if a.battle.over then break end
 end
 assert(a.battle.over and b.battle.over,'battle did not finish')
 print('[double spread] PASS native Surf, canonical mirrored targets, damage, bench replacement and completion')
 love.event.quit()
end
