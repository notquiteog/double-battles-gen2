local width,height=2560,1440
local requested,depth,rects={},0,0
love={graphics={}}
local G=love.graphics
function G.push() depth=depth+1 end
function G.pop() depth=depth-1 end
function G.getDimensions()return width,height end
G.origin=function()end;G.scale=function()end;G.translate=function()end
function G.newFont(size,hint,dpi)
 requested[#requested+1]=dpi
 return {getWidth=function(_,s)return #s*3 end}
end
G.setScissor=function()end;G.setShader=function()end;G.setFont=function()end;G.setColor=function()end
G.setLineWidth=function()end;G.print=function()end
function G.rectangle(kind,x,y,w,h)
 assert(x>=0 and y>=0 and x+w<=width and y+h<=height,'panel outside native playfield')
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
assert(requested[1]==4 and #requested==1,'font rasterization must match displayed scale and be cached')
width,height=960,720;Hud.drawSide(s,'enemy');assert(requested[2]==3,'font follows display resize')
s.phase='moves';assert(Hud.drawBottom(s))
s.phase='db2_target';s.doubleTargetSlot='enemy2'
function s:doubleTargets()return {'enemy','enemy2'} end
assert(Hud.drawBottom(s));Hud.drawSide(s,'enemy')
s.phase='ask-nickname';assert(not Hud.drawBottom(s),'special prompt must retain native controls')
assert(depth==0 and rects>15,'graphics state restored across every panel')
print('modern HUD bounds, font DPI/cache, resize and native prompt fallback passed')
-- Native scanline effects may bake the panel several times in a frame.
-- No modern window-space UI may enter those 160x144 captures.
local capturing=false
local captures,afterFX=0,false
local oldRect=G.rectangle
G.rectangle=function(...)
 assert(not capturing,'modern UI entered the small animation canvas')
 assert(afterFX,'modern UI drawn before animation objects')
 return oldRect(...)
end
local State={drawEnemyHud=function()end,drawPlayerHud=function()end,drawBottom=function()end}
function State:drawSceneBody()
 capturing=true
 for i=1,3 do self:drawEnemyHud();self:drawPlayerHud();self:drawBottom(0);captures=captures+1 end
 capturing=false;afterFX=true
end
Hud.install(State)
setmetatable(s,{__index=State});s.phase='menu'
s:drawSceneBody()
assert(captures==3 and not s.modernHudDeferred and depth==0,'animation capture state leaked')
print('HUD excluded from repeated BG bakes and composed once after animation FX')
