-- Custom target prompts pause native battle logic. Let independent sprite
-- providers animate through their public presentation-only seam in that gap.
return function(battle, dt)
  if not battle or (battle.phase ~= 'db_target'
      and battle.phase ~= 'db_switch_target') then return end
  local exports = battle.game and battle.game.mods and battle.game.mods.exports
  if type(exports) ~= 'table' then return end
  local seen = {}
  for _, provider in pairs(exports) do
    local update = type(provider) == 'table' and provider.updateBattlePresentation
    if type(update) == 'function' and not seen[update] then
      seen[update] = true
      pcall(update, battle, dt)
    end
  end
end
