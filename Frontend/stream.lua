local wsurl = "ws://my.tld:1234"
local rawtape = peripheral.find("tape_drive")
local peripheralCalls = 0

local tape = setmetatable({}, {
    __index = function(_, i)
        if rawtape[i] then
            return function(...)
                peripheralCalls = peripheralCalls + 1
                return rawtape[i](...)
            end
        end
    end
})

local running = true
local wss
local total = 0
local startTimer
local repeatingTimer
local size = tape.getSize()

local cData = "" -- cummulative Data

tape.seek(-math.huge)
tape.setSpeed(2)

local curWrite = tape.getPosition()

local buffer = 5 * 9000 -- 5 seconds buffer at the end

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
            tape.seek(-math.huge)
        end
    end,
    ["websocket_message"] = function(url, data)
        if url == wsurl then
            cData = cData .. data
            
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
        elseif t == repeatingTimer then
            local curRead = tape.getPosition()

            if curRead > size - buffer then
                tape.seek((buffer - (size - curRead)) - curRead)
            end

            local bufferHealth = curWrite%(size-buffer) - curRead%(size-buffer)
            if bufferHealth < 2 * 9000 then -- Less than 2 seconds of buffer remaining
                if curWrite + #cData > size then
                    curWrite = curWrite - (size - buffer)
                end
                local prevWrite = curWrite
                tape.seek(curWrite - tape.getPosition())
                tape.write(cData)
                total = total + #cData
                curWrite = tape.getPosition()
                if curWrite > size - buffer then
                    -- We're at the end and need to mirror to the beginning
                    local offsetInBuffer = prevWrite - (size-buffer)
                    local toWrite = cData
                    if offsetInBuffer < 0 then
                        toWrite = cData:sub(-offsetInBuffer)
                    end
                    tape.seek(offsetInBuffer - curWrite)
                    tape.write(toWrite)
                elseif prevWrite < buffer then
                    -- We're at the beginning and need to mirror to the end
                    local offsetInBuffer = prevWrite
                    local nPos = (size - buffer) + offsetInBuffer
                    tape.seek(nPos - curWrite)
                    tape.write(cData)
                end
                tape.seek(curRead - tape.getPosition())
                print(curRead .. "/" .. curWrite)

                cData = ""
            end

            repeatingTimer = os.startTimer(1)
        end
    end
}

http.websocketAsync(wsurl)
startTimer = os.startTimer(5)
repeatingTimer = os.startTimer(1)

while running do
    local e = {os.pullEvent()}
    if handler[e[1]] then
        handler[e[1]](unpack(e, 2))
    end
end
