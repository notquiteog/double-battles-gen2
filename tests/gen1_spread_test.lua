local M=dofile('lib/gen1_spread.lua')
package.loaded['src.core.Strings']=function(s,...)return string.format(s,...)end
local events={};package.loaded['src.mods.Runtime']={emit=function(_,e)events[#events+1]=e end}
local function mon(own)return {isPlayer=own,name='TEST',mon={hp=100}}end
local p,p2,e,e2=mon(true),mon(true),mon(false),mon(false)
local b={player=p,player2=p2,enemy=e,enemy2=e2,data={moves={SURF={power=95},EXPLOSION={power=170,effect='EXPLODE_EFFECT'}}}}
function b:accuracyRoll()return true end
b.rng=function()return 1 end
function b:computeDamage(_,_,move,opts)assert(opts.rng==self.rng,'unseeded ripple RNG');assert(opts.explode==(move.effect=='EXPLODE_EFFECT'));return 20,{crit=false,typeMult=10}end
function b:sayNext()end;function b:handleBuildingRage()end
function b:applyDamage(v,d)if v.substituteHP then v.substituteHP=v.substituteHP-d else v.mon.hp=v.mon.hp-d end;return d end
function b:onFaint(v)v.fainted=true end
M.ripple(b,p,e,{id='SURF'},'foes')
assert(e2.mon.hp==85 and p2.mon.hp==100 and e.mon.hp==100 and #events==1)
e2.invulnerable=true;M.ripple(b,p,e,{id='SURF'},'foes');assert(e2.mon.hp==85)
e2.invulnerable=nil;e2.substituteHP=40
M.ripple(b,p,e,{id='SURF'},'foes');assert(e2.substituteHP==25 and e2.mon.hp==85)
local targets=M.targets(b,p,e,'others')
assert(targets[1]==e2 and targets[2]==p2,'actor-relative target order')
local mirrored={player=e,player2=e2,enemy=p,enemy2=p2}
p.isPlayer=false;p2.isPlayer=false;e.isPlayer=true;e2.isPlayer=true
local other=M.targets(mirrored,p,e,'others');assert(other[1]==e2 and other[2]==p2,'mirrored RNG target order')
p.isPlayer=true;p2.isPlayer=true;e.isPlayer=false;e2.isPlayer=false
p.mon.hp=0;b.player=p2;b.player2=nil
M.ripple(b,p,e,{id='EXPLOSION'},'others',targets)
assert(p2.mon.hp==85,'explosion reaches snapshotted ally after promotion')
assert(e2.substituteHP==10,'explosion reaches extra foe after user faint')
local hp=p2.mon.hp;M.ripple(b,p,e,{id='SURF'},'foes',targets);assert(p2.mon.hp==hp,'nonexplosion dead actor stopped')
print('PASS native ripple damage, Substitute, invulnerability, fainted Explosion and target snapshots')
