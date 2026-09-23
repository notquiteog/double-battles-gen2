-- Run fixture-only core tests against an unpacked engine; no ROM/profile load.
local engine=assert(arg[1],'usage: luajit tests/run_gen2_core.lua ENGINE_ROOT')
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
local count=0
package.loaded['tests.modkit']={
 check=function(v,m)count=count+1;assert(v,m)end,
 eq=function(a,b,m)count=count+1;assert(a==b,tostring(m)..': '..tostring(a)..' ~= '..tostring(b))end,
 finish=function(name)print(name..': '..count..' contracts passed')end,
}
package.loaded['tests.love_stub']={math={random=math.random},timer={getTime=os.clock},graphics={},filesystem={read=function()end,getInfo=function()end}}
local original=dofile
dofile=function(path)
 if path:sub(1,20)=='mods/double_battles/'then path=path:sub(21)end
 return original(path)
end
original('tests/doubles2_core_test.lua')
