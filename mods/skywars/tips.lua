local S = core.get_translator(core.get_current_modname())

local MESSAGE_INTERVAL = 60 * 3
local messages = {
	{kind = "tip", text = "Use blocks to gain height, create cover, and control the fight."},
	{kind = "tip", text = "Keep moving after a fight: another player may already be nearby."},
	{kind = "tip", text = "Golden apples can turn a close fight around. Use them at the right moment."},
	{kind = "tip", text = "A clean inventory saves time in combat. Keep your weapon and blocks easy to reach."},
	{kind = "tip", text = "The /stats command shows your playtime, kills, deaths and ranking."},
	{kind = "tip", text = "The /top command opens the leaderboards for playtime, kills, deaths or K/D."},
	{kind = "rule", text = "Do not use cheats, exploits, or modified clients that give an unfair advantage."},
	{kind = "rule", text = "Be respectful. Harassment, hate speech, and spam are not allowed."},
	{kind = "rule", text = "Do not evade bans or punishments with alternate accounts."},
	{kind = "rule", text = "Do not build outside the active map or deliberately disrupt map management."},
	{kind = "rule", text = "Report bugs and exploits to the staff; do not abuse them."},
}

local labels = {
	tip = {text = "[Tip]", color = "#60A5FA"},
	rule = {text = "[Rule]", color = "#FB7185"},
}

local elapsed = 0
local message_index = 0

local function send_next_message()
	message_index = message_index % #messages + 1
	local message = messages[message_index]
	local label = labels[message.kind]
	core.chat_send_all(
		core.colorize(label.color, S(label.text))
		.. " " .. core.colorize("#E2E8F0", S(message.text))
	)
end

core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < MESSAGE_INTERVAL then
		return
	end
	elapsed = 0
	send_next_message()
end)
