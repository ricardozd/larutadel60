local _, ns = ...

-- Localized strings. A missing translation returns its own key, so the UI never shows nil.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
