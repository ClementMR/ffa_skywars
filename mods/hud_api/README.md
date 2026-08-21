# HUD API

`hud_api` stores one native Luanti HUD per player and per key. Reusing a key
updates the existing HUD; it never creates duplicates.

```lua
hud_api.show(player, "skywars:warning", {
	type = "text",
	text = "Map cleanup in 10s",
	number = 0xFFB020,
	position = {x = 1, y = 0},
	alignment = {x = -1, y = 1},
	offset = {x = -24, y = 24},
}, {duration = 10, background = true})

hud_api.update(player, "skywars:warning", {text = "Map cleanup in 5s"})
hud_api.remove(player, "skywars:warning")
```

There are only three public methods:

- `show(player, key, definition, {duration = seconds, background = true})`
- `update(player, key, changes)`
- `remove(player, key)`

Definitions use Luanti's native HUD fields directly: `type`, `text`,
`number`, `position`, `alignment`, `offset`, `size`, and so on.
