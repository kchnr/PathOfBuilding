LUA      := luajit
LUAROCKS := $(CURDIR)/luarocks

.PHONY: setup setup-dev test run-headless clean

setup:
	@echo "Installing runtime dependencies to lua_modules..."
	$(LUAROCKS) make --tree lua_modules

setup-dev: setup
	@echo "Installing test dependencies to lua_modules..."
	$(LUAROCKS) install busted --tree lua_modules

test:
	eval $$($(LUAROCKS) path) && busted --lua=$(LUA)

run-headless:
	eval $$($(LUAROCKS) path) && \
	cd src && \
	LUA_PATH="./?.lua;./?/init.lua;../runtime/lua/?.lua;../runtime/lua/?/init.lua;$$LUA_PATH" \
	$(LUA) HeadlessWrapper.lua

clean:
	rm -rf lua_modules
