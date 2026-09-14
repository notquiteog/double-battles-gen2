-- Local two-peer simulation; this is not an Internet multiplayer playtest.
return function(game)
 local U=dofile('/home/admin/Apps/Gen1Recomp/source/tests/drivers/util.lua')
 local Mon=require('src.battle.gen2.Mon')
 local Engine=dofile('/home/admin/Projects/gen1online-plus/pvp/engine.lua')
 local Session=dofile('/home/admin/Projects/gen1online-plus/pvp/session.lua')
 local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
 end
 game.mods.modOptions.double_battles={wild_doubles='always',trainer_doubles=true,gen2_doubles=true}
 local a=Mon.new(game.data,'SENTRET',20);local b=Mon.new(game.data,'RATTATA',20)
 a.moves={{id='TACKLE',pp=35,maxPp=35}};b.moves={{id='TACKLE',pp=35,maxPp=35}}
 local ap,bp={a,copy(a)},{b,copy(b)}
 local function make(role,my,their)
  local save=copy(game.save);save.party=copy(my)
  return Engine.new({gameData=game.data,save=save,myParty=save.party,theirParty=copy(their),seed=731,role=role})
 end
 local host,guest=make('host',ap,bp),make('guest',bp,ap)
 assert(not host.doubles and not guest.doubles,'trainer doubles intercepted multiplayer construction')
 local inboxA,inboxB={},{}
 local function net(inbox,outbox)
  return {send=function(_,m)outbox[#outbox+1]=copy(m)end,update=function()end,
   poll=function()local out={};for i,m in ipairs(inbox)do out[i]=m end;for i=#inbox,1,-1 do inbox[i]=nil end;return out end}
 end
 local hs=Session.new({net=net(inboxA,inboxB),role='host'})
 local gs=Session.new({net=net(inboxB,inboxA),role='guest'})
 host.pvpRemoteAction=function()return hs.theirAction end
 guest.pvpRemoteAction=function()return gs.theirAction end
 local resolves=0
 hs.onResolve=function(action)host:takeTurn(action);resolves=resolves+1 end
 gs.onResolve=function(action)guest:takeTurn(action);resolves=resolves+1 end
 for i=1,3 do
  hs:submitMyAction({kind='move',move='TACKLE'});gs:submitMyAction({kind='move',move='TACKLE'})
  hs:update();gs:update()
  assert(host.player.hp==guest.enemy.hp and host.enemy.hp==guest.player.hp,'mirrored singles HP diverged')
  assert(host.player.moves[1].pp==guest.enemy.moves[1].pp,'mirrored PP diverged')
 end
 assert(resolves==6,'both peers did not resolve every round')
 print('[multiplayer guard] PASS: no auto-doubles; local host/guest sessions resolve 3 mirrored singles rounds')
 print('[multiplayer scope] Doubles protocol and Internet transport are NOT verified/supported by this test')
 love.event.quit()
end
