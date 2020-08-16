local wsurl = "ws://my.tld:1234"
local tape = peripheral.find("tape_drive")
local running = true
local wss
local total = 0
local startTimer
local wraparoundTimer

tape.seek(-math.huge)
tape.setSpeed(2)

local curWrite = tape.getPosition()

local buffer = 5 * 6000 -- 2 seconds buffer at the end

--[[local function truncate(data)
    local e = #data
    while data:sub(e,e):byte() == 0 do
        e = e - 1
        if e == 0 then break end
    end
    local s = 0
    while data:sub(s,s):byte() == 0 do
        s = s + 1
        if s > e then break end
    end
    return data:sub(s, e)
end]]--

local handler = {
    ["websocket_success"] = function(url, ws)
        if url == wsurl then
            print("Connected!")
            wss = ws
        end
    end,
    ["websocket_failure"] = function(url, why)
        if url == wsurl then
            print("Failed to connect: "..why)
        end
    end,
    ["websocket_closed"] = function(url)
        if url == wsurl then
            print("Connection closed")
            print("Data written: ",total)
            local k = tape.getSize()
            tape.stop()
            tape.seek(-k)
            tape.stop() --Just making sure
            tape.seek(-90000)
            local s = string.rep("\xAA", 8192)
            for i = 1, k + 8191, 8192 do
                tape.write(s)
            end
            tape.seek(-k)
            tape.seek(-90000)
            tape.seek(-math.huge)
        end
    end,
    ["websocket_message"] = function(url, data)
        if url == wsurl then
            local curRead = tape.getPosition()
            if curWrite + #data > tape.getSize() then
                curWrite = curWrite - (tape.getSize() - buffer)
            end
            local prevWrite = curWrite
            tape.seek(curWrite - tape.getPosition())
            tape.write(data)
            total = total + #data
--            write(".")
            curWrite = tape.getPosition()
            if curWrite > tape.getSize() - buffer then
                -- We're at the end and need to mirror to the beginning
                local offsetInBuffer = prevWrite - (tape.getSize()-buffer)
                local toWrite = data
                if offsetInBuffer < 0 then
                    toWrite = data:sub(-offsetInBuffer)
                end
                tape.seek(offsetInBuffer - tape.getPosition())
                tape.write(toWrite)
            elseif prevWrite < buffer then
                -- We're at the beginning and need to mirror to the end
                local offsetInBuffer = prevWrite
                local nPos = (tape.getSize() - buffer) + offsetInBuffer
                tape.seek(nPos - tape.getPosition())
                tape.write(data)
            end
            tape.seek(curRead - tape.getPosition())
--            print(curWrite - curRead) -- Buffer health
            print(curRead .. "/" .. curWrite)
        end
    end,
    ["key"] = function(key, held)
        if key == keys.r then
            http.websocketAsync(wsurl)
        end
    end,
    ["timer"] = function(t)
        if t == startTimer then
            tape.play()
        elseif t == wraparoundTimer then
            if tape.getPosition() > tape.getSize() - buffer then
                tape.seek((buffer - (tape.getSize() - tape.getPosition())) - tape.getPosition())
                -- | BUFFER | POS | BUFFER | END
                print("WRAP AROUND!")
            end
            wraparoundTimer = os.startTimer(1)
        end
    end
}

http.websocketAsync(wsurl)
startTimer = os.startTimer(5)
wraparoundTimer = os.startTimer(1)

while running do
    local e = {os.pullEvent()}
    if handler[e[1]] then
        handler[e[1]](unpack(e, 2))
    end
end
