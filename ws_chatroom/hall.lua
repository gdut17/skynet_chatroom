local skynet = require "skynet"
local socket = require "skynet.socket"
local queue = require "skynet.queue"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"

-- 所有用户
local users = {}

-- 所有房间
local rooms = {}

local CMD ={}

local cs = queue()

-- ws发送数据
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


function CMD.ready(client)
    --print("ready", type(client))
    skynet.error("new user login hall: ",client.name)
    table.insert(users,1,client)
    --send_text(client.clientfd,"hello")
end

function CMD.del(client)
    for k,v in pairs(users) do
        if v.name == client.name then
            table.remove(users,k)
            skynet.retpack(true)
            return 
        end
    end
    skynet.retpack(false)
end

function CMD.create(client)
    local roomd = skynet.newservice("room")
    table.insert(rooms,1,roomd)

    for k,v in pairs(users) do
        if v.name == client.name then
            skynet.send(roomd,"lua","add",client)
            table.remove(users,k)
            break
        end
    end
    skynet.retpack(true,roomd)
end

function CMD.join(client)
    local is_room = false
    for _,v in pairs(rooms) do
        if v == client.room then 
            --skynet.error("找到room")
            is_room = true
            break
        end
    end

    if not is_room then 
        skynet.retpack(false,"无此房间号")
        return 
    end
    
    for k,v in pairs(users) do
        if v.name == client.name then
            skynet.send(client.room,"lua","add",client)
            table.remove(users,k)
            break
         end
    end

    skynet.retpack(true)
 end


skynet.start(function()

    skynet.dispatch("lua", function (_, _, cmd, ...)
        local f = CMD[cmd]
        --print("hall", cmd)
        assert(f)
        --f(...)
        cs(f, ...)
    end)
end)