local mons={player={},player2={},enemy={},enemy2={}}
local S={}
function S:activeMon(slot)return mons[slot]end
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
s.battle.doubles=nil;assert(not s:nativeAnimationActors())
assert(s:turnFor('enemy2')==0,'standalone singles changed')
print('PASS paired native move/after-animation ownership, cry/flying/palette identity, exact HUD, friendly target, error/stale/standalone fallback')
