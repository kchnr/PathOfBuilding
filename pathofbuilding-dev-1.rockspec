rockspec_format = "3.0"
package = "pathofbuilding"
version = "dev-1"

source = {
   url = ".",
}

description = {
    summary = "Path of Building - Offline build planner for Path of Exile",
    homepage = "https://github.com/PathOfBuildingCommunity/PathOfBuilding",
    license = "MIT",
}

dependencies = {
   "lua == 5.1",
   "luautf8",
}

test_dependencies = {
   "busted",
}

build = {
   type = "builtin",
   modules = {}
}
