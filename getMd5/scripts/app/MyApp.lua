
require("config")
require("framework.init")
require("framework.shortcodes")
require("framework.cc.init")

local MyApp = class("MyApp", cc.mvc.AppBase)

function MyApp:ctor()
    MyApp.super.ctor(self)
end

function MyApp:run()
	CCFileUtils:sharedFileUtils():addSearchPath("res/")
    mk = require("mkflist2")
    mk:run("files")
    self:enterScene("MainScene")
end

return MyApp
