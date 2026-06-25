return function(sourceTable, keysToIgnore, separateArrayElements)
	local filteredDictionary = {}
	local separatedArray = if separateArrayElements then {} else nil
	for key, value in sourceTable do
		if not table.find(keysToIgnore, key) and (not separateArrayElements or typeof(key) ~= "number") then
			filteredDictionary[key] = value
		end

		if separateArrayElements and typeof(key) == "number" then
			table.insert(separatedArray, value)
		end
	end

	return filteredDictionary, separatedArray
end
