-- Loader v1.0 / single fixed HTTPS source
-- Keep this file in the emulator; the linked script is fetched anew each launch.
local URL = 'https://raw.githubusercontent.com/ezduzitag-droid/dotxden-gamehub/main/data/node_6f2e9a.lua'

if type(gg) ~= 'table' or type(gg.makeRequest) ~= 'function' then
    error('GameGuardian Lua environment required.')
end

local ok, response = pcall(gg.makeRequest, URL)
if not ok or type(response) ~= 'table' or response.code ~= 200 or response.error then
    local reason = ok and (type(response) == 'table' and (response.message or response.code) or response) or response
    gg.alert('Unable to load remote module.\nSource: raw.githubusercontent.com\nReason: ' .. tostring(reason))
    return
end

local source = response.content
if type(source) ~= 'string' or #source < 100 or #source > 160000
   or source:sub(1, 25) ~= '-- REFTOOLS-MODULE-V1.0.0' then
    gg.alert('Remote file failed format/size checks. Nothing executed.')
    return
end

local runnable, parseError = load(source, '@node_6f2e9a.lua', 't')
if not runnable then
    gg.alert('Remote Lua compilation failed:\n' .. tostring(parseError))
    return
end

local executed, runtimeError = pcall(runnable)
if not executed then
    gg.alert('Remote module error:\n' .. tostring(runtimeError))
end
