# HUD API

`hud_api` manages HUDs by player and a caller-owned key. Showing a HUD again
with the same key updates the existing HUD instead of stacking duplicates.

```lua
hud_api.show(player, "objective", {
    type = "text",
    text = "Capture the middle island",
    color = 0xFFFFFF, -- friendly alias for `number`
    position = {x = 0.5, y = 0.15},
    alignment = {x = 0, y = -1},
})

hud_api.set_text(player, "objective", "Middle island captured")
hud_api.remove(player, "objective")
```

For HUDs with multiple pieces, pass named layers. They are removed together and
can be updated independently.

```lua
hud_api.show(player, "status", {
    background = {
        type = "image",
        text = "hud_api_hud_bg.png",
        position = {x = 0.5, y = 0.5},
        scale = {x = 1.4, y = 1.4},
    },
    text = {
        type = "text",
        text = "Ready!",
        number = 0x80FF80,
        position = {x = 0.5, y = 0.5},
        z_index = 100,
    },
})

hud_api.update(player, "status", {text = "Fight!"}, "text")
```

`show` accepts `duration` (in seconds) and `on_expire` in its fourth argument.
Calling it again without a duration cancels the old expiry. `remove_after` (or
`set_timeout`) can add or replace an expiry later.

```lua
hud_api.show_alert(player, "cleanup_warning", "Cleanup in 10 seconds", {
    duration = 10,
    color = 0xFFB020,
})
```

`show_alert` / `notify` is a top-right panel intended for short warnings. Its
placement is customizable using `position`, `offset`, `alignment`,
`background_scale`, `text_size`, `background`, and normal HUD style options.
The mutable presets live in `hud_api.layouts` (`front`, `actionbar`, and
`top_right`).

Existing calls remain supported:

```lua
hud_api.show_front(player, "Cleaning the area", 0xFF0000, 1)
hud_api.show_actionbar(player, "You are in combat", 0xFB2C36, 1)
hud_api.get(player, "front") -- boolean
hud_api.remove(player, "front")
hud_api.remove_all(player)
```

Use `get_id(player, key)`, `get_ids(player, key)`, and `exists(player, key)`
for new code. `get_id` returns the primary layer; `get_ids` returns a table of
all named layer IDs.
