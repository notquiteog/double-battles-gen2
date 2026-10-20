local depth,draws,bodyCalls,hook=0,{},0
love={graphics={push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
 origin=function()end,setShader=function()end,setColor=function()end,setScissor=function()end,
 translate=function()end,scale=function()end,getDimensions=function()return 640,480 end}}
package.loaded['src.ui.gen2.Chrome']={fitOrigin=function(w,h,s)assert(s==3);return 80,24 end}
local State={}
function State:nativeSceneLayout()return not self.modern and'gen2-native-pair'or nil end
function State:wideLayout()return self.wide end
function State:exitFadeBgp()return self.fade end
function State:battlePanelScale()return 3 end
function State:drawEnemyHud()draws[#draws+1]='enemy';if self.failHud then error('HUD failure')end end
function State:drawPlayerHud()draws[#draws+1]='player'end
function State:drawSceneBody()
 bodyCalls=bodyCalls+1;self:drawEnemyHud();self:drawPlayerHud()
 if self.failBody then error('body failure')end
 return 'native-body'
end
local mod={hooks={wrap=function(_,name,fn)assert(name=='render.hud');hook=fn end}}
local M=dofile('lib/gen2/native_hud_resolution.lua')
assert(M.install(State,mod));assert(not M.install(State,mod))
local s=setmetatable({phase='menu',battle={}},{__index=State})
local game={stack={top=function()return s end}}
local function paint()return hook(function()return 'next-result'end,game,{})end
assert(s:drawSceneBody()=='native-body'and#draws==0 and not s.nativePairHudDeferred)
assert(paint()=='next-result'and#draws==2 and depth==0)
paint();assert(#draws==2,'stale pending frame redrawn')
for _,case in ipairs({{'anim',{}},{'phase','resolving'},{'modern',true},{'wide',true},{'fade',0},{'expBurst',{}}})do
 local key,value=unpack(case);local old=s[key];s[key]=value;draws={}
 s:drawSceneBody();assert(#draws==2,'native fallback missing for '..key)
 paint();assert(#draws==2,'fallback drawn twice for '..key);s[key]=old
end
draws={};s:drawSceneBody();s.battle={};paint();assert(#draws==0,'replacement battle claimed old frame')
s:drawSceneBody();local originalTop=game.stack.top;game.stack.top=function()return{}end
paint();assert(#draws==0,'covered screen claimed HUD');game.stack.top=originalTop
s.failBody=true;assert(not pcall(s.drawSceneBody,s));assert(not s.nativePairHudDeferred);s.failBody=nil
s:drawSceneBody();s.failHud=true;assert(not pcall(paint));assert(depth==0);s.failHud=nil
print('PASS native paired HUD window resolution, original layout/returns, animation/provider/fade fallback, identity and error restoration')
