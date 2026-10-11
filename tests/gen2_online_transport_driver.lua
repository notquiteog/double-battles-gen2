-- Complete native Gen2 Surf doubles through actual ENet and Online's adapter.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile('tests/drivers/util.lua');require('src.render.Pipelines').setLevel('voxel',0)
 local Mon=require('src.battle.gen2.Mon');local H=require('src.link.Handshake');local Link=require('src.link.LinkBattle2');local Wire=require('src.link.Protocol')
 local provider=assert(game.mods.exports.double_battles.online)
 local function party()local p={};for i=1,3 do p[i]=Mon.new(game.data,'PSYDUCK',35);p[i].moves={{id='SURF',pp=15,maxPp=15}}end;return p end
 local parties={party(),party()};local packed={Wire.packParty2(parties[1]),Wire.packParty2(parties[2])}
 local hello=H.hello(game,'battle');local verdict=H.checkCompat(hello,hello)
 local Net=require('src.link.Net');local hn,gn=Net.new(),Net.new();local port=tonumber(os.getenv('QA_LINK_PORT'))or 27865
 assert(hn:host(port),hn.error);assert(gn:join('127.0.0.1:'..port),gn.error)
 for _=1,180 do hn:update();gn:update();if hn.paired and gn.paired then break end;U.wait(1)end
 assert(hn.paired and gn.paired);hn:poll();gn:poll()
 local D=dofile(assert(os.getenv('ONLINE_MOD_DIR'))..'/lib/crossgen/double_link.lua')
 local hp,gp=D.transport(hn),D.transport(gn)
 local function peer(p)
  local save={};for k,v in pairs(game.save)do save[k]=v end;save.party=p
  local b;local g=setmetatable({save=save},{__index=game})
  g.input={wasPressed=function(_,key)return key=='a' and b and b.phase~='menu'and b.phase~='moves'end,isDown=function(_,key)return key=='a'end}
  g.stack=setmetatable({states={}},{__index=require('src.core.StateStack')})
  return g,function(v)b=v;g.stack.states={v}end
 end
 local hg,hs=peer(parties[1]);local gg,gs=peer(parties[2])
 local h=assert(Link.newHost(hg,hp,{myParty=packed[1],theirParty=packed[2],seed=177,theirName='QA',verdict=verdict,strict=H.strict(verdict),keepNetOpen=true}))
 local g=assert(Link.newGuest(gg,gp,{myParty=packed[2],theirParty=packed[1],seed=177,theirName='QA',verdict=verdict,strict=H.strict(verdict),keepNetOpen=true}))
 hs(h);gs(g);assert(D.attach(h,hp,provider,true));assert(D.attach(g,gp,provider,false))
 game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('OverworldBattle').setting:sync(false)
 game.mods.modOptions.MODERN_POKEMON_UI={modernBattleUI=false}
 local original={};for i,p in ipairs(parties)do original[i]=Wire.packParty2(p)end
 for frame=1,30000 do
  hn:update();gn:update()
  for i,b in ipairs({h,g})do
   assert(not b.doubleRoom.failed,'double link failed')
   if not b.battle.over and (b.phase=='menu'or b.phase=='moves')and not b.doubleRoom.mine then
    b.link.submit(b,{kind='move',move='SURF',target='enemy'})
   end
   if i==1 or frame%3~=0 then local top=b.game.stack:top();if top and top.update then top:update(1/60)end end
  end
  if h.result and g.result then break end
  if frame%120==0 then U.wait(1)end
  if frame==30000 then print('STALL',h.phase,g.phase,h.doubleRoom.turn,g.doubleRoom.turn,h.battle.over,g.battle.over)end
  assert(frame<30000,'battle stalled')
 end
 assert(h.doubleRoom.verified==h.doubleRoom.turn-1 and g.doubleRoom.verified==g.doubleRoom.turn-1,'unverified final turn')
 assert(h.result=='win'and g.result=='lose'or h.result=='lose'and g.result=='win'or h.result=='draw'and g.result=='draw')
 local function equal(a,b)
  assert(type(a)==type(b),'source party type changed')
  if type(a)~='table'then assert(a==b,'source party changed');return end
  for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'source party key changed')end
 end
 for i,p in ipairs(parties)do equal(Wire.packParty2(p),original[i])end
 assert(not hn.closed and not gn.closed,'persistent room closed')
 hn:send{type='qa_chat',text='after battle'};local delivered=false
 for _=1,120 do hn:update();gn:update();for _,msg in ipairs(gn:poll())do if msg.type=='qa_chat'then delivered=true end end;if delivered then break end;U.wait(1)end
 assert(delivered);hn:close();gn:close()
 print('[PASS Gen2 native ENet spread battle]',require('src.core.GameVersion').get(),h.doubleRoom.verified,h.result,g.result)
 love.event.quit()
end
