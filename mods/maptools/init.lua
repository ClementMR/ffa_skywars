--[[
=====================================================================
** Map Tools **
By Calinou.

Copyright © 2012-2019 Hugo Locurcio and contributors.
Licensed under the zlib license. See LICENSE.md for more information.
=====================================================================
--]]

maptools = {}

local modpath = core.get_modpath("maptools")

S = core.get_translator("maptools")

dofile(modpath .. "/config.lua")
dofile(modpath .. "/aliases.lua")
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/tools.lua")
