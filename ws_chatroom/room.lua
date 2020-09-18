local skynet = require "skynet"
local socket = require "skynet.socket"
local queue = require "skynet.queue"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"

local CMD = {}

-- 当前房间内的用户
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

local function broadcast(name,data)
    local res = {}
    res.cmd = ntc
    res.msg = data .. name
    for k,v in pairs(users) do
        send_text(v.clientfd, cjson.encode(res))
    end
end

local function broadcast_chat(name,data)
    local res = {}
    res.cmd = "chat_res"
    res.msg = name .. ":" .. data

    for k,v in pairs(users) do
        if v.name ~= name then
            send_text(v.clientfd, cjson.encode(res))
        end  
    end
end

function CMD.add(client)
    table.insert(users,1,client)
    local res = {}
    res.msg = "当前房间人数：".. #users
    send_text(client.clientfd, cjson.encode(res))
    broadcast(client.name, "新用户加入：")
end

function CMD.chat(client,data)
    broadcast_chat(client.name, data)
    skynet.retpack(true)
end

function CMD.left(client)
    for k,v in pairs(users) do
        if v.name == client.name then
            client.room = 0
            skynet.send(hall, "lua", "ready", client)
            table.remove(users,k)
            broadcast(client.name, "用户已离开: ")
            skynet.retpack(true)
            return 
         end
    end
    skynet.retpack(false)
end

function CMD.del(client)
    for k,v in pairs(users) do
        if v.name == client.name then
            table.remove(users,k)
            break
         end
    end

    broadcast(client.name, "用户已掉线: ")
    skynet.retpack(true)
end

skynet.start(function()
    hall = skynet.uniqueservice("hall")
    
    skynet.dispatch("lua", function (session, address, cmd, ...)
        local f = CMD[cmd]
        assert(f)
        f(...)
        --[[
        if session == 0 then
            f(...)
        else 
            skynet.retpack(f(...))
        end    
        ]]
        
    end)
end)