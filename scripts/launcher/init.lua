
package.loaded["launcher.config"] = nil
require("launcher.config")
require("lfs")

Launcher = {}

Launcher.server = "http://10.10.10.82:8080/quickhttp/"
Launcher.fListName = "flist"
Launcher.libDir = "lib/"
Launcher.lcherZipName = "launcher.zip"
Launcher.updateFilePostfix = ".upd"

local sharedApplication = CCApplication:sharedApplication()
local sharedDirector = CCDirector:sharedDirector()
local target = sharedApplication:getTargetPlatform()

Launcher.platform    = "unknown"
Launcher.model       = "unknown"

local sharedApplication = CCApplication:sharedApplication()
local target = sharedApplication:getTargetPlatform()
if target == kTargetWindows then
    Launcher.platform = "windows"
elseif target == kTargetMacOS then
    Launcher.platform = "ios"
elseif target == kTargetAndroid then
    Launcher.platform = "android"
elseif target == kTargetIphone or target == kTargetIpad then
    Launcher.platform = "ios"
    if target == kTargetIphone then
        Launcher.model = "iphone"
    else
        Launcher.model = "ipad"
    end
end

-- check device screen size
local glview = sharedDirector:getOpenGLView()
local size = glview:getFrameSize()
local w = size.width
local h = size.height

if CONFIG_SCREEN_WIDTH == nil or CONFIG_SCREEN_HEIGHT == nil then
    CONFIG_SCREEN_WIDTH = w
    CONFIG_SCREEN_HEIGHT = h
end

if not CONFIG_SCREEN_AUTOSCALE then
    if w > h then
        CONFIG_SCREEN_AUTOSCALE = "FIXED_HEIGHT"
    else
        CONFIG_SCREEN_AUTOSCALE = "FIXED_WIDTH"
    end
else
    CONFIG_SCREEN_AUTOSCALE = string.upper(CONFIG_SCREEN_AUTOSCALE)
end

local scale, scaleX, scaleY

if CONFIG_SCREEN_AUTOSCALE then
    if type(CONFIG_SCREEN_AUTOSCALE_CALLBACK) == "function" then
        scaleX, scaleY = CONFIG_SCREEN_AUTOSCALE_CALLBACK(w, h, Launcher.model)
    end

    if not scaleX or not scaleY then
        scaleX, scaleY = w / CONFIG_SCREEN_WIDTH, h / CONFIG_SCREEN_HEIGHT
    end

    if CONFIG_SCREEN_AUTOSCALE == "FIXED_WIDTH" then
        scale = scaleX
        CONFIG_SCREEN_HEIGHT = h / scale
    elseif CONFIG_SCREEN_AUTOSCALE == "FIXED_HEIGHT" then
        scale = scaleY
        CONFIG_SCREEN_WIDTH = w / scale
    else
        scale = 1.0
    end

    glview:setDesignResolutionSize(CONFIG_SCREEN_WIDTH, CONFIG_SCREEN_HEIGHT, kResolutionNoBorder)
end

local winSize = sharedDirector:getWinSize()
Launcher.size = {width = winSize.width, height = winSize.height}
Launcher.width              = Launcher.size.width
Launcher.height             = Launcher.size.height
Launcher.cx                 = Launcher.width / 2
Launcher.cy                 = Launcher.height / 2

Launcher.writablePath = CCFileUtils:sharedFileUtils():getWritablePath()

if Launcher.platform == "android" then
    --java包名--
	Launcher.javaClassName = "com/jiuwanle/zhanhuang/luajavabridge/Luajavabridge"
	Launcher.luaj = {}
	function Launcher.luaj.callStaticMethod(className, methodName, args, sig)
        return CCLuaJavaBridge.callStaticMethod(className, methodName, args, sig)
    end
elseif Launcher.platform == "ios" then
    --oc-
	Launcher.ocClassName = "LuaObjcFun"
	Launcher.luaoc = {}
	function Launcher.luaoc.callStaticMethod(className, methodName, args)
	    local ok, ret = CCLuaObjcBridge.callStaticMethod(className, methodName, args)
	    if not ok then
	        local msg = string.format("luaoc.callStaticMethod(\"%s\", \"%s\", \"%s\") - error: [%s] ",
	                className, methodName, tostring(args), tostring(ret))
	        if ret == -1 then
	            printError(msg .. "INVALID PARAMETERS")
	        elseif ret == -2 then
	            printError(msg .. "CLASS NOT FOUND")
	        elseif ret == -3 then
	            printError(msg .. "METHOD NOT FOUND")
	        elseif ret == -4 then
	            printError(msg .. "EXCEPTION OCCURRED")
	        elseif ret == -5 then
	            printError(msg .. "INVALID METHOD SIGNATURE")
	        else
	            printError(msg .. "UNKNOWN")
	        end
	    end
	    return ok, ret
	end
end

--是否需要更新
Launcher.needUpdate = true

--工作类型--
Launcher.workerType  =  { UNCOMPRESS = 0, UPDATE = 1}
--请求类型
Launcher.RequestType = { LAUNCHER = 0, FLIST = 1, RES = 2 }
--更新结果
Launcher.UpdateRetType = { SUCCESSED = 0, NETWORK_ERROR = 1, MD5_ERROR = 2, OTHER_ERROR = 3 }

function lcher_handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

--类--
function lcher_class(classname, super)
    local superType = type(super)
    local cls

    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}

        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end

        cls.__cname = classname
        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do
                instance[k] = v 
            end
            instance.class = cls
            instance:ctor(...)
            return instance
        end

    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super
        else
            cls = {ctor = function() end}
        end

        cls.__cname = classname
        cls.__ctype = 2 -- lua
        cls.__index = cls

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end

    return cls
end

--返回字符串16进制格式--
function Launcher.hex(s)
    s = string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
    return s
end

--文件是否存在--
function Launcher.fileExists(path)
    return CCFileUtils:sharedFileUtils():isFileExist(path)
end

--读取文件--
function Launcher.readFile(path)
    local file = io.open(path, "rb")
    if file then
        local content = file:read("*all")
        io.close(file)
        return content
    end
    return nil
end

--写文件--
function Launcher.writefile(path, content, mode)
    mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end


--移除路径所有的文件--
function Launcher.removePath(path)
    local mode = lfs.attributes(path, "mode")
    if mode == "directory" then
        local dirPath = path.."/"
        for file in lfs.dir(dirPath) do
            if file ~= "." and file ~= ".." then 
                local f = dirPath..file 
                Launcher.removePath(f)
            end 
        end
        os.remove(path)
    else
        os.remove(path)
    end
end

--创建一个文件--
function Launcher.mkDir(path)
    if not Launcher.fileExists(path) then
        return lfs.mkdir(path)
    end
    return true
end

--执行zip或其他lua--
function Launcher.doFile(path)
    local fileData = CZHelperFunc:getFileData(path)
    local fun = loadstring(fileData)
    local ret, flist = pcall(fun)
    if ret then
        return flist
    end

    return flist
end


--取文件内容的md5--
function Launcher.fileDataMd5(fileData)
	if fileData ~= nil then
		return CCCrypto:MD5(Launcher.hex(fileData), false)
	else
		return nil
	end
end

--取文件内容的md5--
function Launcher.fileMd5(filePath)
	local data = Launcher.readFile(filePath)
	return Launcher.fileDataMd5(data)
end

--比较md5--
function Launcher.checkFileDataWithMd5(data, cryptoCode)
	if cryptoCode == nil then
        return true
    end

    local fMd5 = CCCrypto:MD5(Launcher.hex(data), false)
    if fMd5 == cryptoCode then
        return true
    end

    return false
end
--比较md5--
function Launcher.checkFileWithMd5(filePath, cryptoCode)
	if not Launcher.fileExists(filePath) then
        return false
    end

    local data = Launcher.readFile(filePath)
    if data == nil then
        return false
    end

    return Launcher.checkFileDataWithMd5(data, cryptoCode)
end

--平台初始化--
local function needInitPlatform()
	local needInit = false
	if Launcher.platform == "android" then
		
		local javaMethodName = "needInitPlatform"
		local javaParams = { }
	    local javaMethodSig = "()Z"
		local ok, ret = Launcher.luaj.callStaticMethod(Launcher.javaClassName, javaMethodName, javaParams, javaMethodSig)
		if ok then
			needInit = ret
		end
	elseif Launcher.platform == "ios" then
		local ok, ret = Launcher.luaoc.callStaticMethod(Launcher.ocClassName, "needInitPlatform")
        if ok then
            needInit = ret
        end
	end

	return needInit
end


--初始化平台--
function Launcher.initPlatform(callback)
	if needInitPlatform() then
		if Launcher.platform == "android" then
			local javaMethodName = "initPlatform"
			local javaParams = {
	                callback
	            }
	        local javaMethodSig = "(I)V"
	        Launcher.luaj.callStaticMethod(Launcher.javaClassName, javaMethodName, javaParams, javaMethodSig)
		elseif Launcher.platform == "ios" then
			local args = {
				callback
			}
			Launcher.luaoc.callStaticMethod(Launcher.ocClassName, "initPlatform", args)
		else
			callback("successed")
		end
	else

		callback("successed")
	end
end

function Launcher.getAppVersionCode()
    local appVersion = 1
    if Launcher.platform == "android" then
        local javaMethodName = "getAppVersionCode"
        local javaParams = { }
        local javaMethodSig = "()I"
        local ok, ret = Launcher.luaj.callStaticMethod(Launcher.javaClassName, javaMethodName, javaParams, javaMethodSig)
        if ok then
            appVersion = ret
        end
    elseif Launcher.platform == "ios" then
        local ok, ret = Launcher.luaoc.callStaticMethod(Launcher.ocClassName, "getAppVersionCode")
        if ok then
            appVersion = ret
        end
    end
    return appVersion
end

function Launcher.performWithDelayGlobal(listener, time)
	local scheduler = CCDirector:sharedDirector():getScheduler()
    local handle = nil
    handle = scheduler:scheduleScriptFunc(function()
        scheduler:unscheduleScriptEntry(handle)
        listener()
    end, time, false)
end

function Launcher.runWithScene(scene)
	local curScene = sharedDirector:getRunningScene()
	if curScene then
		sharedDirector:replaceScene(scene)
	else
		sharedDirector:runWithScene(scene)
	end
end
