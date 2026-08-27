enderpearl = {}
local t = core.get_translator("enderpearl")
local callbacks = {}

----------------------
-- ! Item Section ! -- 
----------------------

local cooldown = skywars.cooldown()
core.register_craftitem("enderpearl:ender_pearl", {
  description = core.colorize("#800080", "Enderpearl") .. core.colorize("#808080", "\nCooldown 5s"),
  inventory_image = "enderpearl.png",
  stack_max = 16,
  on_use =
    function(_, player, pointed_thing)
      if cooldown:get(player) then
        return
      else
        cooldown:set(player, 5)
      end

      local throw_starting_pos = vector.add({x=0, y=1.5, z=0}, player:get_pos())
      local ender_pearl = core.add_entity(throw_starting_pos, "enderpearl:thrown_ender_pearl", player:get_player_name())

      core.after(0, function() player:get_inventory():remove_item("main", "enderpearl:ender_pearl") end)
    
      core.sound_play("enderpearl_throw", {max_hear_distance = 10, pos = player:get_pos()})
    end,
  
})



------------------------
-- ! Entity Section ! -- 
------------------------

-- entity declaration
local thrown_ender_pearl = {
  initial_properties = {
    hp_max = 1,
    physical = true,
    collide_with_objects = false,
    collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.2, 0.2},
    visual = "wielditem",
    visual_size = {x = 0.4, y = 0.4},
    textures = {"enderpearl:ender_pearl"},
    spritediv = {x = 1, y = 1},
    initial_sprite_basepos = {x = 0, y = 0},
    pointable = false,
    speed = 30,
    gravity = 15,
    damage = 2,
    lifetime = 10
  },
  player_name = ""
}


function thrown_ender_pearl:on_step(dtime, moveresult)  
  local collided_with_node = moveresult.collisions[1] and moveresult.collisions[1].type == "node"

  if collided_with_node then
    local player = core.get_player_by_name(self.player_name)

    if not player then
      self.object:remove()
      return
    elseif player:get_meta():get_string("ep_can_teleport") == "false" then
      self.object:remove()
      return
    end
    -- removing fall damage
    player:add_velocity(vector.multiply(player:get_velocity(), -1))
    player:set_pos(vector.add(self.object:get_pos(), {x = 0, y = 1, z = 0}))
    player:set_hp(player:get_hp()-self.initial_properties.damage, "enderpearl")
    core.sound_play("enderpearl_teleport", {max_hear_distance = 10, pos = player:get_pos()})

    for i=1, #callbacks do
      local node = core.get_node(moveresult.collisions[1].node_pos)
      callbacks[i](node)
    end

    self.object:remove()
  end
end



function thrown_ender_pearl:on_activate(staticdata)
  if not staticdata or not core.get_player_by_name(staticdata) then
    self.object:remove()
    return
  end

  self.player_name = staticdata
  local player = core.get_player_by_name(staticdata)
  local yaw = player:get_look_horizontal()
  local pitch = player:get_look_vertical()
  local dir = player:get_look_dir()

  self.object:set_rotation({x = -pitch, y = yaw, z = 0})
  self.object:set_velocity({
      x=(dir.x * self.initial_properties.speed),
      y=(dir.y * self.initial_properties.speed),
      z=(dir.z * self.initial_properties.speed),
  })
  self.object:set_acceleration({x=dir.x*-4, y=-self.initial_properties.gravity, z=dir.z*-4})

  core.after(self.initial_properties.lifetime, function() self.object:remove() end)
end



core.register_entity("enderpearl:thrown_ender_pearl", thrown_ender_pearl)



---------------------------
-- ! Callbacks Section ! -- 
---------------------------

-- on_teleport(hit_node)
function enderpearl.on_teleport(func)
  table.insert(callbacks, func)
end



-----------------------
-- ! Utils Section ! -- 
-----------------------

function enderpearl.block_teleport(player, duration)
  if duration then
    core.after(duration, function() 
      if core.get_player_by_name(player:get_player_name()) then
        player:get_meta():set_string("ep_can_teleport", "")
      end
    end)
  end

  player:get_meta():set_string("ep_can_teleport", "false")
end
