
require("game.config")
require("framework.init")

--设置为一个类
local MyApp = class("MyApp", cc.mvc.AppBase)

function MyApp:ctor()
    MyApp.super.ctor(self,"MyApp","game.app");
    --print(self.packageRoot);
end

function MyApp:run()
	--添加文件搜索路径--
	--local path = device.writablePath.."/upd/res/";
	--添加搜索路径--
	--CCFileUtils:sharedFileUtils():addSearchPath(path);
	--print(self.packageRoot);
    self:enterScene("MainScene")
end

return MyApp
