-- This test is for the layer-specific test infrastructure.
-- It runs under plain busted (no HeadlessWrapper) via `make test`.
-- @tags layer

describe("test_helper", function()
	it("require('Data.Global') returns a table with ModFlag", function()
		local Global = require("Data.Global")
		assert.is_table(Global)
		assert.is_not_nil(Global.ModFlag)
		assert.is_table(Global.ModFlag)
		assert.equals(Global.ModFlag.Attack, 0x00000001)
	end)
end)
