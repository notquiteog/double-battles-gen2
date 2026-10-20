local mons={player={},player2={},enemy={},enemy2={}}
local S={}
function S:activeMon(slot)return self.shownMon and self.shownMon[slot]or mons[slot]end
function S:push(ev)
 if ev.kind=='transform'and self.shownMon[ev.side]==ev.mon or ev.kind=='identity'then
  self.shownMon[ev.side]=setmetatable({species=ev.from or ev.species},{__index=ev.mon})
 end
 return true,nil,'queued'
end
function S:turnFor(side)return side=='enemy'and 1 or 0 end
function S:afterAnimFor(side)return side=='player'and'ANIM_ENEMY_DAMAGE'or'ANIM_PLAYER_DAMAGE'end
function S:startAnim(key,opts)
 if key=='missing'then return false,'missing'end
 if key=='error'then error('native script failed')end
 self.anim={animId=key,turn=opts.turn,bg={player={slide=8},enemy={slide=-4}}}
 local context=self
 self.anim.cry=function()return context.battle.player,context.battle.enemy end
 self.anim.flying={self:activeMon('player'),self:activeMon('enemy')}
 return true,nil,'extra'
end
function S:advanceQueue()
 local event=table.remove(self.queue,1)
 if event.kind=='damage'then
  self.lastDamage=event
  if event.anim==false then return false end
  local hit=event.anim or(event.side=='enemy'and'ANIM_ENEMY_DAMAGE'or'ANIM_PLAYER_DAMAGE')
  if self.afterAnimPlayed and(hit=='ANIM_ENEMY_DAMAGE'or hit=='ANIM_PLAYER_DAMAGE')then
   self.afterAnimPlayed=nil;return false
  end
  if hit==false then return false end
  return self:startAnim(event.animMove or hit,{turn=self:turnFor(event.animSide or(event.side=='enemy'and'player'or'enemy'))})
 end
 local result=self:startAnim(event.move,{turn=self:turnFor(event.side)})
 self.pendingAfterAnim={name=self:afterAnimFor(event.side),side=event.side}
 return result,nil,'native'
end
function S:startPendingAfterAnim()
 local p=self.pendingAfterAnim;self.pendingAfterAnim=nil
 if not p then return false end
 return self:startAnim(p.name,{turn=self:turnFor(p.side)})
end
function S:animPicState(side)return self.anim and self.anim.bg[side]end
function S:hudCleared(side)return self.anim and side==(self.anim.turn==0 and'player'or'enemy')end
local painted
local View={drawObjects=function(_,runner,battle,extra)painted=battle;return nil,extra end}
dofile('lib/gen2/move_animation_slots.lua').install(S,View)
local actors={player='player2',enemy='enemy2',playerMon=mons.player2,enemyMon=mons.enemy2}
local s=setmetatable({battle={doubles={},player=mons.player,enemy=mons.enemy},animView=setmetatable({},{__index=View})},{__index=S})
local function event(move)
 s.queue={{move=move or'TACKLE',side='player2',nativeAnimationActors=actors}}
end
event();local a,b,c=s:advanceQueue();assert(a and b==nil and c=='native')
assert(s:nativeAnimationActors()==actors)
assert(s:animPicState('player2').slide==8 and s:animPicState('enemy2').slide==-4)
assert(not s:animPicState('player')and not s:animPicState('enemy'),'native effect leaked to uninvolved leads')
assert(s:hudCleared('player2')and not s:hudCleared('player')and not s:hudCleared('enemy2'))
local p,e=s.anim.cry();assert(p==mons.player2 and e==mons.enemy2,'native cry used lead')
assert(s.anim.flying[1]==mons.player2 and s.anim.flying[2]==mons.enemy2)
assert(s.battle.player==mons.player and s.battle.enemy==mons.enemy,'live context mutated')
local x,y=s.animView:drawObjects(s.anim,s.battle,'native');assert(x==nil and y=='native')
assert(painted.player==mons.player2 and painted.enemy==mons.enemy2 and painted~=s.battle)
assert(s.pendingAfterAnim.name=='ANIM_ENEMY_DAMAGE','partner chose wrong native after-animation')
s.anim=nil;assert(s:startPendingAfterAnim());assert(s:nativeAnimationActors()==actors,'after-animation lost actor map')
local saved=mons.enemy2;mons.enemy2={}
assert(not s:nativeAnimationActors(),'replacement inherited queued actor effects');mons.enemy2=saved
s.afterSendOut={};assert(not s:nativeAnimationActors(),'release metadata overridden');s.afterSendOut=nil
s.anim={};assert(not s:nativeAnimationActors(),'unrelated runner inherited metadata')
event('error');assert(not pcall(s.advanceQueue,s))
s:startAnim('UNRELATED',{turn=0});assert(not s:nativeAnimationActors(),'failed event leaked context')
event('missing');assert(not s:advanceQueue());assert(not s:nativeAnimationActors())
-- Same-side targeting keeps the native two-context identity without swapping gameplay.
actors={player='player',enemy='player2',playerMon=mons.player,enemyMon=mons.player2}
event();s.queue[1].side='player';s:advanceQueue()
assert(s:animPicState('player').slide==8 and s:animPicState('player2').slide==-4)
assert(not s:animPicState('enemy'),'friendly target painted a foe')
-- Standalone hits retain real HP target keys but select the logical script.
for _,pair in ipairs({{'player2','enemy2'},{'player','player2'},{'enemy2','enemy'}})do
 actors={player=pair[1],enemy=pair[2],playerMon=mons[pair[1]],enemyMon=mons[pair[2]]}
 for _,logical in ipairs({'player','enemy'})do
  local ev={kind='damage',side=actors[logical],nativeAnimationActors=actors}
  s.queue={ev};s:advanceQueue()
  assert(s.anim.animId==(logical=='player'and'ANIM_PLAYER_DAMAGE'or'ANIM_ENEMY_DAMAGE'))
  assert(s.anim.turn==(logical=='player'and 1 or 0))
  assert(s.lastDamage.side==ev.side and ev.anim==nil and ev.animSide==nil,'original event or HP target mutated')
  assert(s:nativeAnimationActors()==actors)
 end
end
s.queue={{kind='damage',side=actors.enemy,nativeAnimationActors=actors,anim='ANIM_HIT_CONFUSION',animSide=actors.enemy}}
s:advanceQueue();assert(s.anim.animId=='ANIM_HIT_CONFUSION'and s.anim.turn==1,'custom self hit changed')
s.queue={{kind='damage',side=actors.enemy,nativeAnimationActors=actors,animMove='WRAP',animSide=actors.player}}
s:advanceQueue();assert(s.anim.animId=='WRAP'and s.anim.turn==0,'residual move changed')
s.queue={{kind='damage',side=actors.enemy,nativeAnimationActors=actors}};s.afterAnimPlayed=true
assert(not s:advanceQueue()and not s.afterAnimPlayed,'native duplicate-hit latch changed')
s.queue={{kind='damage',side=actors.enemy,nativeAnimationActors=actors,anim=false}}
assert(not s:advanceQueue(),'disabled hit enabled')
-- Native push creates a provable display copy; arbitrary lookalikes do not.
actors={player='player2',enemy='enemy2',playerMon=mons.player2,enemyMon=mons.enemy2}
s.shownMon={player2=mons.player2,enemy2=mons.enemy2}
local ok,nothing,queued=s:push({kind='transform',side='player2',mon=mons.player2,from='DITTO'})
assert(ok and nothing==nil and queued=='queued')
local shown=s.shownMon.player2;event();s:advanceQueue()
assert(s:nativeAnimationActors().playerMon==shown,'native Transform display copy lost ownership')
assert(s:animPicState('player2')and not s:animPicState('player'),'display copy moved to lead')
local cry=s.anim.cry();assert(cry==shown,'native cry did not follow displayed identity')
s.shownMon.player2=mons.player2
assert(s:nativeAnimationActors().playerMon==mons.player2,'native Transform completion lost identity')
s.shownMon.player2=setmetatable({species='DITTO'},{__index=mons.player2})
assert(not s:nativeAnimationActors(),'unproven lookalike proxy accepted')
s.shownMon.player2=mons.player2
s:push({kind='identity',side='player2',mon=mons.player2,species='DITTO'})
assert(s:nativeAnimationActors().playerMon==s.shownMon.player2,'native identity event lost ownership')
s.shownMon.player2={};assert(not s:nativeAnimationActors(),'replacement identity accepted')
s.battle.doubles=nil;assert(not s:nativeAnimationActors())
assert(s:turnFor('enemy2')==0,'standalone singles changed')
print('PASS paired native move/after-animation ownership, cry/flying/palette identity, exact HUD, friendly target, error/stale/standalone fallback')
