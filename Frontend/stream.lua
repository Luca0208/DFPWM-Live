local version="29667b9a6799acfcc8222048bb7cec081a9b1fda"
local wsurl = settings.get("radio.wsurl")
local rawtape = peripheral.find("tape_drive")

local handle = http.get("https://raw.githubusercontent.com/Luca0208/DFPWM-Live/master/.version")
if handle then
    local data = handle.readAll()
    handle.close()
    local latest = data:match("commit ([0-9a-f]+)\n")
    if not latest then
        printError("Malformed .version file! Please check manually at https://github.com/Luca0208/DFPWM-Live")
    else
        if version ~= latest then
            print("Updating!")
            print(data)
            local s = shell.getRunningProgram()
            handle = http.get("https://raw.githubusercontent.com/Luca0208/DFPWM-Live/master/Frontend/stream.lua")
            if not handle then
                printError("Could not download new version :( Please check manually at https://github.com/Luca0208/DFPWM-Live")
            else
                data = handle.readAll()
                local f = fs.open(s, "w")
                handle.close()
                f.write(data)
                f.close()
                shell.run(s, ...)
                return
            end
        end
    end
else
    printError("Couldn't check for updates, please check manually at https://github.com/Luca0208/DFPWM-Live")
end

if not wsurl then
    printError("Websocket URL not set!")
    printError("Use \"set radio.wsurl <URL>\" to set it")
    return
end

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
local started = os.clock()
local startedPlaying = os.clock() + 5
local lastWrite = os.clock()
local dlSpeed = 0
local startTimer
local repeatingTimer
local size = tape.getSize()
local curIndicatorpos = 0

local cData = "" -- cummulative Data

tape.seek(-math.huge)
tape.setSpeed(2)

local curWrite = tape.getPosition()

local buffer = 5 * 9000 -- 5 seconds buffer at the end

local function wipeTape()
    tape.stop()
    tape.seek(-math.huge)
    tape.write(("\000"):rep(size))
    tape.seek(-math.huge)
end

local prefix = {"", "K", "M", "G", "T"}
local function format(num, _decimals, useIEC)
    local factor = useIEC and 1024 or 1000
    local decimals = math.pow(10, _decimals or 2)
    local i = 1
    while prefix[i] and num >= factor do
        i = i + 1
        num = num/factor
    end
    num = math.floor(num * decimals + 0.5)/decimals
    if prefix[i] == "" then
        return tostring(num)
    else
        return tostring(num) .. prefix[i] .. (useIEC and "i" or "")
    end
end

local handler = {
    ["websocket_success"] = function(url, ws)
        if url == wsurl then
            print("Thanks for using DFPWM-Live!")
            print("Playtime |  DL   |DL Total |Periph. Calls |")
            print("---------|-------|---------|------|-------|")
            startTimer = os.startTimer(5)
            repeatingTimer = os.startTimer(1)
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
            running = false
        end
    end,
    ["websocket_message"] = function(url, data)
        if url == wsurl then
            cData = cData .. data
            total = total + #data
        end
    end,
    ["char"] = function(c)
        if c:lower() == "q" then
            running = false
        end
    end,
    ["timer"] = function(t)
        if t == startTimer then
            tape.play()
            startedPlaying = os.clock()
        elseif t == repeatingTimer then
            local curRead = tape.getPosition()

            if curRead > size - buffer then
                tape.seek((buffer - (size - curRead)) - curRead)
            end

            local bufferHealth = curWrite%(size-buffer) - curRead%(size-buffer)

            local x, y = term.getCursorPos()
            term.setCursorPos(1, y)
            term.clearLine()

            local runTime = math.max(os.clock() - startedPlaying, 0)
            local hours = math.floor(runTime/(3600))
            local minutes = (runTime%3600)/60
            local seconds = (runTime%60)

            local formattedTime = ("%2d:%2d:%2d"):format(hours, minutes, seconds):gsub(" ", "0")

            term.write(("%s|%7s|%9s|%6d|%7s"):format(
                formattedTime,
                format(dlSpeed, 0, true) .. "B/s",
                format(total, 2, true) .. "B"),
                format(peripheralCalls, 2),
                format(peripheralCalls/(os.clock() - started), 2) .. "/s"
            )

            if bufferHealth < 2 * 9000 then -- Less than 2 seconds of buffer remaining
                if curWrite + #cData > size then
                    curWrite = curWrite - (size - buffer)
                end
                local prevWrite = curWrite
                tape.seek(curWrite - tape.getPosition())
                tape.write(cData)
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
                dlSpeed = #cData / (os.clock() - lastWrite)
                cData = ""
                lastWrite = os.clock()
            end

            repeatingTimer = os.startTimer(1)
        end
    end,
    ["terminate"] = function()
        running = false
    end
}

http.websocketAsync(wsurl)

while running do
    local e = {os.pullEventRaw()}
    if handler[e[1]] then
        handler[e[1]](unpack(e, 2))
    end
end

-- Unfortunately because we have no way of checking wether a websocket is open this is the best we can do
pcall(function() wss.close() end)
print("Connection closed")
print("Data received:",format(total, nil, true) .. "B")
wipeTape()
