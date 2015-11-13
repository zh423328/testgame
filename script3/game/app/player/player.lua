--创建一个类
local  player = class("player", function()
	-- body
	return display.newSprite("icon.png");
end)


--初始化构造函数
function player:ctor()
	-- body
	self:addStateMachine();
end

--添加状态机函数--
function player:addStateMachine()
	--初始化状态机--
	self.fsm = {};
	cc.GameObject.extend(self.fsm):addComponent("components.behavior.StateMachine"):exportMethods();


	--设置状态逻辑--
	self.fsm:setupState({
		initial = "idle",	--闲置

		--事件--
		events = {
			{name = "move", from = {"idle","jump"},to = "walk"},		--切换移动--
			{name = "jumpover", from = {"idle","walk"},to = "jump"},	--跳跃--
			{name = "normal",from ={"walk","jump"}, to = "idle"},		--闲置--
		},

		callbacks = {
			--闲置--
			onenteridle = function()
				-- body
				local scale = CCScaleBy:create(0.2, 1.2)  
				self:runAction(CCRepeat:create(transition.sequence({scale,scale:reverse()}), 2))
			end,

			--移动
			onenterwalk = function()
				local move = CCMoveBy:create(0.2, ccp(50,0));  
				self:runAction(CCRepeat:create(transition.sequence({move,move:reverse()}), 2))
			end,

			--跳跃--
			onenterjump = function()
				-- body
                local jump = CCJumpBy:create(0.5, ccp(0, 0), 100, 2)  
                self:runAction(jump)  
			end,
		},
	});
end

--执行事件--
function player:doEvent(event)
	-- body
	if self.fsm:canDoEvent(event) then
		--todo
		self.fsm:doEvent(event);
	end
	
end


return player