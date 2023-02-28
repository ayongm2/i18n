# i18n
Lua i18n多语言管理类,带简单逻辑功能,如嵌套引用多语言,时间显示等

eg.
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

------------------------------
output:
Castle
Info: Castle time:2023-02 18:03
Info: Building time:2023-02 18:03
