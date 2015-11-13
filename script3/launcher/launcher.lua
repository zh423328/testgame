--取消模块--
package.loaded["launcher.init"] = nil
--加载模块--
require("launcher.init")

local function enter_game()
    CCFileUtils:sharedFileUtils():purgeCachedEntries();
    CCLuaLoadChunksFromZIP("lib/framework_precompiled.zip")
    CCLuaLoadChunksFromZIP("lib/game.zip")
	Game = require("game.game")
	Game.startup()
end

local scheduler = CCDirector:sharedDirector():getScheduler()

local LauncherScene = lcher_class("LauncherScene", function()
	local scene = CCScene:create()
	scene.name = "LauncherScene"
    return scene
end)

function LauncherScene:ctor()
    self._path = Launcher.writablePath .. "upd/"
    
    if (Launcher.platform ~= "android" and Launcher.platform ~= "ios") then
        CCFileUtils:sharedFileUtils():addSearchPath(self._path)
        CCFileUtils:sharedFileUtils():addSearchPath("res/")
    end

	self._textLabel = CCLabelTTF:create(STR_LCHER_UNCOMPRESS_TEXT, "Arial", 20)
	self._textLabel:setColor(ccc3(255, 255, 255))
	self._textLabel:setPosition(Launcher.cx, Launcher.cy - 60)
	self:addChild(self._textLabel)
	
    self._progressLabel = CCLabelTTF:create("0%", "Arial", 20)
    self._progressLabel:setColor(ccc3(255, 255, 255))
    self._progressLabel:setPosition(Launcher.cx, Launcher.cy - 20)
    self:addChild(self._progressLabel)

    local progressBarBg = CCSprite:create("launcher/dark.png")
    self:addChild(progressBarBg)
    local progressBarBgSize = progressBarBg:getContentSize()
    local progressBarPt = ccp(Launcher.cx, Launcher.cy + progressBarBgSize.height * 0.5)
    progressBarBg:setPosition(progressBarPt)

    self._progressBar = CCProgressTimer:create(CCSprite:create("launcher/light.png"))
    self._progressBar:setType(kCCProgressTimerTypeBar)
    self._progressBar:setMidpoint(CCPointMake(0,0))
    self._progressBar:setBarChangeRate(CCPointMake(0, 1))
    self._progressBar:setPosition(progressBarPt)
    self:addChild(self._progressBar)

    --注释平台初始化--
    --enter_game()
    --   Launcher.performWithDelayGlobal(function()
    --   	 if (Launcher.platform == "android" or Launcher.platform == "ios") then
		-- 	Launcher.initPlatform(lcher_handler(self, self._initPlatformResult))
		-- else
		-- 	enter_game()
		-- end
    --   end, 0.1)
    --初始化平台--

    Launcher.mkDir(self._path)

    local flistpath =  self._path .. Launcher.fListName

    self.uncompressfilelist = {};
    self.uncompressnum = 0;
    self.uncompressTotal = 1;
    --更新操作--
    self.workerType = Launcher.workerType.UPDATE;
    --是否存在文件--
    if Launcher.fileExists(flistpath) then
         self:_initPlatformResult("successed");
    else
        --第一次copy资料-- app中的文件列表--
        self.workerType = Launcher.workerType.UNCOMPRESS;
        self.appfileList = Launcher.doFile(Launcher.fListName)

        if self.appfileList == nil or (self.appfileList and self.appfileList.appVersion == nil ) then
            --todo
            self.workerType = Launcher.workerType.UPDATE;
            self:_initPlatformResult("successed");
        elseif self.appfileList and self.appfileList.appVersion then
            --解压资源--
            local filelist = self.appfileList.fileInfoList;
            self.uncompressTotal = #filelist;
            for k=1, self.uncompressTotal do
                table.insert(self.uncompressfilelist, filelist[k]);
            end
            self:UncompressRes();
        end
    end
end

function LauncherScene:UncompressRes()
    --解压相关文件--
    --先删除里面所有内容--
    Launcher.removePath(self._path)

    --创建资源目录--
    local dirPaths = self.appfileList.dirPaths
    for i=1,#(dirPaths) do
        Launcher.mkDir(self._path..(dirPaths[i].name))
    end

    --拷贝操作--
    self.schedulerhandle = nil;
    self.schedulerhandle = scheduler:scheduleScriptFunc(function()
        self:UnCompressFile();
    end, 1/60, false)
end


--定时器
function LauncherScene:UnCompressFile()
    -- body
    if  self.workerType == Launcher.workerType.UNCOMPRESS then
        --解压copy文件--
        self.uncompressnum  = self.uncompressnum +1;
        --执行copy操作--
        if #self.uncompressfilelist ~= 0 then
            --todo
            --更新--
            local filename = self.uncompressfilelist[1].name;
            local newpath = self._path..filename;
            local oldpath = CCFileUtils:sharedFileUtils():fullPathForFilename(filename);

            local filedata = Launcher.readFile(oldpath);
            if filedata then
                --todo
                Launcher.writefile(newpath, filedata)
            end

            local downloadPro = (self.uncompressnum  * 100) / (self.uncompressTotal)
            if downloadPro >=100 then
                --todo
                downloadPro = 100;
            end

            self._progressBar:setPercentage(downloadPro)
            self._progressLabel:setString(string.format("%d%%", downloadPro))
            
            table.remove(self.uncompressfilelist,1);
        else
            --结束了执行更新操作--
            scheduler:unscheduleScriptEntry(self.schedulerhandle);
            self._textLabel:setString(STR_LCHER_HAS_UPDATE);
            self._progressLabel:setVisible(false);
            self._progressBar:setVisible(false);
            self.workerType = Launcher.workerType.UPDATE;
            self:_initPlatformResult("successed");
        end
    end
end


function LauncherScene:_initPlatformResult(message)
	if message == "successed" then
		--启动更新逻辑
		self:_initUpdate()
	else
		--TODO::初始化平台失败
	end
end

--初始化更新--
function LauncherScene:_initUpdate()
    Launcher.performWithDelayGlobal(function()
    	self:_checkUpdate()
    end, 0.1)
end

--检查更新--
function LauncherScene:_checkUpdate()
	Launcher.mkDir(self._path)
    --upd文件中--flist文件--
	self._curListFile =  self._path .. Launcher.fListName

	if Launcher.fileExists(self._curListFile) then
      self._fileList = Launcher.doFile(self._curListFile)
    end
      

    --当前更新文件中的版本--
    if self._fileList ~= nil then
        --大版本更新--
        local appVersionCode = Launcher.getAppVersionCode()
        if appVersionCode ~= self._fileList.appVersion then
            --新的app已经更新需要删除upd/目录下的所有文件
            Launcher.removePath(self._path)
            --重新启动--
            require("main")
            return
        end
    else
        --第一次启动--
    	self._fileList = Launcher.doFile(Launcher.fListName)
    end

    --没有nil--
    if self._fileList == nil then
    	self._updateRetType = Launcher.UpdateRetType.OTHER_ERROR
    	self:_endUpdate()
    end

    --更新launcher.lib--
    self:_requestFromServer(Launcher.libDir .. Launcher.lcherZipName, Launcher.RequestType.LAUNCHER, 30)
end

--结束更新--
function LauncherScene:_endUpdate()
	if self._updateRetType ~= Launcher.UpdateRetType.SUCCESSED then
		CCLuaLog("update errorCode = %d", self._updateRetType)
		Launcher.removePath(self._curListFile)
	end

	enter_game()
end

--申请更新--
function LauncherScene:_requestFromServer(filename, requestType, waittime)
    local url = Launcher.server ..Launcher.platform.."/".. filename

    if Launcher.needUpdate then
        local request = CCHTTPRequest:createWithUrl(function(event) 
        	self:_onResponse(event, requestType)
        end, url, kCCHTTPRequestMethodGET)

        if request then
        	request:setTimeout(waittime or 60)
        	request:start()
    	else
    		--初始化网络错误
    		self._updateRetType = UpdateRetType.NETWORK_ERROR
        	self:_endUpdate()
    	end
    else
    	--不更新
    	enter_game()
    end
end


function LauncherScene:_onResponse(event, requestType)
    local request = event.request
    if event.name == "completed" then
        if request:getResponseStatusCode() ~= 200 then
            self._updateRetType = Launcher.UpdateRetType.NETWORK_ERROR
        	self:_endUpdate()
        else
            --文件下载--
            local dataRecv = request:getResponseData()
            if requestType == Launcher.RequestType.LAUNCHER then
            	self:_onLauncherPacakgeFinished(dataRecv)
            elseif requestType == Launcher.RequestType.FLIST then
            	self:_onFileListDownloaded(dataRecv)
            else
            	self:_onResFileDownloaded(dataRecv)
            end
        end
    elseif event.name == "inprogress" then
    	 if requestType == Launcher.RequestType.RES then
    	 	self:_onResProgress(event.dlnow)
    	 end
    else
        self._updateRetType = Launcher.UpdateRetType.NETWORK_ERROR
        self:_endUpdate()
    end
end

function LauncherScene:_onLauncherPacakgeFinished(dataRecv)
	Launcher.mkDir(self._path .. Launcher.libDir)
	local localmd5 = nil

    --update--
	local localPath = self._path .. Launcher.libDir .. Launcher.lcherZipName

	if not Launcher.fileExists(localPath) then
        --相对位置--
		localPath = Launcher.libDir .. Launcher.lcherZipName
	end
		
	localmd5 = Launcher.fileMd5(localPath)

	local downloadMd5 =  Launcher.fileDataMd5(dataRecv)

    --launcher有更新--
	if downloadMd5 ~= localmd5 then
		Launcher.writefile(self._path .. Launcher.libDir .. Launcher.lcherZipName, dataRecv)
        require("main")
    else
        --更新flist--
    	self:_requestFromServer(Launcher.fListName, Launcher.RequestType.FLIST)
    end
end

--下载文件flist.upd临时文件---
function LauncherScene:_onFileListDownloaded(dataRecv)
	self._newListFile = self._curListFile .. Launcher.updateFilePostfix
	Launcher.writefile(self._newListFile, dataRecv)

    --新的flist.upd文件--
	self._fileListNew = Launcher.doFile(self._newListFile)
	if self._fileListNew == nil then
        self._updateRetType = Launcher.UpdateRetType.OTHER_ERROR
		self:_endUpdate()
		return
	end

    --跟当前的版本相同--
	if self._fileListNew.version == self._fileList.version then
		Launcher.removePath(self._newListFile)
		self._updateRetType = Launcher.UpdateRetType.SUCCESSED
		self:_endUpdate()
		return
	end

	--创建资源目录--
	local dirPaths = self._fileListNew.dirPaths
    for i=1,#(dirPaths) do
        Launcher.mkDir(self._path..(dirPaths[i].name))
    end

    self:_updateNeedDownloadFiles()

    self._numFileCheck = 0
    self:_reqNextResFile()

end

--资源更新--
function LauncherScene:_onResFileDownloaded(dataRecv)
	local fn = self._curFileInfo.name .. Launcher.updateFilePostfix
	Launcher.writefile(self._path .. fn, dataRecv)
	if Launcher.checkFileWithMd5(self._path .. fn, self._curFileInfo.code) then
		table.insert(self._downList, fn)
		self._hasDownloadSize = self._hasDownloadSize + self._curFileInfo.size
		self._hasCurFileDownloadSize = 0
		self:_reqNextResFile()
	else
		--文件验证失败
        self._updateRetType = Launcher.UpdateRetType.MD5_ERROR
    	self:_endUpdate()
	end
end

function LauncherScene:_onResProgress(dlnow)
	self._hasCurFileDownloadSize = dlnow
    self:_updateProgressUI()
end

function LauncherScene:_updateNeedDownloadFiles()
	self._needDownloadFiles = {}
    self._needRemoveFiles = {}
    self._downList = {}
    self._needDownloadSize = 0
    self._hasDownloadSize = 0
    self._hasCurFileDownloadSize = 0

    --文件列表比较--
    local newFileInfoList = self._fileListNew.fileInfoList
    local oldFileInfoList = self._fileList.fileInfoList

    local hasChanged = false
    for i=1, #(newFileInfoList) do
        hasChanged = false
        for k=1, #(oldFileInfoList) do
            if newFileInfoList[i].name == oldFileInfoList[k].name then
                hasChanged = true
                if newFileInfoList[i].code ~= oldFileInfoList[k].code then
                    --".upd文件--"
                    local fn = newFileInfoList[i].name .. Launcher.updateFilePostfix
                    if Launcher.checkFileWithMd5(self._path .. fn, newFileInfoList[i].code) then
                        table.insert(self._downList, fn)
                    else
                        self._needDownloadSize = self._needDownloadSize + newFileInfoList[i].size
                        table.insert(self._needDownloadFiles, newFileInfoList[i])
                    end
                end
                table.remove(oldFileInfoList, k)
                break
            end
        end
        if hasChanged == false then
            self._needDownloadSize = self._needDownloadSize + newFileInfoList[i].size
            table.insert(self._needDownloadFiles, newFileInfoList[i])
        end
    end
    self._needRemoveFiles = oldFileInfoList


    self._progressLabel:setVisible(true);
    self._progressLabel:setString("0%%");
    self._progressBar:setVisible(true);
    self._textLabel:setString(STR_LCHER_UPDATING_TEXT)

end

function LauncherScene:_updateProgressUI()
	local downloadPro = ((self._hasDownloadSize + self._hasCurFileDownloadSize) * 100) / (self._needDownloadSize)
    self._progressBar:setPercentage(downloadPro)
    self._progressLabel:setString(string.format("%d%%", downloadPro))
end

function LauncherScene:_reqNextResFile()
    self:_updateProgressUI()
    self._numFileCheck = self._numFileCheck + 1
    self._curFileInfo = self._needDownloadFiles[self._numFileCheck]
    if self._curFileInfo and self._curFileInfo.name then
    	self:_requestFromServer(self._curFileInfo.name, Launcher.RequestType.RES)
    else
    	self:_endAllResFileDownloaded()
    end

end

function LauncherScene:_endAllResFileDownloaded()
    --self._newListFile == flist.upd
    --self._curListFile == flist

	local data = Launcher.readFile(self._newListFile)
    Launcher.writefile(self._curListFile, data)
    self._fileList = Launcher.doFile(self._curListFile)
    if self._fileList == nil then
        self._updateRetType = Launcher.UpdateRetType.OTHER_ERROR
    	self:_endUpdate()
        return
    end

    --移除零时文件--
    Launcher.removePath(self._newListFile)

    local offset = -1 - string.len(Launcher.updateFilePostfix)
    for i,v in ipairs(self._downList) do
        v = self._path .. v
        local data = Launcher.readFile(v)

        local fn = string.sub(v, 1, offset)
        --移除临时文件--
        Launcher.writefile(fn, data)
        Launcher.removePath(v)
    end

    --移除所有不要的文件--
    for i,v in ipairs(self._needRemoveFiles) do
        Launcher.removePath(self._path .. (v.name))
    end

    self._updateRetType = Launcher.UpdateRetType.SUCCESSED
    self:_endUpdate()
end


local lchr = LauncherScene.new()
Launcher.runWithScene(lchr)