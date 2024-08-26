--this is the entry point for the code. This runs all other scripts.


--get the local path and save it as a global. only autorun files can get the path in this way!
blue_prints = {}
blue_prints.path = ...
blue_prints.save_path = "LocalMods/Blueprints_saved_blueprints"

blue_prints.most_recent_circuitbox = nil 
blue_prints.time_delay_between_loops = 100

dofile(blue_prints.path .. "/Lua/cs_required_warning.lua")

if CSActive then --CSActive is if csharp scripts are enabled. This mod requires them.
	dofile(blue_prints.path .. "/Lua/register_types.lua")
	dofile(blue_prints.path .. "/Lua/first_time_setup.lua")
	dofile(blue_prints.path .. "/Lua/utilities.lua")
	dofile(blue_prints.path .. "/Lua/save_blueprint.lua")
	dofile(blue_prints.path .. "/Lua/load_blueprint.lua")
	dofile(blue_prints.path .. "/Lua/delete_blueprint.lua")
	dofile(blue_prints.path .. "/Lua/commands.lua")
end 

--TODO list
--add buttons to control the mod instead of the text interface

