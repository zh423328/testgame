
 --package.loaded["config"] = nil

 --require("game")
 --game.startup()
 --require("app.MyApp").new():run()

local Game = {};

function Game.startup()
	require("game.app.MyApp").new():run();
end

return Game;

