if SERVER then return end -- we don't want server to run GUI code.

local resolution = blue_prints.getScreenResolution()
local run_once_at_start = false

local function check_and_rebuild_frame()
	local new_resolution = blue_prints.getScreenResolution()
	if new_resolution ~= resolution or run_once_at_start == false then

        local spacer = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.04), blue_prints.gui_button_frame_list.Content.RectTransform), "", nil, nil, GUI.Alignment.Center)

        local button = GUI.Button(GUI.RectTransform(Vector2(1, 0.1), blue_prints.gui_button_frame_list.Content.RectTransform), "Clear Circuitbox", GUI.Alignment.Center, "GUIButtonSmall")

		button.OnClicked = function ()
			
			local message_box = GUI.MessageBox('Are you sure you want to clear the box?', 'This will remove all components, labels and wires.', {'Cancel', 'Clear Box'}) 
			
			local cancel_button = nil
			local clear_button = nil
			
			if message_box.Buttons[0] == nil then --this is if no one has registered it. If some other mod registers it I dont want it to break.
				cancel_button = message_box.Buttons[1]
				clear_button = message_box.Buttons[2]
			else --if its been registered, it will behave as a csharp table
				cancel_button = message_box.Buttons[0]
				clear_button = message_box.Buttons[1]
			end
			
			clear_button.Color = Color(160, 160, 255) -- Base color (more blue)
			clear_button.HoverColor = Color(190, 190, 255) -- Lighter blue when hovering

			cancel_button.OnClicked = function ()
				message_box.Close()
			end
			
			clear_button.OnClicked = function ()
				blue_prints.clear_circuitbox()
				GUI.AddMessage('Circuitbox Cleared', Color.White)
				message_box.Close()
			end
			
			
			
		end

		resolution = new_resolution
		run_once_at_start = true
	end
end


Hook.Patch("Barotrauma.Items.Components.CircuitBox", "AddToGUIUpdateList", function()
	check_and_rebuild_frame()
end, Hook.HookMethodType.After)
