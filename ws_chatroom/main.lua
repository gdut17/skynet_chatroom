--[[
独立的5个actor实体
main    -- 接收客户端连接，为每个客户端创建服务
agent   -- 处理客户端发来的数据，和大厅交互
hall    -- 大厅服务，管理agent，分配房间服务
room    -- 房间服务，处理房间内客户端的逻辑
redis   -- 读写数据库中客户端的信息

网络协议使用websocket
数据库使用redis
数据格式使用json


]]

local skynet = require "skynet"
local socket = require "skynet.socket"


skynet.start(function ()

    skynet.uniqueservice("http_server")
    skynet.uniqueservice("ws_server")
    skynet.uniqueservice("redis")
    skynet.uniqueservice("hall")

    skynet.exit()
   -- local hall = skynet.uniqueservice("hall") --hall是唯一服
    --socket.start(listenfd, accept) -- 绑定listenfd, actor 与 epoll
end)