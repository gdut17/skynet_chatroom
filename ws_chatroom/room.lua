local skynet = require "skynet"
local socket = require "skynet.socket"
local queue = require "skynet.queue"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"

local CMD = {}

local users = {}

local hall


local function send_frame(id, fin, opcode, data)
    local finbit, mask_bit
    if fin then
        finbit = 0x80
    else
        finbit = 0
    end

    local frame = string.pack("B", finbit | opcode)
    local l = #data
    -- self.mask_outgoing
    if nil then
        mask_bit = 0x80
    else
        mask_bit = 0
    end

    if l < 126 then
        frame = frame .. string.pack("B", l | mask_bit)
    elseif l < 0xFFFF then
        frame = frame .. string.pack(">BH", 126 | mask_bit, l)
    else 
        frame = frame .. string.pack(">BL", 127 | mask_bit, l)
    end

    --if self.mask_outgoing then
    --end

    frame = frame .. data

    socket.write(id, frame)
    
end

local function send_text(id,data)
    send_frame(id, true, 0x1, data)
end

local function broadcast(name)
    for k,v in pairs(users) do
        local res = {}
        res.msg = "新用户上线：" .. name
        send_text(v.clientfd,cjson.encode(res))
    end
end
local function broadcast_chat(name,data)
    local res = {}
    res.cmd = "chat_res"
    for k,v in pairs(users) do
        if v.name ~= name then
            res.msg = "chat：" .. name .. ":" .. data
            send_text(v.clientfd,cjson.encode(res))
        end  
    end
end

function CMD.add(client)
    table.insert(users,1,client)
    local res = {}
    res.msg = "当前房间人数：".. #users
    send_text(client.clientfd,cjson.encode(res))
    broadcast(client.name)
end

function CMD.chat(client,data)
    broadcast_chat(client.name,data)
    skynet.retpack(true)
end

function CMD.del(client)
    table.insert(users,1,client)
    local res = {}
    res.msg = "当前房间人数：".. #users
    send_text(client.clientfd,cjson.encode(res))
    broadcast(client.name)
end

skynet.start(function()
    hall = skynet.uniqueservice("hall")
    
    skynet.dispatch("lua", function (_, _, cmd, ...)
        local f = CMD[cmd]
        print("room ", cmd)
        assert(f)
        f(...)
        --cs(f, ...)
    end)
end)