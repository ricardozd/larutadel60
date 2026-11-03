local Client = require("support.client")

describe("TOC (acceptance)", function()
	it("targets the WoW Forever interface 16001", function()
		assert.are.equal("16001", Client.tocField("Interface"))
	end)

	it("declares LaRutaDel60DB as SavedVariables", function()
		assert.are.equal("LaRutaDel60DB", Client.tocField("SavedVariables"))
	end)

	it("keeps the _Forever TOC identical to the base TOC", function()
		assert.are.equal(Client.readFile(Client.TOC), Client.readFile(Client.FOREVER_TOC))
	end)

	it("only references files that exist", function()
		for _, path in ipairs(Client.addonFiles()) do
			local handle = io.open(path, "r")
			assert.is_not_nil(handle, "missing " .. path)
			handle:close()
		end
	end)
end)
