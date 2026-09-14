local scale=5
local requested,depth,rects={},0,0
love={graphics={}}
local G=love.graphics
function G.push() depth=depth+1 end
function G.pop() depth=depth-1 end
function G.transformPoint(x,y)return x*scale,y*scale end
function G.newFont(size,hint,dpi)
 requested[#requested+1]=dpi
 return {getWidth=function(_,s)return #s*3 end}
end
G.setShader=function()end;G.setFont=function()end;G.setColor=function()end
G.setLineWidth=function()end;G.print=function()end
function G.rectangle(kind,x,y,w,h)
 assert(x>=0 and y>=0 and x+w<=161 and y+h<=144,'panel outside native playfield')
 rects=rects+1
end
local Hud=dofile('lib/gen2_hud.lua')
local mon={hp=12,stats={hp=30},level=8,species='SENTRET',moves={{id='TACKLE',pp=35}}}
local s={battle={doubles={},enemy=mon,enemy2=mon,player=mon},showEnemyHud=true,showPlayerHud=true,
 phase='menu',menuIndex=1,moveIndex=1,game={data={moves={TACKLE={name='TACKLE',type='NORMAL'}}}}}
function s:activeMon(side)return self.battle[side] end
function s:hudHp(m)return m.hp end
function s:statusTag()return nil end
function s:name(m)return m.species end
function s:statusHUDVisible()return true end
function s:bottomUIVisible()return true end
function s:hudCleared()return false end
function s:menuLabels()return {'FIGHT','POKEMON','PACK','RUN'} end
function s:playerMoves()return mon.moves end
Hud.drawSide(s,'enemy');Hud.drawSide(s,'player');assert(Hud.drawBottom(s))
assert(requested[1]==5 and #requested==1,'font rasterization must match displayed scale and be cached')
scale=3;Hud.drawSide(s,'enemy');assert(requested[2]==3,'font follows display resize')
s.phase='moves';assert(Hud.drawBottom(s))
s.phase='ask-nickname';assert(not Hud.drawBottom(s),'special prompt must retain native controls')
assert(depth==0 and rects>15,'graphics state restored across every panel')
print('modern HUD bounds, font DPI/cache, resize and native prompt fallback passed')
