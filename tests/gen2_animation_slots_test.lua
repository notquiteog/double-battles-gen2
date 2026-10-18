local mons={player={},player2={},enemy={},enemy2={}}
local S={}
function S:activeMon(side)return mons[side]end
function S:turnFor(side)return side=='enemy'and 1 or 0 end
function S:animPicState(side)return{size=self.anim.bg.picSize[side]}end
function S:revealSentOut()self.originalReveal=true end
function S:finishSendOut(after)
 self.picHidden[after.side]=false;self.cry=after.mon;self.hud=after.side
 if self.fail then error('native finish failed')end
 return nil,after.mon,false
end
dofile('lib/gen2/animation_slots.lua').install(S)
local s=setmetatable({battle={doubles={}},anim={animId='ANIM_SEND_OUT_MON',bg={picSize={player=3,enemy=2}}},picHidden={player=true,player2=true,enemy=true,enemy2=true}},{__index=S})
for _,slot in ipairs({'player','player2','enemy','enemy2'})do
 s.afterSendOut={side=slot,mon=mons[slot]};assert(s:nativeAnimationSlot()==slot)
 assert(s:turnFor(slot)==(slot:match('enemy')and 1 or 0))
 for other in pairs(mons)do assert((s:animPicState(other)~=nil)==(other==slot),'wrong BG owner')end
 if slot:match('2$')then
  local base=slot:gsub('2$','');s.picHidden[slot]=true;s.picHidden[base]=true;s:revealSentOut()
  assert(not s.picHidden[slot]and s.picHidden[base],'partner reveal changed lead')
  s.picHidden[slot]=true -- native no-script completion also clears the actor
  local a,b,c=s:finishSendOut(s.afterSendOut);assert(a==nil and b==mons[slot]and c==false)
  assert(s.hud==base and s.cry==mons[slot]and s.picHidden[base]and not s.picHidden[slot],'native cry/HUD or lead hidden state')
 end
end
s.fail=true;assert(not pcall(s.finishSendOut,s,s.afterSendOut));assert(s.picHidden.enemy)
s.fail=nil;s.afterSendOut.mon={};assert(s:nativeAnimationSlot()==nil,'stale queued identity')
s.afterSendOut.mon=mons.enemy2;s.anim.animId='TACKLE';assert(not s:nativeAnimationSlot(),'move ownership invented')
s.anim.animId='ANIM_SEND_OUT_MON';s.battle.doubles=nil;assert(not s:nativeAnimationSlot());assert(s:turnFor('enemy2')==0,'single native reader changed')
print('PASS exact native paired sendout slot, BG identity, turn/reveal, native cry/HUD/returns, stale/move/single fallback and error restoration')
