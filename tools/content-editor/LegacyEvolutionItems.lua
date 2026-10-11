-- The Gen 1/2 engines dispatch vanilla stones by ID. Export custom stones
-- with the same effect contracts and party-menu behavior.
local M = {}
function M.used(project)
  for _, item in pairs(project.items or {}) do
    if item.effectTemplate == "stone" then return true end
  end
  return false
end
function M.emit(project, gen2, encode, out)
  local ids = {}
  for id, item in pairs(project.items or {}) do
    if item.effectTemplate == "stone" then ids[#ids + 1] = id end
  end
  table.sort(ids)
  if #ids == 0 then return end
  out[#out + 1] = "local customStones=" .. encode(ids)
  if gen2 then
    out[#out + 1] = [=[
  local stone=require("src.core.gen2.ItemEffects").RECORDS.FIRE_STONE
  for _,id in ipairs(customStones) do
    mod.content.item_effects:override(id, {
      action="stone", field=true, needsTarget=true, use=stone.use,
    })
    mod.content.items:patch(id,{fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_NOUSE"})
  end
]=]
  else
    out[#out + 1] = [=[
  for _,id in ipairs(customStones) do
    local effect=id.."_EVOLUTION_STONE"
    mod.content.item_effects:register(effect, {
      field=true,battle=false,needsTarget=true,
      use=function(ctx)
        local data,save,target=ctx.data,ctx.save,ctx.target
        local def=target and data.pokemon[target.species]
        for _,evo in ipairs(def and def.evolutions or {}) do
          if evo.method=="ITEM" and evo.item==ctx.itemId then
            if require("src.core.GameVersion").isYellow()
                and require("src.world.PikachuFollower").isStarterPikachu(save,target) then
              require("src.core.Sound").playCry(data,"PIKACHU")
              save.pikachuEmotionModifier,save.pikachuMood=4,0x82
              local name=target.nickname or def.name or target.species
              return "failed",{name.."\nis refusing!"}
            end
            require("src.core.Sound").play(data,"Heal_Ailment")
            return "consumed",nil,{evolveTo=evo.species}
          end
        end
        return "failed",{"It won't have any effect."}
      end,
    })
    mod.content.items:patch(id,{effect=effect,needsTarget=true})
  end
  mod.events:on("game.ready",function()
    local effects=require("src.inventory.ItemEffects")
    local isStone=effects.isStone
    local ids={};for _,id in ipairs(customStones) do ids[id]=true end
    effects.isStone=function(id) return ids[id] or isStone(id) end
  end)
]=]
  end
end
return M
