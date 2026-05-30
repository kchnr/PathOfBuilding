LUA      := luajit
LUAROCKS := luarocks --lua-version 5.1
TREE     := lua_modules
ROCKFILE := pathofbuilding-dev-1.rockspec
ROCKOPTS := --tree $(TREE)
LUAENV   := eval $$($(LUAROCKS) path $(ROCKOPTS))

.PHONY: setup test test-system test-integration test-ui test-health test-all test-run-headless clean

setup:
	@echo "Installing runtime dependencies to $(TREE)..."
	$(LUAROCKS) install --only-deps $(ROCKFILE) $(ROCKOPTS)
	@echo "Done."

# ADR 0002: default = models + logic (< 1s)
test:
	$(LUAENV) && busted --lua=$(LUA)

# Old system tests (full app boot) — kept during migration
test-system:
	$(LUAENV) && busted --lua=$(LUA) --run=system

# ADR 0002: integration tests (adapters + api)
test-integration:
	@echo "Not yet — no adapter/api tests exist."

# ADR 0002: UI tests
test-ui:
	@echo "Not yet — no UI layer tests exist."

# ADR 0002: health checks (CI gate)
test-health:
	@echo "Not yet — no health checks exist."

# Full CI pipeline
test-all: test test-system

test-run-headless:
	$(LUAENV) && \
	cd src && \
	LUA_PATH="./?.lua;./?/init.lua;../runtime/lua/?.lua;../runtime/lua/?/init.lua;$$LUA_PATH" \
	$(LUA) HeadlessWrapper.lua

clean:
	rm -rf $(TREE)
