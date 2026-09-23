-- Optional mechanics provider; native LinkBattle owns validated party clones.
return function(decorate)
 local M={generation=1,protocol=1,supportsDouble=function()return true end}
 function M.attach(b)
  local BS=require('src.battle.BattleState')
  local function alive(v)return v and v.mon and v.mon.hp>0 end
  local function second(p,lead)for _,m in ipairs(p)do if m~=lead and m.hp>0 then return m end end end
  local partner=second(b.enemyParty,b.enemy.mon)
  if not partner or not second(b.playerParty,b.player.mon)then return nil,'Two healthy Pokemon required per trainer.'end
  b.__dbOnline=true;decorate(b.game,b,BS.makeBattler(b.data,partner,false))
  b.awardExp=function()end
  local A={}
  local function party(side)return side=='player'and b.playerParty or b.enemyParty end
  local function key(side,i)return side..(i==2 and '2'or '')end
  function A.encode(a,c)
   local out={false,false}
   for _,e in ipairs({a,c})do
    local i=e.user==b.player2 and 2 or 1;local action=e.action
    if not action then return nil,'Missing move.'end
    if action.dbSwitch then
     for j,m in ipairs(b.playerParty)do if m==action.dbSwitch then out[i]={kind='switch',index=j}end end
    else
     local slot
     for j,m in ipairs(e.user.curMoves)do if m==action or m.id==action.id then slot=j;break end end
     out[i]={kind=action.struggle and 'struggle'or b:lockedAction(e.user) and 'locked'or'move',slot=slot,target=e.target==b.enemy2 and 2 or 1}
    end
   end
   return out
  end
  function A.decode(rows,side)
   if type(rows)~='table'then return nil,'Missing actions.'end
   local out,used={},{};local foes=side=='player'and'enemy'or'player'
   for i=1,2 do
    local user=b[key(side,i)];local w=rows[i];local e={user=user};out[i]=e
    if alive(user)then
     if type(w)~='table'then return nil,'Missing live action.'end
     if w.kind=='switch'then
      local j=w.index;local p=party(side)
      if type(j)~='number'or j%1~=0 or not p[j]or p[j].hp<=0 or used[j]then return nil,'Invalid switch.'end
      for k=1,2 do if b[key(side,k)]and b[key(side,k)].mon==p[j]then return nil,'Already active.'end end
      used[j]=true;e.action={dbSwitch=p[j]}
     else
      local locked=b:lockedAction(user)
      if w.kind=='locked'then e.action=locked
      elseif w.kind=='struggle'then
       local usable=false;for _,mv in ipairs(user.curMoves or {})do if (mv.pp or 0)>0 then usable=true end end
       if not usable then e.action={id='STRUGGLE',pp=1,struggle=true}end
      elseif w.kind=='move'and type(w.slot)=='number'and w.slot%1==0 then
       local mv=user.curMoves[w.slot];if mv and (mv.pp or 0)>0 and not locked then e.action=mv end
      end
      if not e.action or (w.target~=1 and w.target~=2)then return nil,'Invalid move or target.'end
      e.target=b[key(foes,w.target)]
     end
    end
   end
   return out
  end
  function A.resolve(mine,theirs)
   local a,why=A.decode(mine,'player');if not a then return false,why end
   local e,err=A.decode(theirs,'enemy');if not e then return false,err end
   b.__dbSlotA=a[1];b.__dbSlotB=a[2];b.__dbRemote=e;b.__dbResolving=true
   b:resolveTurn(a[1].action);b.__dbResolving=nil;b.__dbRemote=nil;return true
  end
  -- Resolve switches on either side using the same cloned-party operation.
  b.__dbExecuteSwitch=function(self,old,mon)
   local slot
   for _,k in ipairs({'player','player2','enemy','enemy2'})do if self[k]==old then slot=k end end
   if not slot then return end
   local own=slot:sub(1,6)=='player';local nb=BS.makeBattler(self.data,mon,own)
   nb.dbAnchor=old.dbAnchor;self[slot]=nb
   self.__dbReplaced=self.__dbReplaced or {};self.__dbReplaced[old]=nb
   self:syncSides();self:sayNext(nb.name..' entered the battle!')
  end
  b.onFaint=function(self,v)
   if v.faintQueued then return end;v.faintQueued=true
   self:sayNext(v.name..' fainted!')
   require('src.mods.Runtime').emit('battle.fainted',{battle=self,battler=v})
  end
  b.playerMonFainted=function()end;b.enemyMonFainted=function()end
  local ending=b.endOfTurn
  b.endOfTurn=function(self)
   ending(self)
   self:act(function()
    -- Deterministic bench order on both peers, with no AI or save-party writes.
    for _,side in ipairs(self.linkRole=='host'and{'player','enemy'}or{'enemy','player'})do
     for i=1,2 do
      local k=key(side,i)
      if not alive(self[k])then
       local replacement
       for _,m in ipairs(party(side))do
        if m.hp>0 and (not self[side]or self[side].mon~=m)and(not self[side..'2']or self[side..'2'].mon~=m)then replacement=m;break end
       end
       if replacement then
        self[k]=BS.makeBattler(self.data,replacement,side=='player');self[k].dbAnchor=i
       end
      end
     end
    end
    for _,side in ipairs({'player','enemy'})do if not alive(self[side])and alive(self[side..'2'])then self[side],self[side..'2']=self[side..'2'],self[side];self[side].dbAnchor=1 end end
    self:syncSides()
    local mine=alive(self.player)or alive(self.player2);local theirs=alive(self.enemy)or alive(self.enemy2)
    if not mine or not theirs then self.result=mine and 'win'or theirs and'lose'or'draw';self.afterQueue='finish' end
   end)
  end
  function A.signature(host)
   local out={tostring(b.turnCount),tostring(b.rngDraws)}
   local function atom(v)return type(v)=='table'and tostring(v.id or '')or tostring(v)end
   for _,side in ipairs(host and{'player','enemy'}or{'enemy','player'})do
    for _,m in ipairs(party(side))do
     out[#out+1]=table.concat({m.species,m.hp,tostring(m.status)},':')
     for _,mv in ipairs(m.moves or {})do out[#out+1]=tostring(mv.id)..'='..tostring(mv.pp)end
    end
    for i=1,2 do
     local v=b[key(side,i)];out[#out+1]=v and v.mon.species or '-'
     if v then
      for _,k in ipairs({'attack','defense','special','speed','accuracy','evasion'})do out[#out+1]=tostring(v.stages and v.stages[k]or 0)end
      for _,k in ipairs({'confusedTurns','sleepTurns','toxicCounter','substituteHP','charging','mustRecharge','bideTurns','thrashTurns','trappingTurns'})do out[#out+1]=atom(v[k]or 0)end
     end
    end
   end
   return table.concat(out,'|')
  end
  function A.finish(reason)b.result='draw';b.phase='messages';b.afterQueue='finish';b:say(reason or 'Link ended.')end
  return A
 end
 return M
end
