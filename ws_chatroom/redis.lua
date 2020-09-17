local skynet = require "skynet.manager"
local redis = require "skynet.db.redis"

skynet.start(function ()
	local rds = redis.connect({
		host	= "127.0.0.1",
		port	= 6379,
		db		= 0,
		-- auth	= "123456",
	})
	skynet.dispatch("lua", function (session, address, cmd, ...)
		--print(session,address,cmd,...)
		skynet.retpack( rds[cmd:lower()](rds, ...) )
	end)
end)
