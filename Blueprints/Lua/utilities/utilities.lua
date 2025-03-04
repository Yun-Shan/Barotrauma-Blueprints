if SERVER then return end --prevents it from running on the server



function blue_prints.clean_string(str)
    local cleaned = str
    -- Common control characters
    cleaned = cleaned:gsub("\r", "")      -- Carriage Return
    cleaned = cleaned:gsub("\n", "")      -- Line Feed
    cleaned = cleaned:gsub("\t", "")      -- Tab
    cleaned = cleaned:gsub("\f", "")      -- Form Feed
    cleaned = cleaned:gsub("\b", "")      -- Backspace
    cleaned = cleaned:gsub("\v", "")      -- Vertical Tab
    cleaned = cleaned:gsub("\a", "")      -- Bell (Alert)
    cleaned = cleaned:gsub("\027", "")    -- Escape
    cleaned = cleaned:gsub("\000", "")    -- Null byte
    cleaned = cleaned:gsub("\x1A", "")    -- EOF (Control-Z)
    cleaned = cleaned:gsub("%z", "")      -- Additional null bytes
    cleaned = cleaned:gsub("%c", "")      -- Any remaining control characters
    
    -- Remove Unicode zero-width characters
    cleaned = cleaned:gsub("\u{200B}", "") -- Zero-width space
    cleaned = cleaned:gsub("\u{200C}", "") -- Zero-width non-joiner
    cleaned = cleaned:gsub("\u{200D}", "") -- Zero-width joiner
    cleaned = cleaned:gsub("\u{FEFF}", "") -- Zero-width no-break space (BOM)
    
    return cleaned
end

function blue_prints.escapePercent(str)
    return str:gsub("%%", "%%%%")
end

function blue_prints.getScreenResolution()
    if Screen and Screen.Selected and Screen.Selected.Cam then
        return Screen.Selected.Cam.Resolution
    end
    return nil
end



function blue_prints.get_description_from_xml(xmlString)
    --remove all whitespace
    local function trim(s)
        return s:match("^%s*(.-)%s*$")
    end

    -- Define both patterns
    local newFormatPattern = '<Label[^>]-header="<<<STRINGSTART>>>[dD][eE][sS][cC][rR][iI][pP][tT][iI][oO][nN]<<<STRINGEND>>>"[^>]-body="([^"]*)"[^>]*/>'
    local oldFormatPattern = '<Label[^>]-header="[dD][eE][sS][cC][rR][iI][pP][tT][iI][oO][nN]"[^>]-body="([^"]*)"[^>]*/>'

    -- Try matching new format first
    local body = xmlString:match(newFormatPattern)
    
    -- If not found, try old format
    if not body then
        body = xmlString:match(oldFormatPattern)
    end

    if not body then
        return nil
    end

    --The trim(body) call takes the description text we found and removes any whitespace (spaces, tabs, newlines) from the beginning and end of the text before returning it.
    return trim(body)
end




function blue_prints.get_component_count_from_xml(xmlString)
	local count = 0
	for _ in xmlString:gmatch('<Component.-/>') do
		count = count + 1
	end

    return count
end






function blue_prints.get_xml_content_as_string_from_path(provided_path) 
	
	-- Check if the filename already ends with .txt
    if not string.match(provided_path, "%.txt$") then
        -- Add .txt if it's not already present
        provided_path = provided_path .. ".txt"
    end

	local file_path = (blue_prints.save_path .. "/" .. provided_path)
	local xmlContent, err = blue_prints.readFile(file_path)

	if xmlContent then
		return xmlContent
	else
		print("file not found")
		print("saved designs:")
		blue_prints.print_all_saved_files()
	end
end





function blue_prints.print_requirements_of_circuit(provided_path) 
	
	local xmlContent = blue_prints.get_xml_content_as_string_from_path(provided_path) 

	if xmlContent then
		-- In the usage section:
		local inputs, outputs, components, wires, labels, inputNodePos, outputNodePos = blue_prints.parseXML(xmlContent)
		
		print("This circuit uses: ")
		local identifierCounts = {}

		-- Count occurrences
		for _, component in ipairs(components) do
			--local prefab = ItemPrefab.GetItemPrefab(component.item)
			local identifier = component.item
			identifierCounts[identifier] = (identifierCounts[identifier] or 0) + 1
		end

		-- Print the counts
		for identifier, count in pairs(identifierCounts) do
			print(identifier .. ": " .. count)
		end
	end
end



function blue_prints.check_what_is_needed_for_blueprint(provided_path) 
	
	local xmlContent = blue_prints.get_xml_content_as_string_from_path(provided_path) 

	if xmlContent then
		-- In the usage section:
		local inputs, outputs, components, wires, labels, inputNodePos, outputNodePos = blue_prints.parseXML(xmlContent)
		
		-- Check inventory for required components
		local missing_components = blue_prints.check_inventory_for_requirements(components)

		local all_needed_items_are_present = true
		for _, count in pairs(missing_components) do
			if count > 0 then
				all_needed_items_are_present = false
				break
			end
		end
		
		if all_needed_items_are_present then
			print("All required components are present!")
		else
			print("You are missing: ")
			for name, count in pairs(missing_components) do
				if count > 0 then
					print(name .. ": " .. count)
				end
			end
			print("You can also use an equivalent amount of FPGAs")
		end
	end

	
end


function blue_prints.get_components_currently_in_circuitbox(passed_circuitbox) 
	
	local components = passed_circuitbox.GetComponentString("CircuitBox").Components
	
	local resourceCounts = {}
	for i, component in pairs(components) do
		--print(tostring(component.UsedResource.Identifier))
		resourceCounts[tostring(component.UsedResource.Identifier)] = (resourceCounts[tostring(component.UsedResource.Identifier)] or 0) + 1
    end
	
	return resourceCounts
end


function blue_prints.getFurthestRightElement(components, labels, inputNodePos, outputNodePos)
    local furthestRight = {x = -math.huge, y = 0, element = nil, type = nil}

	local offset_adjustment = 256

    -- Check components
    for _, component in ipairs(components) do
        if component.position.x + offset_adjustment > furthestRight.x then
            furthestRight.x = component.position.x + offset_adjustment
            furthestRight.y = component.position.y
            furthestRight.element = component
            furthestRight.type = "component"
        end
    end

    -- Check labels
    for _, label in ipairs(labels) do
		--print(label.header, label.size.width)
        local rightEdge = label.position.x + (label.size.width / 2)
        if rightEdge > furthestRight.x then
            furthestRight.x = rightEdge
            furthestRight.y = label.position.y
            furthestRight.element = label
            furthestRight.type = "label"
        end
    end

    -- Check input node
    if inputNodePos and inputNodePos.x + offset_adjustment > furthestRight.x then --input and output nodes dont check width
        furthestRight.x = inputNodePos.x + offset_adjustment
        furthestRight.y = inputNodePos.y
        furthestRight.element = inputNodePos
        furthestRight.type = "inputNode"
    end

    -- Check output node
    if outputNodePos and outputNodePos.x + offset_adjustment > furthestRight.x then
        furthestRight.x = outputNodePos.x + offset_adjustment
        furthestRight.y = outputNodePos.y
        furthestRight.element = outputNodePos
        furthestRight.type = "outputNode"
    end

    return furthestRight
end



function blue_prints.print_all_saved_files()
    local saved_files = blue_prints.getFiles(blue_prints.save_path)
    
    for name, value in pairs(saved_files) do
        if string.match(value, "%.txt$") then
            local filename = value:match("([^/\\]+)$") -- Match after last slash or backslash
            local filename = string.gsub(filename, "%.txt$", "") --cut out the .txt at the end
            
            local xml_of_file = blue_prints.readFileContents(value)
            local description_of_file = blue_prints.get_description_from_xml(xml_of_file)
            local number_of_components_in_file = blue_prints.get_component_count_from_xml(xml_of_file)
            
            print("-------------")
            
            local print_string = '‖color:white‖' .. filename ..  '‖end‖' .. "  -  (" .. number_of_components_in_file .. " fpgas) "
            
            if description_of_file ~= nil then
                print_string = print_string .. " -  " ..  '‖color:yellow‖' .. description_of_file ..  '‖end‖'
            end
            print(print_string)
        end
    end
end


function blue_prints.readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Failed to open file: " .. path
    end
    local content = file:read("*all")
    file:close()
    return content
end


function blue_prints.isInteger(str)
    return str and not (str == "" or str:find("%D"))
end

function blue_prints.isFloat(str)
    local n = tonumber(str)
    return n ~= nil and math.floor(n) ~= n
end



function blue_prints.removeKeyFromTable(tbl, keyToRemove)
    local newTable = {}
    for k, v in pairs(tbl) do
        if k ~= keyToRemove then
            newTable[k] = v
        end
    end
    return newTable
end



function blue_prints.hexToRGBA(hex)
    -- Remove the '#' if present
    hex = hex:gsub("#", "")
    
    -- Check if it's a valid hex color
    if #hex ~= 6 and #hex ~= 8 then
        return nil, "Invalid hex color format"
    end
    
    -- Convert hex to decimal
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = 255
    
    -- If alpha channel is provided
    if #hex == 8 then
        a = tonumber(hex:sub(7, 8), 16)
    end
    
    -- Return Color object
    return Color(r, g, b, a)
end




function blue_prints.getNthValue(tbl, n)
    local count = 0
    for key, value in pairs(tbl) do
        count = count + 1
        if count == n then
            return value
        end
    end
    return nil  -- Return nil if there are fewer than n items
end






function blue_prints.string_to_bool(passed_string)
    -- Convert to lower case for case-insensitive comparison
    local lower_string = string.lower(passed_string)
    
    -- Check for common true values
    if lower_string == "true" or lower_string == "1" then
        return true
    elseif lower_string == "false" or lower_string == "0" then
        return false
    else
        -- Handle unexpected cases (could also return nil or error)
        error("Invalid string for boolean conversion: " .. passed_string)
    end
end



function blue_prints.get_circuit_box_lock_status()
    -- First verify we have a selected circuitbox
    if blue_prints.most_recent_circuitbox == nil then
        print("No circuitbox detected")
        return false
    end
    
    -- Get the CircuitBox component
    local circuit_box = blue_prints.most_recent_circuitbox.GetComponentString("CircuitBox")
    if circuit_box == nil then
        print("Could not find CircuitBox component")
        return false
    end
    
    -- Return true if either permanently or temporarily locked
    return circuit_box.Locked or circuit_box.TemporarilyLocked
end
-- Usage example:
-- local is_locked = blue_prints.get_circuit_box_lock_status()



function blue_prints.count_circuit_elements_in_box()
    if blue_prints.most_recent_circuitbox == nil then
        print("no circuitbox detected")
        return 0, 0, 0
    end

    local circuit_box = blue_prints.most_recent_circuitbox.GetComponentString("CircuitBox")
    
    -- Initialize counts to 0
    local num_components = 0
    local num_labels = 0
    local num_wires = 0

    -- Only count if the collections exist
    if circuit_box.Components then
        num_components = #circuit_box.Components
    end

    if circuit_box.Labels then
        num_labels = #circuit_box.Labels
    end

    if circuit_box.Wires then
        num_wires = #circuit_box.Wires
    end

    return num_components, num_labels, num_wires
end

function blue_prints.calculate_clear_delay()
    -- Get current counts of all elements
    local num_components, num_labels, num_wires = blue_prints.count_circuit_elements()

    -- Calculate individual delays for each type
    local component_delay = 0
    local label_delay = 0 
    local wire_delay = 0

    -- Only calculate delays if we have elements to clear
    if num_components > 0 then
        component_delay = math.ceil(num_components / blue_prints.component_batch_size) * blue_prints.time_delay_between_loops
    end
    
    if num_labels > 0 then
        label_delay = math.ceil(num_labels / blue_prints.component_batch_size) * blue_prints.time_delay_between_loops
    end
    
    if num_wires > 0 then
        wire_delay = math.ceil(num_wires / blue_prints.component_batch_size) * blue_prints.time_delay_between_loops
    end

    -- Get minimum delay and add buffer time
    --wire delay doesnt matter because wires are automatically removed when comps are removed
    --there is some extra buffer in there to account for wires directly from input to output
    local time_delay = component_delay + label_delay + 500 
    
    return time_delay
end

--save a reference to the most recently interacted circuit box
Hook.Patch("Barotrauma.Items.Components.CircuitBox", "AddToGUIUpdateList", function(instance, ptable)
	blue_prints.most_recent_circuitbox = instance.Item
end, Hook.HookMethodType.After)

