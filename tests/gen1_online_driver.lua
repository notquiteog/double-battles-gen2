-- Native Gen1 double battle over two local ENet endpoints. Run from the
-- engine with a disposable *-qa identity and ONLINE_MOD_DIR set to the
-- Online checkout. Choices are scripted; native turn presentation is real.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile('tests/drivers/util.lua')
 local Pokemon=require('src.pokemon.Pokemon');local Wire=require('src.link.Protocol')
 local Link=require('src.link.LinkBattle');local provider=assert(game.mods.exports.double_battles.online)
 local data=game.data
 local function mon(species,moves)
  local m=Pokemon.new(data,species,35,function(a,b)return b and a or 1 end)
  m.moves={};for _,id in ipairs(moves)do m.moves[#m.moves+1]={id=id,pp=30,maxPP=30}end
  return m
 end
 local parties={{mon('RATTATA',{'TACKLE','TAIL_WHIP'}),mon('PIKACHU',{'THUNDERSHOCK','GROWL'}),mon('SANDSHREW',{'SCRATCH','SAND_ATTACK'})},
  {mon('PIDGEY',{'GUST','SAND_ATTACK'}),mon('NIDORAN_M',{'TACKLE','LEER'}),mon('RATTATA',{'TACKLE','TAIL_WHIP'})}}
 game.save.party=parties[1]
 local Net=require('src.link.Net');local hn,gn=Net.new(),Net.new()
 local port=tonumber(os.getenv('QA_LINK_PORT')) or 27863
 assert(hn:host(port),hn.error);assert(gn:join('127.0.0.1:'..port),gn.error)
 for _=1,180 do hn:update();gn:update();if hn.paired and gn.paired then break end;U.wait(1)end
 assert(hn.paired and gn.paired,'local ENet pair failed');hn:poll();gn:poll()
 local transport=dofile(assert(os.getenv('ONLINE_MOD_DIR'))..'/lib/crossgen/double_link.lua').transport
 local attach=dofile(assert(os.getenv('ONLINE_MOD_DIR'))..'/lib/crossgen/double_link1.lua').attach
 local hp,gp=transport(hn),transport(gn)
 local function peerGame(party)
  local save={};for k,v in pairs(game.save)do save[k]=v end;save.party=party
  local g=setmetatable({save=save},{__index=game});local b
  g.input={wasPressed=function(_,key)return b and b.phase=='messages' and key=='a'end,isDown=function(_,key)return key=='a'end}
  g.stack=setmetatable({states={}},{__index=require('src.core.StateStack')})
  return g,function(v)b=v;g.stack.states={v}end
 end
 local hg,hset=peerGame(parties[1]);local gg,gset=peerGame(parties[2])
 local h=assert(Link.newHost(hg,hp,{myParty=Wire.packParty(parties[1]),theirParty=Wire.packParty(parties[2]),seed=112233,verdict='full',keepNetOpen=true}))
 local g=assert(Link.newGuest(gg,gp,{myParty=Wire.packParty(parties[2]),theirParty=Wire.packParty(parties[1]),seed=112233,verdict='full',keepNetOpen=true}))
 local apis={};local observed={attach=function(b)local a,e=provider.attach(b);apis[b]=a;return a,e end}
 hset(h);gset(g);assert(attach(h,hp,observed,true));assert(attach(g,gp,observed,false))
 local original=h.player.mon;local twin=assert(Wire.unpackMon(data,Wire.packMon(original)))
 h.playerParty[#h.playerParty+1]=twin
 local beforeSlot=apis[h].signature(true);h.player.mon=twin
 assert(apis[h].signature(true)~=beforeSlot,'identical-species active slot is not hashed')
 h.player.mon=original;h.playerParty[#h.playerParty]=nil
 local beforeTransform=apis[h].signature(true);local oldMoves=h.player.curMoves
 h.player.curMoves={{id='TRANSFORM',pp=5}}
 assert(apis[h].signature(true)~=beforeTransform,'transformed moves are not hashed')
 h.player.curMoves=oldMoves
 assert(apis[h].signature(true)==apis[g].signature(false),'initial mirrored state differs')
 -- Start at the native command menu; every subsequent text/animation/drain
 -- and end-of-turn is driven by the actual update loop on both endpoints.
 h.queue={};g.queue={};h.phase='menu';g.phase='menu'
 local function submit(b,turn)
  local rows={}
  for i,k in ipairs({'player','player2'})do
   local v=b[k];rows[i]={user=v,action=v.curMoves[turn%#v.curMoves+1],target=b[turn%2==0 and 'enemy' or 'enemy2']}
  end
  if turn==2 and b==h then rows[1].action={dbSwitch=b.playerParty[3]}end
  b:__dbSubmit(rows[1],rows[2])
 end
 local before={};for _,p in ipairs(parties)do for _,m in ipairs(p)do before[#before+1]=m.hp end end
 local sent={0,0}
 for frame=1,24000 do
  -- Game:step services linkNet even while the battle-exit overlay is on top.
  hn:update();gn:update()
  for i,b in ipairs({h,g})do
   local state=b.doubleRoom
   assert(not state.failed,'link failed on '..b.linkRole..' turn '..state.turn)
   if not b.result and b.phase=='menu' and sent[i]<state.turn then sent[i]=state.turn;submit(b,state.turn)end
   -- Unequal frame rates exercise hash waits during native animations.
   if i==1 or frame%3~=0 then local top=b.game.stack:top();if top and top.update then top:update(1/60)end end
  end
  if h.linkEnded and g.linkEnded then break end
  if frame%120==0 then U.wait(1)end
  if frame==24000 then for _,b in ipairs({h,g})do local st=b.doubleRoom;print('[stall]',b.linkRole,b.phase,'result',b.result,'after',b.afterQueue,'queue',#b.queue,'current',b.current and b.current.text,'waitingUI',b.waitingUI,'anim',b.animPlaying,'drain',b.draining,'waitFrames',b.waitFrames,'verified',st.verified,'resolving',st.resolving,'menu',st.menuPending,'finish',st.finishPending,'stack',b.game.stack:top()==b,'closed',b.net.closed)end end
  assert(frame<24000,'link stalled '..h.phase..'/'..g.phase..' turns '..h.doubleRoom.turn..'/'..g.doubleRoom.turn)
 end
 assert(h.linkEnded and g.linkEnded,'battle did not finish')
 assert(h.result=='win' and g.result=='lose' or h.result=='lose' and g.result=='win' or h.result=='draw' and g.result=='draw')
 assert(h.doubleRoom.verified==h.doubleRoom.turn-1 and g.doubleRoom.verified==g.doubleRoom.turn-1,'final hashes not confirmed')
 local n=0;for _,p in ipairs(parties)do for _,m in ipairs(p)do n=n+1;assert(m.hp==before[n],'save party mutated')end end
 assert(not hn.closed and not gn.closed,'room closed with battle')
 hn:send{type='qa_chat',text='still connected'};local delivered=false
 for _=1,120 do hn:update();gn:update();for _,msg in ipairs(gn:poll())do if msg.type=='qa_chat'then delivered=true end end;if delivered then break end;U.wait(1)end
 assert(delivered,'post-battle room traffic failed');hn:close();gn:close()
 print('[Gen1 online doubles] PASS',h.doubleRoom.verified,'turns, native animations, uneven clocks, ENet, targets, switch/faints, final hashes, party integrity, retained transport',h.result,g.result)
 love.event.quit()
end
