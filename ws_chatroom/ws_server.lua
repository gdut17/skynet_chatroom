local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"

local function handle_socket(cid)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(cid), 8192)

    if code then
        if header.upgrade == "websocket" then
            --print("websocket req",id)
            --print(type(header))
            --local ws = websocket.new(id, header, handler)
            --ws:start()
            local header_json = cjson.encode(header)
            local agent = skynet.newservice("agent", cid) --
            skynet.send(agent,"lua","get",header_json)
        end
    end
end

-- ws://192.168.186.143:9998/
skynet.start(function()
    local address = "0.0.0.0:9998"
    skynet.error("http server listen on 0.0.0.0:9998")

    local id = assert(socket.listen(address))
    socket.start(id , function(cid, addr)
        skynet.error("websocket req ",cid,addr)
        socket.start(cid)
        pcall(handle_socket, cid)
    end)
end)
