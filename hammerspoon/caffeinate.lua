-- To replace the Caffeinate app

local prefix = require('prefix')

local menu = nil

local function toggle()
    local enabled = hs.caffeinate.toggle('system')
    if enabled then
        menu = hs.menubar.new():setTitle('☕')
    else
        menu:delete()
    end
end

local function sleepDislay()
    hs.execute('pmset displaysleepnow')
end

prefix.bind('', 'c', toggle)
prefix.bind('', 's', sleepDislay)
