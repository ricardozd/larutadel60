local Client = require("support.client")

local PREFIX = "La Ruta del 60: "

local function routeCount()
	local pipe = assert(io.popen("find data/routes -name '*.json' | wc -l"))
	local count = tonumber(pipe:read("*a"):match("%d+"))
	pipe:close()
	return count
end

describe("Addon (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	it("greets once on login in WoW Forever (enUS)", function()
		local client = Client.boot()
		client.login()
		assert.are.same({ PREFIX .. "Loaded. Type /ruta for info." }, client.messages())
	end)

	it("warns first when the client is not WoW Forever", function()
		local client = Client.boot({ projectId = 1 })
		client.login()
		assert.are.same({
			PREFIX .. "Warning: this client is not WoW Forever; guides may be wrong.",
			PREFIX .. "Loaded. Type /ruta for info.",
		}, client.messages())
	end)

	it("reports the TOC version and the number of guides on /ruta", function()
		local client = Client.boot()
		client.login()
		client.slash("/ruta")
		local messages = client.messages()
		local expected =
			string.format("%sVersion %s - %d guide(s) loaded.", PREFIX, Client.tocField("Version"), routeCount())
		assert.are.equal(expected, messages[#messages])
	end)

	it("speaks Spanish on an esES client", function()
		local client = Client.boot({ locale = "esES" })
		client.login()
		client.slash("/ruta")
		assert.are.same({
			PREFIX .. "Cargado. Escribe /ruta para más info.",
			string.format("%sVersión %s - %d guía(s) cargada(s).", PREFIX, Client.tocField("Version"), routeCount()),
		}, client.messages())
	end)

	it("speaks Spanish on an esMX client", function()
		local client = Client.boot({ locale = "esMX", projectId = 1 })
		client.login()
		assert.are.same({
			PREFIX .. "Aviso: este cliente no es WoW Forever; las guías pueden fallar.",
			PREFIX .. "Cargado. Escribe /ruta para más info.",
		}, client.messages())
	end)

	it("creates saved variables on the first login", function()
		local client = Client.boot()
		client.login()
		assert.is_table(LaRutaDel60DB)
	end)

	it("keeps saved variables from a previous session", function()
		local client = Client.boot({ savedVariables = { keep = true } })
		client.login()
		assert.is_true(LaRutaDel60DB.keep)
	end)

	it("creates no globals besides the allowed ones", function()
		local client = Client.boot()
		client.login()
		client.slash("/ruta")
		assert.are.same({ "LaRutaDel60DB", "SLASH_LARUTADEL601" }, client.newGlobals())
		assert.are.same({ "LARUTADEL60" }, client.newSlashCommands())
	end)
end)
