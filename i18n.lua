--[[
    多语言处理类
    @author baochengfu
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

local LOCAL_LANGUAGE = {{}, {}}
local callbackNotFindedKeyProcess
--[[
    载入多语言信息
    @param  languages           string|table   多语言内容主体
    @param  updateLanguages     string|table   更新用多语言内容
--]]
function i18n.loadLanguages( languages, updateLanguages )
    if type(languages) == "string" then
        package.loaded[languages] = nil
        LOCAL_LANGUAGE[1] = require(languages)
    else
        LOCAL_LANGUAGE[1] = languages
    end
    -- 可根据项目需要调整成自动加载更新的多语言,甚至是多个多语言文件
    if type(updateLanguages) == "string" then
        package.loaded[updateLanguages] = nil
        LOCAL_LANGUAGE[2] = require(updateLanguages)
    else
        LOCAL_LANGUAGE[2] = updateLanguages
    end
end
-- 设置找不到key时的追加方案,可以在具体项目中增加自动适应的能力,修改成另一个key后再查找
function i18n.setNotFindedKeyProcess( callback )
    callbackNotFindedKeyProcess = callback
end
local function translate( key, values )
    return LOCAL_LANGUAGE[2][key] or LOCAL_LANGUAGE[1][key] 
        or (DEBUG == 2 and LOCAL_LANGUAGE[3] and LOCAL_LANGUAGE[3][key])
end
-- 扩展的替换规则和替换函数
local EXPAND_FUNCTIONS = {
    -- {   -- 运算
    --     "%%calc%|.-{.-}", 
    --     function ( translateKey )
    --         local valueStart = string_find(translateKey, "%|") + 1
    --         local valueEnd = string_find(translateKey, "{") - 1
    --         local value = (string_sub(translateKey, valueStart, valueEnd))
    --         local key = string_sub(translateKey, string_find(translateKey, "{") + 1, -2)
    --         return util.lambda(value)(key)
    --     end
    -- },
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
                -- return formatTimeString(format, time)
                return os.date(format or "%d/%m/%Y %H:%M:%S", time)
            end
        end
    },
}
--[[
    多语言转换
    @param  key         string  多语言key
    @param  values      table  多语言设置用的值
    @param  forceTemplate   bool    强制使用模板,即key就是模板
--]]
function i18n.translate( key, values, forceTemplate ) 
    if key == "" or key == nil then return key end
    local result
    if forceTemplate then
        result = key
    else
        result = translate( key, values )
        if not result and callbackNotFindedKeyProcess then
            result = translate(callbackNotFindedKeyProcess(key), values)
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
                elseif callbackNotFindedKeyProcess then
                    key = callbackNotFindedKeyProcess(key)
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
        local content = LOCAL_LANGUAGE[2][key] or LOCAL_LANGUAGE[1][key]
        local hasKey = content ~= nil
        local hasParams
        if hasKey and checkParams then
            hasParams = string_find(content, "%%{.-}") ~= nil
        end
        return hasKey, hasParams
    end
    return false
end
-- 弄个i18n.translate的快捷调用
setmetatable(i18n, {
	__call = function ( _, key, values, forceTemplate )
		return i18n.translate(key, values, forceTemplate)
	end
	})

--[[
print(i18n("%time{%{time}}", {time = 850}, true))
print(i18n("%time{%{[1]}|%Y-%m %H:%M}", {os.time()}, true))
print(i18n("%time{%{time}}", {time = os.time()}, true))
--]]

return i18n