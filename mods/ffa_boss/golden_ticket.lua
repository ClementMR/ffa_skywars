core.register_craftitem("ffa_boss:golden_ticket", {
    description = core.colorize("#FFD700", ffa_boss.S("Golden ticket")),
    inventory_image = "ffa_boss_golden_ticket.png",
    stack_max = 1,
    on_use = function(itemstack, user, pointed_thing)
        local ok, error = ffa_boss.start_event()
        if ok then
            itemstack:take_item(1)
            return itemstack
        end

        core.chat_send_player(user:get_player_name(), error)
    end
})
