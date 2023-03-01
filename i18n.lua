--[[
    多语言
    @author ayongm2
--]]
local i18n = {}

local string_gsub     = string.gsub
local string_find     = string.find
local string_sub      = string.sub
local string_format   = string.format

local string_split = function(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string_find(input, delimiter, pos, true) end do
        table.insert(arr, string_sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string_sub(input, pos))
    return arr
end

local table_getByPath = function( t, path )
    if not type(t) == "table" then return end
    if not path then 
        return t
    elseif string_find(path, "%.") or string_find(path, "%[") then 
        local paths = string_split(path, ".")
        local cur = t
        local hasN = string_find(path, "%[") ~= nil
        for i, keyname in ipairs(paths) do
            local v 
            if hasN then
                local n = tonumber(string.match(keyname, "^%[(.+)%]$"))
                if n then v = cur[n] end 
            end 
            if v == nil then v = cur[keyname] end
            if v ~= nil then cur = v else return nil end
        end
        return cur
    else
        return t[path]
    end
end

local convertSecondToString = function(second)
    if not second or second < 0 then second = 0 end
    local formatStr = "!%H:%M:%S"
    local timeStr 
    if second >= 86400 then
        local dDay = math.floor(second / 86400)
        second = second - dDay * 86400
        timeStr = dDay .. "d " .. os.date(formatStr, second)
    else
        timeStr = os.date(formatStr, second)
    end
    return timeStr
end

local LANGUAGES = {{}, {}}
local notFindCallback
--[[
    载入多语言信息
    @param  languages           string|table   多语言内容主体
    @param  updates             string|table   更新用多语言内容
--]]
function i18n.loadLanguages( languages, updates )
    if type(languages) == "string" then
        package.loaded[languages] = nil
        LANGUAGES[1] = require(languages)
    else
        LANGUAGES[1] = languages
    end
    -- 可根据项目需要调整成自动加载更新的多语言,甚至是多个多语言文件
    if updates ~= nil then
        LANGUAGES[2] = {}
    elseif type(updates) == "string" then
        package.loaded[updates] = nil
        LANGUAGES[2] = require(updates)
    else
        LANGUAGES[2] = updates
    end
end
-- 找不到key时的替换方案
function i18n.setNotFindCallback( callback )
    notFindCallback = callback
end
local function translate( key, values )
    return LANGUAGES[2][key] or LANGUAGES[1][key] 
        or (DEBUG == 2 and LANGUAGES[3] and LANGUAGES[3][key])
end
-- 扩展功能
local EXPAND_FUNCTIONS = {
    {  -- 时间格式 %time{xxxx|x}
        "%%time{.-}",
        function ( translateKey )
            local timeStr = string_sub(translateKey, 7, -2)
            local timeInfo = string_split(timeStr, "|")
            local time, format = tonumber(timeInfo[1]), timeInfo[2]
            if type(time) == "number" and time < 500000000 then
                -- 差值时间 可自行实现
                return convertSecondToString(time)
            else
                -- TODO:正常时间 请自行实现转换
                return os.date(format or "%d/%m/%Y %H:%M:%S", time)
            end
        end
    },
}
--[[
    多语言转换
    @param  key         string  多语言key
    @param  values      table  多语言设置用的值
    @param  useTemplate bool    key为模板
--]]
function i18n.translate( key, values, useTemplate ) 
    if key == "" or key == nil then return key end
    local result
    if useTemplate then
        result = key
    else
        result = translate( key, values )
        if not result and notFindCallback then
            result = translate(notFindCallback(key), values)
        end
    end
    if result then 
        if values then 
            result = string_gsub(result, "%%{.-}", function ( translateKey )
                local key = string_sub(translateKey, 3, -2)
                return table_getByPath(values, key) or translateKey
            end)
        end
        -- 扩展替换函数
        for i, v in ipairs(EXPAND_FUNCTIONS) do
            if string_find(result, v[1]) then
                result = string_gsub(result, v[1], v[2])
            end
        end
        -- 内置替换
        if string_find(result, "%%i18n{.-}") then
            result = string_gsub(result, "%%i18n{.-}", function ( translateKey )
                local key = string_sub(translateKey, 7, -2)
                if i18n.hasKey(key) then
                    return i18n.translate(key, values)
                elseif notFindCallback then
                    key = notFindCallback(key)
                    if i18n.hasKey(key) then
                        return i18n.translate(key, values)
                    end
                end
                return translateKey
            end)
        end
    end
    if result then 
        return result
    elseif DEBUG == 2 then
        return key
    else
        return key
    end
end
--[[
    是否存在指定key对应的多语言
    @param  key             string  多语言key
    @param  checkParams     bool    是否需要验证包含参数
    @return bool, bool      是否存在指定key, 是否包含参数匹配
--]]
function i18n.hasKey(key, checkParams)
    if key ~= nil and key ~= "" then
        local content = LANGUAGES[2][key] or LANGUAGES[1][key]
        local hasKey = content ~= nil
        local hasParams
        if hasKey and checkParams then
            hasParams = string_find(content, "%%{.-}") ~= nil
        end
        return hasKey, hasParams
    end
    return false
end

setmetatable(i18n, {
	__call = function ( _, key, values, useTemplate )
		return i18n.translate(key, values, useTemplate)
	end
	})

--[[
print(i18n("%time{%{time}}", {time = 850}, true))
print(i18n("%time{%{[1]}|%Y-%m %H:%M}", {os.time()}, true))
print(i18n("%time{%{time}}", {time = os.time()}, true))


local lang = {
    ["build_name_1"] = "Castle",
    ["build_name_2"] = "Building",
    ["info_build_1"] = "Info: %i18n{build_name_%{buildId}} time:%time{%{time}|%Y-%m %H:%M}",
    ["info_build_2"] = "Info: %i18n{build_name_%{[1]}} time:%time{%{[2]}|%Y-%m %H:%M}",
}

i18n.loadLanguages(lang, {})
print(i18n("build_name_1"))
print(i18n("info_build_1", {buildId = 1, time = os.time()}))
print(i18n("info_build_2", {2, os.time()}))
--]]

return i18n
