-- Run as a worldmod's init.lua in a disposable ffa_skywars world.
-- Exercises the real explosion code and engine vectors with controlled ObjectRefs.
local objects = {}
local entities = {}
local effects
local damage_entities = true
local noop = function() return nil end
local api = {
	settings = {
		get = noop,
		get_bool = function(_, key)
			return key == "tnt_revamped.damage_entities" and damage_entities
		end,
	},
	registered_nodes = {},
	registered_entities = entities,
	registered_items = {},
	register_on_mods_loaded = noop,
	register_on_placenode = noop,
	get_player_by_name = noop,
	get_objects_inside_radius = function() return objects end,
	log = noop,
	pos_to_string = function() return "test" end,
}
local env = setmetatable({
	minetest = api,
	tnt = {add_effects = function(_, _, drops) effects = drops end},
	ItemStack = function(name)
		return {
			get_name = function() return name end,
			get_definition = function() return {groups = {}} end,
		}
	end,
}, {__index = _G})
setfenv(assert(loadfile(core.get_modpath("tnt_revamped") .. "/functions.lua")), env)()

local function object(name, player)
	local obj = {pos = vector.new(1, 0, 0), hp = 20, kicks = 0, punches = 0}
	obj.entity = name and {name = name, object = obj, flow_check_step = 5}
	function obj:get_pos() return self.pos end
	function obj:get_luaentity() return self.entity end
	function obj:is_player() return player or false end
	function obj:get_attach() return self.attached end
	function obj:get_velocity() assert(self.pos); return vector.zero() end
	function obj:add_velocity(velocity)
		assert(self.pos)
		self.kicks = self.kicks + 1
		self.velocity = velocity
	end
	function obj:get_hp() return self.hp end
	function obj:set_hp(hp) self.hp = hp end
	function obj:get_armor_groups() assert(self.pos); return {} end
	function obj:punch() assert(self.pos); self.punches = self.punches + 1 end
	return obj
end

local function explode(...)
	objects = {...}
	env.tnt.boom(vector.zero(), {radius = 2, disable_drops = true}, "test", true)
end

local removed = object("throwables:thrown_fireball")
removed.pos = nil
local player = object(nil, true)
local mob = object("test:mob")
explode(removed, player, mob)
assert(player.hp == 4 and player.kicks == 1, "Valid players must still receive damage and knockback")
assert(mob.punches == 1 and mob.kicks == 1, "Valid entities must still receive damage and knockback")

local attached = object("test:armor")
attached.attached = player
local tnt = object("tnt_revamped:empty_tnt_entity")
local missing_entity = object(nil)
explode(attached, tnt, missing_entity)
assert(attached.kicks == 0 and attached.punches == 0, "Attachments must remain protected")
assert(tnt.entity.flow_check_step == 0 and tnt.kicks == 1 and tnt.punches == 0,
	"TNT must keep its special blast physics")
assert(missing_entity.kicks == 0 and missing_entity.punches == 0)

entities["test:removes_self"] = {on_blast = function(self)
	self.object.pos = nil
	return true, true, {"test:drop"}
end}
local self_removing = object("test:removes_self")
explode(self_removing)
assert(self_removing.kicks == 0 and self_removing.punches == 0)
assert(effects["test:drop"], "Drops from a removed entity must be preserved")

local victim = object("test:mob")
entities["test:removes_other"] = {on_blast = function()
	victim.pos = nil
	return false, false, {}
end}
explode(object("test:removes_other"), victim)
assert(victim.kicks == 0 and victim.punches == 0)

entities["test:immune"] = {on_blast = function() return false, false, {} end}
local immune = object("test:immune")
explode(immune)
assert(immune.kicks == 0 and immune.punches == 0)

damage_entities = false
-- Settings are cached when functions.lua is loaded.
setfenv(assert(loadfile(core.get_modpath("tnt_revamped") .. "/functions.lua")), env)()
local underwater = object(nil, true)
explode(underwater)
assert(underwater.hp == 20 and underwater.kicks == 1, "Water damage setting must be respected")

core.log("action", "[tnt_entity_physics] All regression checks passed")
core.register_on_mods_loaded(function() core.request_shutdown("Regression checks passed", false, 0) end)
