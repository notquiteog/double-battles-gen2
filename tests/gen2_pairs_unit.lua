local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local options={gen2_doubles=true,trainer_pairs=true,pair_distance=1}
local records={[1]={class=1,classId='YOUNGSTER',id='JOEY1',member=1,name='JOEY',baseMoney=4,party={{hp=20,level=10},{hp=20,level=13}}},[2]={class=1,classId='YOUNGSTER',id='MIKEY1',member=2,name='MIKEY',baseMoney=6,party={{hp=20,level=12},{hp=20,level=16}}}}
local a={cellX=4,cellY=3,def={trainer={class=1,member=1,event=10}}};local b={cellX=6,cellY=3,def={trainer={class=1,member=2,event=11}}}
package.loaded['src.world.gen2.Trainers']={party=function(_,r)local p={};for i,m in ipairs(r.party)do p[i]={hp=m.hp,level=m.level}end;return p end}
local awards={}
package.loaded['src.battle.gen2.Prize']={rewardLevel=function(p)return p[#p].level end,award=function(_,v)awards[#awards+1]=v;return v end,message=function()return 'reward'end}
local flags={};local world={trainerNpc=a,npcs={a,b},game={data={}},events={set=function(_,k,v)flags[k]=v end}}
function world:trainerParty(_,m)return records[m]end
function world:trainerBeaten(r)return flags[r.event]end
function world:trainerRefused()return false end
local mod={options={get=function(_,k)return options[k]end}}
local M=dofile('lib/gen2/pairs.lua')(mod,{})
local lead={class=1,classId='YOUNGSTER',memberId='JOEY1',party=records[1].party,baseMoney=4,name='JOEY'}
local original={trainer=lead}
local out,info=M.combine(world,original);ok(out==original and not info,'distance 1 remains single')
options.pair_distance=2;out,info=M.combine(world,original);ok(info and #out.trainer.party==4,'distance 2 recruits visible unbeaten trainer')
ok(out.trainer~=lead and #lead.party==2,'input trainer is unchanged')
ok(info.owner[1]=='enemy'and info.owner[2]=='enemy2'and info.owner[3]=='enemy'and info.owner[4]=='enemy2','replacement pools retain trainer ownership')
local battle={doubles={},save={player={name='P'}},amuletCoin=true,emit=function()end}
M.decorate(battle,info);battle:awardPrizeMoney();battle:awardPrizeMoney();ok(#awards==2,'two independent native awards paid once')
ok(awards[1].level==13 and awards[2].level==16 and awards[2].amuletCoin,'original last levels and Amulet Coin preserved')
M.finish(world,info,'lose');ok(not flags[11],'loss leaves trainer B unbeaten');M.finish(world,info,'win');ok(flags[11],'win writes trainer B native event')
out,info=M.combine(world,original);ok(not info,'defeated partner unavailable')
flags[11]=nil;options.trainer_pairs=false;out,info=M.combine(world,original);ok(not info,'pairs OFF')
options.trainer_pairs=true;lead.classId='RIVAL1';out,info=M.combine(world,original);ok(not info,'story trainer excluded')
print('gen2_pairs_unit: '..n..' contracts passed')
