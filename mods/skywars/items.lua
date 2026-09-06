core.register_on_mods_loaded(function()
    for name, def in pairs(core.registered_items) do
        if def and def.type == "node" then
            local recipes = core.get_all_craft_recipes(name)
            if recipes and #recipes > 0 then -- Check s'il y a bien des recettes
                core.clear_craft({output = name})
            end
        end
    end
end)
