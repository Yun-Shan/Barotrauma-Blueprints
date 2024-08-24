if SERVER then return end --prevents it from running on the server





















-- Function to extract components and their IDs
local function extractComponents(xmlString)
    local components = {}
    for id, position in xmlString:gmatch('<Component id="(%d+)" position="([^"]+)"') do
        components[#components + 1] = {id = tonumber(id), position = position}
    end
    table.sort(components, function(a, b) return a.id < b.id end)
    return components
end

-- Function to create ID mapping
local function createIdMapping(components)
    local idMap = {}
    local newId = 0
    for _, component in ipairs(components) do
        idMap[component.id] = newId
        newId = newId + 1
    end
    return idMap
end

-- Function to update component IDs and wire targets
local function updateXml(xmlString, idMap)
    -- Update component IDs
    xmlString = xmlString:gsub('<Component id="(%d+)"', function(id)
        return string.format('<Component id="%d"', idMap[tonumber(id)])
    end)
    
    -- Update wire targets
    xmlString = xmlString:gsub('target="(%d*)"', function(target)
        if target ~= "" then
            local newTarget = idMap[tonumber(target)]
            if newTarget then
                return string.format('target="%d"', newTarget)
            else
                print("Warning: No mapping found for target " .. target)
                return string.format('target="%s"', target)
            end
        else
            return 'target=""'
        end
    end)
    
    return xmlString
end

-- Main function to renumber components and update wire targets
local function renumberComponents(xmlString)
    local components = extractComponents(xmlString)
    local idMap = createIdMapping(components)
    return updateXml(xmlString, idMap)
end



























local function find_id_within_component(component_string)

	-- Define the pattern to match the id attribute value
	local pattern = 'id="(%d+)"'

	-- Extract the id value using string.match
	local id_value = string.match(component_string, pattern)

	-- Print the result
	if id_value then
		return id_value
	else
		return ""
	end

end


local function find_specific_component(xmlContent, target_component)
    -- Split the XML content into lines
    local lines = {}
    for line in string.gmatch(xmlContent, "[^\r\n]+") do
        table.insert(lines, line)
    end

    -- Define the pattern to match the component
    local pattern = "<Component.-/->"

    -- Initialize counters
    local count = 0

    -- Iterate through each line to find the specific component
    for i, line in ipairs(lines) do
        -- Check for components in the current line
        for component in string.gmatch(line, pattern) do
            count = count + 1
            if count == target_component then
                -- Return both the line number and the line content
                return i, line
            end
        end
    end

    -- Return nil, nil if the component was not found
    return nil, nil
end


local function count_component_number(xmlContent)

	-- Define the pattern to match the component
	local pattern = "<Component.-/->"

	-- Initialize counter
	local count = 0

	-- Use string.gmatch to iterate over all matches
	for _ in string.gmatch(xmlContent, pattern) do
		count = count + 1
	end
	
	return count

end


local function swap_lines_in_string(xmlContent, line1, line2)
	-- Split the text into lines
	local lines = {}
	for line in string.gmatch(xmlContent, "[^\r\n]+") do
		table.insert(lines, line)
	end

	-- Swap the specified lines
	if line1 <= #lines and line2 <= #lines then
		lines[line1], lines[line2] = lines[line2], lines[line1]
	else
		print("Error: Line numbers out of range.")
	end

	-- Join the lines back into a single string
	local swapped_text = table.concat(lines, "\n")

	return swapped_text
end



local function put_components_in_order(xmlContent)
	
	local something_in_xml_changed = false
	local number_of_components = count_component_number(xmlContent)
	
	for i = 1, number_of_components-1 do
		local first_line_number, first_line_content = find_specific_component(xmlContent, i)
		local second_line_number, second_line_content = find_specific_component(xmlContent, i+1)
		
		--print(first_line_content)
		--print(second_line_content)
		--print("-----")
		
		local first_id = find_id_within_component(first_line_content)
		local second_id = find_id_within_component(second_line_content)
		
		if tonumber(first_id) > tonumber(second_id) then
			--print("comparing" .. first_id .. " to " .. second_id)
			xmlContent = swap_lines_in_string(xmlContent, first_line_number, second_line_number)
			something_in_xml_changed = true
		end
	end
	
	if something_in_xml_changed then return put_components_in_order(xmlContent) end
	
	--print(xmlContent)
	
	return xmlContent

end






local function add_attribute_to_component_in_xml(xmlContent, targetId, attributeString)
	-- Function to add the attribute to the specific Component element
	local function modifyComponent(componentString)
		local id = componentString:match('id="(%d+)"')
		if id and tonumber(id) == targetId then
			local escapedAttributeString = attributeString:gsub('%%', '%%%%')
			return componentString:gsub('/>$', ' ' .. escapedAttributeString .. ' />')
		else
			return componentString
		end
	end

	-- Find the CircuitBox element
	local circuitBoxStart, circuitBoxEnd = xmlContent:find('<CircuitBox.->')
	local circuitBoxEndTag = xmlContent:find('</CircuitBox>', circuitBoxEnd)
	if not circuitBoxStart or not circuitBoxEndTag then
		print("CircuitBox element not found")
		return xmlContent
	end

	-- Extract the CircuitBox content
	local circuitBoxContent = xmlContent:sub(circuitBoxEnd + 1, circuitBoxEndTag - 1)

	-- Modify the specific Component element
	local modifiedCircuitBoxContent = circuitBoxContent:gsub('<Component.-/>', modifyComponent)

	-- Replace the original CircuitBox content with the modified content
	return xmlContent:sub(1, circuitBoxEnd) .. modifiedCircuitBoxContent .. xmlContent:sub(circuitBoxEndTag)
end


function blue_prints.save_blueprint(provided_path)
	if Character.Controlled == nil then print("you dont have a character") return end
	if blue_prints.most_recent_circuitbox == nil then print("no circuitbox detected") return end
	
    -- Check if the filename already ends with .txt
    if not string.match(provided_path, "%.txt$") then
        -- Add .txt if it's not already present
        provided_path = provided_path .. ".txt"
    end

	local file_path = (blue_prints.save_path .. "/" .. provided_path)
	
	local character = Character.Controlled

    
	local sacrificial_xml = XElement("Root")
	blue_prints.most_recent_circuitbox.Save(sacrificial_xml)
	local circuitbox_xml = tostring(sacrificial_xml)

	--the xml does not contain all the component info, so we have to add it
	local components = blue_prints.most_recent_circuitbox.GetComponentString("CircuitBox").Components
	
	for i, component in ipairs(components) do
		
		--add the class name to component
		local class_name = nil
		for value in component.Item.Components do
			local target_string = tostring(value)
			local target_string = target_string:match("([^%.]+)$") --cut off anything before the last period
			if string.find(target_string, "Component") then
				--print("The string contains 'Component'")
				class_name = target_string
				break
			end
        end
		if class_name ~= nil then 
			circuitbox_xml = add_attribute_to_component_in_xml(circuitbox_xml, component.ID, 'Class="' .. class_name .. '"')
		else
			print("Error: couldnt find class name! Report this bug on the workshop page please! Component causing the problem: " .. tostring(component.Item.Prefab.Identifier))
		end
		
		--add any values stored inside the component
		local my_editables =  component.Item.GetInGameEditableProperties(false)
		for tuple in my_editables do 
			--print(tuple.Item2.name, ' = ', tuple.Item2.GetValue(tuple.Item1)) 
			circuitbox_xml = add_attribute_to_component_in_xml(circuitbox_xml, component.ID, tostring(tuple.Item2.name) .. '="' .. tostring(tuple.Item2.GetValue(tuple.Item1)) .. '"')
		end
		
		--add the item prefab itself
		local parsed_item_string = 'item="' .. tostring(component.Item.Prefab.Identifier) .. '"'
		circuitbox_xml = add_attribute_to_component_in_xml(circuitbox_xml, component.ID, parsed_item_string)
		
    end
	
	--now some cleanup to deal with deleted components
	circuitbox_xml = put_components_in_order(circuitbox_xml)
	circuitbox_xml = renumberComponents(circuitbox_xml)
	

	-- Open the file for writing
	local file = io.open(file_path, "w")

	-- Check if the file was successfully opened
	if file then
		-- Write the XML string to the file
		file:write(circuitbox_xml)
		
		-- Close the file
		file:close()
		
		print("blueprint saved to " .. file_path)
		return
	else
		print("Error: Could not open file for writing")
	end
end

