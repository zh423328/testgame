--载入定时器模块scheduler
local scheduler = require("framework.scheduler");
local player = require("game.app.player.player");

local MainScene = class("MainScene", function()
    return display.newScene("MainScene")
end)

local time = 0
local function update(dt)
	-- body
	--time = time + 1;
	--CCLuaLog(dt);
end

local function once()
	CCLuaLog("later call");
end
function MainScene:ctor()
	local sp = display.newSprite("Hello.png", display.cx, display.cy);
	if sp then
		--todo
		self:addChild(sp);
	end

	self.label = ui.newTTFLabel({text = "0",size = 30,x = display.cx,y = display.cy,align = ui.TEXT_ALIGN_CENTER});
	if self.label  then
		--todo
		self:add(self.label);
	end
	--

	--newLayer--
	self.layer = display.newLayer();
	if self.layer then
		--todo
		self:addChild(self.layer);

		--设置键盘事件--
		self.layer:setKeypadEnabled(true);
		self.layer:addNodeEventListener(cc.KEYPAD_EVENT,function(event)
				self:KeyEvent(event);
			end)
	end


	--添加player--
	self.player = player.new();

	if self.player then
		--todo
		self.player:setPosition(ccp(display.cx,display.cy));
		self:addChild(self.player);
	end
		
	local function menuCallback(tag)  
        if tag == 1 then   
            self.player:doEvent("normal")  
        elseif tag == 2 then  
            self.player:doEvent("move")  
        elseif tag == 3 then  
            self.player:doEvent("jumpover")  
        end  
    end  
	--添加状态控制--
	local mormalItem = ui.newTTFLabelMenuItem({text = "normal", x = display.width*0.3, y = display.height*0.2, listener = menuCallback, tag = 1})  
    local moveItem =  ui.newTTFLabelMenuItem({text = "move", x = display.width*0.5, y = display.height*0.2, listener = menuCallback, tag = 2})  
    local attackItem =  ui.newTTFLabelMenuItem({text = "attack", x = display.width*0.7, y = display.height*0.2, listener = menuCallback, tag = 3})  
    local menu = ui.newMenu({mormalItem, moveItem, attackItem})  
    self:addChild(menu)
end

function MainScene:onEnter()
	--每隔一秒执行一次--
	self.schedulerhandle = scheduler.scheduleGlobal(update,1);

	--延时time执行一次函数，
	scheduler.performWithDelayGlobal(once, 2);
end

function MainScene:onExit()
	scheduler.unscheduleGlobal(self.schedulerhandle);
end

function MainScene:KeyEvent(event)
	-- body
	--返回--
	print(event.key);
	if event.key == "back" then
		--todo
		device.showAlert("Config Exit", "Are you sure exit game?", {"Yes","No"}, function (event)
			-- body
			if event.buttonIndex == 1 then
				--todo
				--确认
				app:exit();
			else
				--取消
			end
		end)
	elseif event.key == "menu" then
		print("menu");
	end
end

return MainScene
