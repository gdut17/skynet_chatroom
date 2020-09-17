local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"

-- 发送html
local function response(id,  ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

local function handle(id)
    socket.start(id) -- 这里一定要start，否则不会接收来自客户端的数据
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
        local f = io.open("/home/gdut17/skynet_test/myexample/ws_chatroom/index.html", "r")
        local index_html = f:read("*a")
        f:close()
        response(id, code, index_html)
    end
    socket.close(id)
end

local function accept(clientfd, addr)
    skynet.error("http req ",clientfd,addr)
    skynet.fork(handle,clientfd)
end
-- http://192.168.186.143:9999/
skynet.start(function ()
    local listenfd = socket.listen("0.0.0.0", 9999)
    skynet.error("http server listen on 0.0.0.0:9999")
    socket.start(listenfd, accept) 
end)