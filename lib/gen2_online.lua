-- Mechanics-only provider. Online owns consent, transport, compatibility and
-- turn hashes; native LinkBattle2 owns cloned parties and teardown.
return function(Core)
 local M={protocol=1,generation=2,supportsDouble=function()return true end}
 function M.attach(s)
  local b=s.battle
  local function second(party,lead)for _,m in ipairs(party or {})do if m~=lead and not m.isEgg and (m.hp or 0)>0 then return m end end end
  local p,e=second(b.party,b.player),second(b.enemyParty,b.enemy)
  if not p or not e then return nil,'Both trainers need two healthy Pokemon.'end
  Core.decorate(b,p,e);s.doubleLink=true
  local A={selected=1}
  function A.restore()
   if A.selected==2 then b.player,b.player2=b.player2,b.player;b.playerIndex=b.doubles.index.player end
   A.selected=1
  end
  function A.select(index)
   A.restore();if index==2 then b.player,b.player2=b.player2,b.player;b.playerIndex=b.doubles.index.player2;A.selected=2 end
  end
  function A.slots()
   local out={};for i,key in ipairs({'player','player2'})do local m=b.doubles[key];if m and (m.hp or 0)>0 then out[#out+1]=i end end;return out
  end
  local function mon(side,index)return b.doubles[side..(index==2 and '2'or '')]end
  function A.encode(action,index)
   local m=mon('player',index)
   if action.kind=='switch'then return {kind='switch',index=action.index}end
   if action.kind~='move'then return nil,'No items or running in link battles.'end
   for i,move in ipairs(m.moves or {})do if move.id==action.move then return {kind='move',move=i,target=action.target=='enemy2'and 2 or 1}end end
   if action.move=='STRUGGLE'then return {kind='struggle',target=action.target=='enemy2'and 2 or 1}end
   return nil,'Choose a known move.'
  end
  function A.decode(rows,side)
   if type(rows)~='table'then return nil,'Missing paired actions.'end
   local out,used={},{}
   local party=side=='player'and b.party or b.enemyParty
   for i=1,2 do
    local m=mon(side,i);local w=rows[i];local key=side..(i==2 and '2'or '')
    if m and (m.hp or 0)>0 then
     if type(w)~='table'then return nil,'Missing live battler action.'end
     if w.kind=='switch'then
      local n=w.index
      if type(n)~='number'or n%1~=0 or not party[n]or party[n].hp<=0 or party[n].isEgg or party[n]==mon(side,1)or party[n]==mon(side,2)or used[n]then return nil,'Invalid switch.'end
      used[n]=true;out[key]={kind='switch',index=n}
     elseif w.kind=='move'or w.kind=='struggle'then
      local move=w.kind=='move'and type(w.move)=='number'and w.move%1==0 and m.moves[w.move]
      local locked=move and (b:forcedMove(m)==move.id or b:lockedInMove(m)==move.id or b:volatile(m).chargeMove==move.id)
      if w.kind=='move'and (not move or ((move.pp or 0)<=0 and not locked))then return nil,'Invalid move slot.'end
      if w.kind=='struggle'and b:hasUsableMoves(m)then return nil,'Struggle is unavailable.'end
      if w.target~=1 and w.target~=2 then return nil,'Invalid target.'end
      out[key]={kind='move',move=move and move.id or 'STRUGGLE',target=(side=='player'and'enemy'or'player')..(w.target==2 and'2'or'')}
     else return nil,'Invalid action kind.'end
    end
   end
   return out
  end
  function A.resolve(mine,theirs)
   A.restore()
   local a,why=A.decode(mine,'player');if not a then return false,why end
   local other,err=A.decode(theirs,'enemy');if not other then return false,err end
   for k,v in pairs(other)do a[k]=v end
   local events=b:takeTurn(a);s.phase='resolving';s:pushAll(events);s.message=nil;s.messageTimer=0;s:advanceQueue();return true
  end
  function A.signature(host)
   A.restore()
   b.rngDraws=s.rngOwner and s.rngOwner.rngDraws or b.rngDraws
   local role=host and 'host'or'guest'
   local out={tostring(b.turn or 0)}
   local leadP,leadE,pi,ei=b.player,b.enemy,b.playerIndex,b.enemyIndex
   local ps,es=b.stages.player,b.stages.enemy
   for i=1,2 do
    local pk,ek=i==1 and 'player'or'player2',i==1 and 'enemy'or'enemy2'
    b.player,b.enemy=b.doubles[pk],b.doubles[ek]
    b.playerIndex,b.enemyIndex=b.doubles.index[pk],b.doubles.index[ek]
    b.stages.player,b.stages.enemy=b.stages[pk],b.stages[ek]
    local raw=b:linkSignature(role)
    raw.volatile=raw.volatile:gsub('futureSightSide=([%w]+)',function(side)return 'futureSightSide='..((side=='player')==host and 'host'or'guest')end)
    for _,key in ipairs({'actives','volatile','bench'})do out[#out+1]=raw[key]end
    out[#out+1]=tostring(host and b.playerIndex or b.enemyIndex)
    out[#out+1]=tostring(host and b.enemyIndex or b.playerIndex)
   end
   b.player,b.enemy,b.playerIndex,b.enemyIndex=leadP,leadE,pi,ei
   b.stages.player,b.stages.enemy=ps,es
   return table.concat(out,'\n')
  end
  function A.finish(reason)
   A.restore();b:endBattle('draw');s.result='draw';s.phase='resolving';s:pushAll(b:takeEvents());s:advanceQueue()
  end
  return A
 end
 return M
end
