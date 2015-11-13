------------------------------------------------------------------------------
--Load origin framework
------------------------------------------------------------------------------
CCLuaLoadChunksFromZIP("res/framework_precompiled.zip")

------------------------------------------------------------------------------
--If you would update the modoules which have been require here,
--you can reset them, and require them again in modoule "appentry"
------------------------------------------------------------------------------
require("config")
require("framework.init")

------------------------------------------------------------------------------
--define UpdateScene
------------------------------------------------------------------------------
local UpdateScene = class("UpdateScene", function()
    return display.newScene("UpdateScene")
end)

--local server = "http://192.168.19.139:8088/"
local server = "http://10.10.10.82:8080/quickhttp/"
local param  = ""..device.platform.."/"
local list_filename = "flist"
local downList = {}

--字符串转换为16进制码--
local function hex(s)
    s=string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
    return s
end

--读取文件所有内容- 
local function readFile(path)
    local file = io.open(path, "rb")
    if file then
        local content = file:read("*all")
        io.close(file)
        return content
    end
    return nil
end

--移除文件--
local function removeFile(path)
    --CCLuaLog("removeFile: "..path)
    io.writefile(path, "")
    if device.platform == "windows" then
        --os.execute("del " .. string.gsub(path, '/', '\\'))
    else
        os.execute("rm " .. path)
    end
end

---检查md5--
local function checkFile(fileName, cryptoCode)
    print("checkFile:", fileName)
    print("cryptoCode:", cryptoCode)

    if not io.exists(fileName) then
        return false
    end

    local data = readFile(fileName)
    if data==nil then
        return false
    end

    if cryptoCode==nil then
        return true
    end

    local ms = crypto.md5(hex(data))
    print("file cryptoCode:", ms)
    if ms==cryptoCode then
        return true
    end

    return false
end

--检查目录是否可用--
local function checkDirOK( path )
    require "lfs"
    local oldpath = lfs.currentdir()
    CCLuaLog("old path------> "..oldpath)

    if lfs.chdir(path) then
        lfs.chdir(oldpath)
        CCLuaLog("path check OK------> "..path)
        return true
    end

    if lfs.mkdir(path) then
        CCLuaLog("path create OK------> "..path)
        return true
    end
end

local function CreateDir( path )
    require("lfs");

    if io.exists(path) then
        --todo
        return true;
    end

    if lfs.mkdir(path) then
        CCLuaLog("path create OK------> "..path)
        return true
    end

    return false;
end

function UpdateScene:ctor()
    self.path = device.writablePath.."/upd/"

    --create dir--
    CreateDir(self.path);

    local label = ui.newTTFLabel({
        text = "Loading...",
        size = 64,
        x = display.cx,
        y = display.cy,
        align = ui.TEXT_ALIGN_CENTER
    })
    self:addChild(label)
end

function UpdateScene:updateFiles()
    local data = readFile(self.newListFile)
    io.writefile(self.curListFile, data)

    self.fileList = dofile(self.curListFile)
    if self.fileList==nil then
        self:endProcess()
        return
    end

    removeFile(self.newListFile)

    for i,v in ipairs(downList) do
        print(i,v)
        local data=readFile(v)
        local fn = string.sub(v, 1, -5)
        print("fn: ", fn)
        io.writefile(fn, data)
        removeFile(v)
    end
    self:endProcess()
end

function UpdateScene:reqNextFile()
    self.numFileCheck = self.numFileCheck+1
    self.curStageFile = self.fileListNew.stage[self.numFileCheck]
    if self.curStageFile and self.curStageFile.name then
        local fn = self.path..self.curStageFile.name
        if checkFile(fn, self.curStageFile.code) then
            self:reqNextFile()
            return
        end

        fn = fn..".upd"
        if checkFile(fn, self.curStageFile.code) then
            table.insert(downList, fn)
            self:reqNextFile()
            return
        end
        self:requestFromServer(self.curStageFile.name)
        return
    end

    self:updateFiles()
end

function UpdateScene:onEnterFrame(dt)
	if self.dataRecv then
		if self.requesting == list_filename then
            --写入内容到文件中--
			io.writefile(self.newListFile, self.dataRecv)
            CCLuaLog("datarecv:"..self.dataRecv);

			self.dataRecv = nil

			self.fileListNew = dofile(self.newListFile)
			if self.fileListNew==nil then
				CCLuaLog(self.newListFile..": Open Error!")
				self:endProcess()
				return
			end

			CCLuaLog(self.fileListNew.ver)
			if self.fileListNew.ver==self.fileList.ver then
				self:endProcess()
				return
			end

            self.numFileCheck = 0
            self.requesting = "files"
            self:reqNextFile()
            return
		end

        if self.requesting == "files" then
            local fn = self.path..self.curStageFile.name..".upd"
            io.writefile(fn, self.dataRecv)
            self.dataRecv = nil
            if checkFile(fn, self.curStageFile.code) then
                table.insert(downList, fn)
                self:reqNextFile()
            else
                self:endProcess()
            end
            return
        end

        return
	end

end

function UpdateScene:onEnter()
    CCLuaLog(self.path);
    if not checkDirOK(self.path) then
        require("appentry")
        return
    end

    self.curListFile =  self.path..list_filename               
	self.fileList = nil

	if io.exists(self.curListFile) then
		self.fileList = dofile(self.curListFile)
	end

	if self.fileList==nil then
		self.fileList = {
			ver = "1.0.0",
			stage = {},
			remove = {},
		}
	end

	self.requestCount = 0
	self.requesting = list_filename
    self.newListFile = self.curListFile..".upd"
	self.dataRecv = nil
	self:requestFromServer(self.requesting)

    self:scheduleUpdate(function(dt) self:onEnterFrame(dt) end)

    --print("device.platform", device.platform)
    --if device.platform ~= "android" then return end

    -- avoid unmeant back
    self:performWithDelay(function()
        -- keypad layer, for android
        local layer = display.newLayer()
        layer:addKeypadEventListener(function(event)
            if event == "back" then app:exit() end
        end)
        self:addChild(layer)

        layer:setKeypadEnabled(true)
    end, 0.5)
end

function UpdateScene:onExit()
end

function UpdateScene:endProcess()
	CCLuaLog("----------------------------------------UpdateScene:endProcess")

    if self.fileList and self.fileList.stage then
        local checkOK = true
        for i,v in ipairs(self.fileList.stage) do
            if not checkFile(self.path..v.name, v.code) then
                CCLuaLog("----------------------------------------Check Files Error")
                checkOK = false
                break
            end
        end

        if checkOK then
            for i,v in ipairs(self.fileList.stage) do
                if v.act=="load" then
                    CCLuaLoadChunksFromZIP(self.path..v.name)
                end
            end
            for i,v in ipairs(self.fileList.remove) do
                removeFile(self.path..v)
            end
        else
            removeFile(self.curListFile)
        end
    end

    require("appentry")
end

function UpdateScene:requestFromServer(filename, waittime)
    local url = server..param..filename;
    self.requestCount = self.requestCount + 1
    local index = self.requestCount

    -- 创建一个请求，并以 GET 方式发送数据到服务端--
    local request = network.createHTTPRequest(function(event)
        self:onResponse(event, index)
    end, url, "GET")

    if request then
        request:setTimeout(waittime or 30)
        -- 开始请求。当请求完成时会调用 callback() 函数
        request:start()
    else
        self:endProcess()
    end

end

--完成回调--
function UpdateScene:onResponse(event, index, dumpResponse)
    local request = event.request
    printf("REQUEST %d - event.name = %s", index, event.name)
    if event.name == "completed" then
        printf("REQUEST %d - getResponseStatusCode() = %d", index, request:getResponseStatusCode())
        --printf("REQUEST %d - getResponseHeadersString() =\n%s", index, request:getResponseHeadersString())

        if request:getResponseStatusCode() ~= 200 then
        	self:endProcess()
        else
            printf("REQUEST %d - getResponseDataLength() = %d", index, request:getResponseDataLength())
            if dumpResponse then
                printf("REQUEST %d - getResponseString() =\n%s", index, request:getResponseString())
            end
            self.dataRecv = request:getResponseData()
        end
    elseif event.name == "inprogress" then
        CCLuaLog(string.format("%d/%d",event.dlnow,event.dltotal));
    else
        printf("REQUEST %d - getErrorCode() = %d, getErrorMessage() = %s", index, request:getErrorCode(), request:getErrorMessage())
        self:endProcess()
    end

    print("----------------------------------------")
end

local upd = UpdateScene.new()
display.replaceScene(upd)