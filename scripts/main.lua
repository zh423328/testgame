--添加调试代码--
require("mobdebug").start()

function __G__TRACKBACK__(errorMessage)
    print("----------------------------------------")
    print("LUA ERROR: " .. tostring(errorMessage) .. "\n")
    print(debug.traceback("", 2))
    print("----------------------------------------")
end

--启动程序--启动后执行MyApp脚本 --
--require("app.MyApp").new():run()
--require("update")


CCFileUtils:sharedFileUtils():purgeCachedEntries();
--加载launcher.zip--
--CCLuaLoadChunksFromZIP("lib/launcher.zip")
package.loaded["launcher.launcher"] = nil
require("launcher.launcher")
