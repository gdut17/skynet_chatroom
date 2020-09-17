local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"

local clientfd , header = ...
clientfd = tonumber(clientfd)

-- 客户端信息记录，包括fd,name，password，本服务号
local client = {}

local ws = nil
local rds
local hall

local CMD = {}
local handler = {}

local function read_table(result)
	local reply = {}
	for i = 1, #result, 2 do reply[result[i]] = result[i + 1] end
	return reply
end

function CMD.get(msg)
    --print("CMD.get")
    header = cjson.decode(msg);
    --print(header["sec-websocket-key"])
    ws = websocket.new(clientfd, header, handler)
    --print(type(ws))
    ws:start()  
end

function CMD.login(msg)
    
    --print(msg.name)
    -- local ok = rds:exists("user:" .. msg.name)
    local ok = skynet.call(rds,"lua","exists","user:" .. msg.name)
    --print("login1",ok)
    local res = {}
    res.cmd = "login_res"

    if not ok then 
        res.ok = ok;
        res.msg = "不存在用户名"

        ws:send_text(cjson.encode(res))
        return 
    end

    local tb = skynet.call(rds,"lua","hgetall","user:" .. msg.name)
    tb = read_table(tb)
    if tb.password ~= msg.password then 
        res.ok = false;
        res.msg = "密码错误"
        ws:send_text(cjson.encode(res))
    else
        client.name = msg.name
        client.password = msg.password

        res.ok = true;
        ws:send_text(cjson.encode(res))
        skynet.send(hall, "lua", "ready", client)--这里不能发送ws
    end
end

function CMD.register(msg)
    --print(msg.name)
    -- local ok = rds:exists("user:" .. msg.name)
    local ok = skynet.call(rds,"lua","exists","user:" .. msg.name)
    --print(ok)

    local res = {}
    res.cmd = "register_res"

    if not ok then
        local info = {"name", msg.name, "password", msg.password}
        skynet.call(rds,"lua","hmset","user:" .. msg.name, table.unpack(info))
        res.ok = true;
    else
        res.ok = false;
        res.msg = "用户名已存在"
    end

    --local js = cjson.encode(res)
    --print(js)
    ws:send_text(cjson.encode(res))
end

function CMD.create(msg)
    local ok, roomd = skynet.call(hall,"lua","create",client)
    skynet.error("create room ",ok,roomd)
    local res = {}
    res.cmd = "create_res"
    if ok then 
        client.room = roomd
        res.room = roomd
        res.ok = true
    else
        client.room = 0
        res.ok = false
    end
    ws:send_text(cjson.encode(res))
end

function CMD.join(msg)
    
    client.room = tonumber(msg.room)
    local ok, roomd = skynet.call(hall,"lua","join",client)
    skynet.error("join room ",ok,roomd)
    local res = {}
    res.cmd = "join_res"
    if ok then 
        res.ok = true
    else
        client.room = 0
        res.ok = false
        res.msg = "房间号不存在"
    end
    ws:send_text(cjson.encode(res))
end


--[[
    未完成
    离开房间逻辑
    agent call roomd，房间服务将该用户移除，并在房间内广播
    room call hall 房间服务将该用户信息发回hall大厅服务管理。
    client.room = 0;
]]
function CMD.left(msg)

end

function CMD.chat(msg)
    local res = {}
    res.cmd = "chat_res"
    if client.room == 0 then 
        res.ok = false
        res.msg = "你未在房间内"
        ws:send_text(cjson.encode(res))
        return 
    end

    local ok, roomd = skynet.call(client.room ,"lua","chat",client,msg.data)
    --skynet.error("chat room ",ok,roomd)
end

function handler.on_open(ws)
    print(string.format("%d::open", ws.id))
end

function handler.on_message(ws, message)
    print(string.format("%d receive:%s", ws.id, message))
    print(type(message))
    local msg = cjson.decode(message)
    local f = CMD[msg.cmd]
    assert(f)
    f(msg)
    --ws:send_text(message .. "from server")
   -- ws:close()
end

function handler.on_close(ws, code, reason)
    print(string.format("%d close:%s  %s", ws.id, code, reason))

    --[[
        if client.room == 0 then
        skynet.call(hall,"lua","del",client)
    else
        skynet.call(client.room,"lua","del",client)
    ]]
    

    skynet.exit()
end



-- http://192.168.186.143:9999/
skynet.start(function()

    --header = cjson.decode(header)
    rds = skynet.uniqueservice("redis")
    hall = skynet.uniqueservice("hall")
    --print("recv a connection:", clientfd)
    socket.start(clientfd)
    client.clientfd = clientfd
    client.agent = skynet.self()
    client.room = 0

    skynet.dispatch("lua", function (_, _, cmd, ...)
        local f = CMD[cmd]
        --print(cmd)
        if f then
            f(...)
        else
            skynet.error("null cmd ",cmd)
        end
        --assert(f)
        
    end)
end)
