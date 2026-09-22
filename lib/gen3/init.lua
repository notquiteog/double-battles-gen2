-- FireRed already owns four battlers, target selection, paired actions, spread
-- moves and link doubles. Keep those mechanics in the native battle engine.
return function(mod)
  local Bridge=require('src.core.game3.battle_bridge')
  local Party=require('src.core.game3.party')
  local Runtime=require('src.core.game3.runtime')
  local schema=mod.options:define({
    {key='gen3_trainer_doubles',label='TRAINER DOUBLES',type='toggle',default=false},
    {key='online_doubles',label='ONLINE DOUBLES',type='toggle',default=true},
  })
  assert((loadstring or load)(assert(mod:read('lib/InGameOptions.lua')),'@double-battles-gen2/options'))().install(mod,schema,'DOUBLE BATTLES')
  local start=Bridge.start
  Bridge.start=function(nativeMod,game,foe,opts)
    opts=opts or {}
    -- A native double trainer retains its imported flag regardless of this
    -- option. Scripted wilds and visible spawns never become trainer battles.
    if not opts.wild and not opts.link and mod.options:get('gen3_trainer_doubles')
      and type(foe)=='table' and type(foe.party)=='table' and #foe.party>=2 then
      local s=Runtime.getSession()
      if s and Party.monsStateToDoubles(s.party)==Party.PLAYER_HAS_TWO_USABLE_MONS then
        local copy={};for k,v in pairs(opts)do copy[k]=v end;copy.double=true;opts=copy
      end
    end
    return start(nativeMod,game,foe,opts)
  end
  mod.exports.online={protocol=1,generation=3,
    supportsDouble=function()return mod.options:get('online_doubles')~=false end}
  mod.exports.nativeDoubles=true
  mod.log:info('FireRed native trainer/link doubles integration loaded; visible wild encounters preserved')
end
