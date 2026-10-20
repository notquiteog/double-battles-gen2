package.loaded['src.ui.gen2.BattleHud']={EXP_LENGTH_PX=72}
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
local modern=true
Hud.install(State,function()return modern end)
setmetatable(s,{__index=State});s.phase='menu'
s:drawSceneBody()
assert(captures==3 and not s.modernHudDeferred and depth==0,'animation capture state leaked')
print('HUD excluded from repeated BG bakes and composed once after animation FX')

s.battle.doubles=nil
assert(Hud.active(s),'single battle must use modern layout')
s:drawSceneBody()
modern=false;assert(not Hud.active(s),'single battle opt-out failed')
s.battle.doubles={};assert(not Hud.active(s),'double battle opt-out failed')
modern=true;assert(Hud.active(s),'double battle enable failed')
s.battle.doubles=nil
s.tutorial=true;modern=true;assert(not Hud.active(s),'tutorial layout must stay native')
print('single battle modern layout, opt-out and tutorial guard passed')

-- A staged provider owns projection; every live slot must use its own head,
-- not the old corner anchors. The public theme handles native text tokens.
local anchors,buttons,labels={},{},{}
local theme={apiVersion=1,ink={.2,.2,.2,1},panel=function()end,
 aboveHead=function(x,y,w,h)return x-w/2,y-h-10 end,
 statusCard=function(x,y,w,h,tip)anchors[#anchors+1]={x=x,y=y,tip=tip}end,
 button=function(x,y,w,h,kind)buttons[#buttons+1]=kind end,
 text=function(s)labels[#labels+1]=s end,
 hpColor=function()return .1,.7,.2,1 end}
Hud.install(State,function()return true end,function()return theme end,function(slot)
 return ({player=300,player2=600,enemy=1200,enemy2=1800})[slot],400
end)
width,height=2560,1440;s.tutorial=false;s.battle.doubles={};s.battle.player2=mon
s.phase='menu';s:drawSceneBody()
assert(#anchors==4,'not all four heads received independent cards')
assert(anchors[1].tip==300 and anchors[2].tip==450 and anchors[3].tip==75 and anchors[4].tip==150)
assert(table.concat(buttons,',')=='fight,pokemon,bag,run','semantic command order changed')
assert(table.concat(labels,','):find('PKMN',1,true),'native Pokemon formatting escaped into UI')
assert(depth==0)
print('public theme/anchor providers: four independent overhead cards, command order and clean labels passed')

-- Final composition happens after native letterboxing; stack menus hide cards.
local Installed={drawEnemyHud=function()end,drawPlayerHud=function()end,drawBottom=function()end}
Installed.drawSceneBody=function(self)self:drawEnemyHud();self:drawPlayerHud();self:drawBottom(0)end
local finalHud
Hud.install(Installed,function()return true end,function()return theme end,nil,
 {hooks={wrap=function(_,name,fn)assert(name=='render.hud');finalHud=fn end}})
setmetatable(s,{__index=Installed});anchors={};buttons={};labels={}
s:drawSceneBody();assert(#labels==0,'window cards painted before final native frame')
local game={stack={top=function()return s end}}
finalHud(function()return 'native'end,game);assert(#labels>0,'final window HUD absent')
labels={};s:drawSceneBody();game.stack.top=function()return{}end
finalHud(function()end,game);assert(#labels==0,'stale cards covered native party/bag')
print('window HUD deferred past native frame and hidden by stack menus')

local semantic={}
local layouts=0
theme.layoutStatusCards=function(items)layouts=layouts+1;assert(#items==4);local out={};for _,i in ipairs(items)do out[i.id]={x=i.id*100,y=30}end;return out end
theme.combatCardSize=function(ally)return 90,ally and 25 or 18 end
theme.combatCard=function(x,y,w,h,tip,selected,c)semantic[#semantic+1]=c;assert(w==90);return true end
-- Restore direct scene hooks, keeping real state selection and native values.
Hud.install(State,function()return true end,function()return theme end,function(slot)return ({player=300,player2=600,enemy=1200,enemy2=1800})[slot],400 end)
setmetatable(s,{__index=State});s.phase='menu';s:drawSceneBody()
assert(#semantic==4 and layouts==4,'semantic provider missed a double slot or shared layout')
for _,c in ipairs(semantic)do assert(c.name and c.level and c.hp and c.maximum,'native card fields dropped')end
print('optional semantic compact cards preserve all four native battlers')

local offsets={};G.translate=function(x,y)offsets[#offsets+1]={x,y}end
local projected
theme.viewport=function(w,h)assert(w==2560 and h==1440);return 80,40,2400,1320 end
theme.layoutStatusCards=function(items,w,h)
 assert(w==600 and h==330);projected={};local out={}
 for _,i in ipairs(items)do projected[i.id]=i;out[i.id]={x=20,y=30}end
 return out
end
Hud.drawSide(s,'enemy')
assert(offsets[1][1]==80 and offsets[1][2]==40,'safe origin not applied')
assert(projected[0].x==55 and projected[1].x==280 and projected[2].x==130 and projected[3].x==430)
for _,i in pairs(projected)do assert(i.y==90,'actor anchor omitted safe-origin subtraction')end
assert(Hud.layout.width==600 and Hud.layout.height==330 and depth==0)
print('PASS safe-area card bounds, exact projected heads and graphics restoration')
