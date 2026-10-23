-- All claimed editions use the public row hook; native page builders stay owned.
for _,version in ipairs{'red','gold','crystal','firered','leafgreen','ruby','sapphire','emerald'}do
 local gen=version=='red'and 1 or(version=='gold'or version=='crystal')and 2 or 3
 package.loaded['src.core.GameVersion']={generation=function()return gen end}
 package.loaded['src.ui.game3.option_rows']=nil
 package.preload['src.ui.game3.option_rows']=function()error('private native row builders must not be patched')end
 local events={};package.loaded['src.mods.Runtime']={emit=function(k,p)events[#events+1]={k,p}end}
 local values={wild_doubles='sometimes'};local callbacks={}
 local mod={id='TEST',supports=function(_,surface,key)return surface=='hooks'and key=='ui.options.rows'end,options={get=function(_,k)return values[k]end},hooks={wrap=function(_,key,fn)callbacks[key]=fn end}}
 local Adapter=dofile('lib/InGameOptions.lua');Adapter.install(mod,{{key='wild_doubles',label='WILD DOUBLES',type='choice',choices={{'OFF','off'},{'SOMETIMES','sometimes'},{'ALWAYS','always'}}}},'TEST')
 local hook=assert(callbacks['ui.options.rows']);local native={id='textSpeed',label='NATIVE TEXT SPEED'};local back={id='cancel',label='BACK'};local marker={};local calls=0
 local game={options={modOptions={}},mods={modOptions={}},writeOptions=function()calls=calls+1 end}
 local function base(g,rows,extra)assert(g==game and extra==marker);return rows end
 local rows=hook(base,game,{native,back},marker);assert(#rows==3 and rows[1]==native and rows[3]==back and rows[2].id=='TEST:wild_doubles')
 rows[2].step(game,1);assert(game.mods.modOptions.TEST.wild_doubles=='always'and calls==1 and #events==1)
 rows=hook(base,game,rows,marker);assert(#rows==3,'duplicate native option rows')
 callbacks['core.quit_to_launcher'](function()end);rows=hook(base,game,{native,back},marker);assert(#rows==2 and rows[1]==native)
end
print('PASS public option rows, canonical game callbacks, future args, persisted preferences, duplicate/unload guards across8 editions')
