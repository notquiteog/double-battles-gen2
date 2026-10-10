local depth,draws,huds=0,{},{}
love={graphics={push=function()depth=depth+1 end,pop=function()depth=depth-1 end,translate=function()end,scale=function()end}}
local State={PLAYER_PIC_TILE_X=2,PLAYER_PIC_TILE_Y=6,PLAYER_PIC_TILES=6,ENEMY_PIC_TILE_X=12,ENEMY_PIC_TILE_Y=0,ENEMY_PIC_TILES=7}
local mons={player={hp=40,level=10},player2={hp=35,level=12},enemy={hp=30,level=7},enemy2={hp=20,level=8}}
function State:activeMon(slot)return mons[slot]end
function State:hudHp(mon,slot)return slot=='enemy2'and 9 or mon.hp end
function State:statusTag(mon,slot)return slot=='player2'and'PSN'or nil end
function State:expPixels(mon)return mon.level end
function State:drawPic(mon,back)draws[#draws+1]={mon,back};if self.fail then error('native picture failure')end end
function State:drawEnemyHud()local m=self:activeMon('enemy');huds[#huds+1]={m,self:hudHp(m,'enemy')}end
function State:drawPlayerHud()local m=self:activeMon('player');huds[#huds+1]={m,self:statusTag(m,'player'),self.shownExp}end
dofile('lib/gen2/native_layout.lua').install(State)
local s=setmetatable({battle={},shownExp=4,shownLevel=10,ballRows={player=true}},{__index=State})
s:drawPic(mons.player,true);s:drawEnemyHud();assert(#draws==1 and #huds==1,'single battle changed')
draws,huds={},{};s.battle.doubles={}
s:drawPic(mons.enemy,false);s:drawPic(mons.player,true)
s:drawEnemyHud();s:drawPlayerHud()
assert(#draws==4 and #huds==4,'missing or duplicate native battler/HUD')
assert(huds[2][1]==mons.enemy2 and huds[2][2]==9,'partner HP animation reads lead')
assert(huds[4][1]==mons.player2 and huds[4][2]=='PSN'and huds[4][3]==12,'partner status/EXP reads lead')
assert(s.shownExp==4 and s.ballRows.player,'HUD proxy mutated engine screen')
draws={};s.showPlayerTrainer=true;s:drawPic(mons.player,true);assert(#draws==1,'trainer drawn twice')
s.showPlayerTrainer=false;s.fail=true;assert(not pcall(s.drawPic,s,mons.player,true));assert(depth==0,'graphics state leaked after native failure')
print('PASS native Gen2 doubles slots, identity/HP/status/EXP, trainer and single fallback, state restoration')
