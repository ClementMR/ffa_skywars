core.register_craftitem("ffa_boss:golden_ticket", {
    description = core.colorize("#FFD700", "Golden ticket" ).. "\nUse to spawn a boss",
    inventory_image = "ffa_boss_golden_ticket.png",
    stack_max = 1,
    on_use = function(itemstack, user, pointed_thing)
        if ffa_boss.start_event() then
            itemstack:take_item(1)
            return itemstack
        end
    end
})
