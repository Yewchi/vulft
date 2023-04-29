DEV_ENVIRONMENT_LOCALE = "en"

local LOCALIZATIONS = {} -- {["zh"] = {["hi"]="nihao"}, ...}, ["ru"] = {...}}
local LOCALIZED_TO_DEV = {} -- {["zh"] = {["nihao"] = "hi"..
local locale_name_of_the_word_for_language = {} -- {["lang"] = ["en"], ...}
local locale_name_of_the_name_of_a_language_for_locales = {} -- {["en"] = {["chinese"] = "zh", ...
local language_name_of_locale_in_locale = {} -- {["zh"] = {["en"] = "yingyu", ...

-- NB no two-letter variable names allowed in file
--
-- lua data files was probably a better idea, loading one file + using backup dev langs

local function print_localize_err(str, args)
	ERROR_print(true, not VERBOSE,
			"[lang] ERROR - Attempt to register localize with a null. %s: %s",
			str, Util_PrintableTable(args)
		)
end

local function get_locale_tbl(locale)
	local localeTbl = LOCALIZATIONS[locale]
	if not localeTbl then
		WARN_print(string.format("[lang] No such locale found '%s'", locale))
	end
	return localeTbl
end

local MISSING_LOCALIZE_PRINTS_PER_LANG = 1
local missing_localize_langs_printed = {}
local function count_missing_localize(lang, str)
	missing_localize_langs_printed[lang] = missing_localize_langs_printed[lang]
			and missing_localize_langs_printed[lang] + 1 or 1
	print(missing_localize_langs_printed[lang])
	if missing_localize_langs_printed[lang] <= MISSING_LOCALIZE_PRINTS_PER_LANG then
		INFO_print(string.format(
					"[lang] Missing localization for string \"%s\" in locale '%s'. Prints: %d",
					str, lang, missing_localize_langs_printed[lang]
				)
			)
		if missing_localize_langs_printed[lang] == MISSING_LOCALIZE_PRINTS_PER_LANG
				and VERBOSE then
			print("/VULFT/ ##SQUELCHING LOCALIZE MISSING", missing_localize_langs_printed[lang], lang)
			Util_TablePrint(LOCALIZATIONS[lang])
		end
	end
end

-------- RegisterLocalize(str, lang1, translation1, lang2, translation2, ...)
function RegisterLocalize(str, ...)
	local args = {...}
	local i = 1
	if not str then
		print_localize_err(str, args)
		return;
	elseif type(str) ~= str then
		str = tostring(str)
	end
	while(i<=#args) do
		local lang = args[i]
		local translation = args[i+1]
		if not lang or not translation then
			print_localize_err(str, args)
			return;
		end
		if not LOCALIZATIONS[lang] then
			INFO_print(string.format("[lang] New locale created: '%s'", lang))
			LOCALIZATIONS[lang] = {}
		end
		LOCALIZATIONS[lang][str] = translation
		i=i+2
	end
end

function GetLocaleProperName(locale)
	if type(locale) ~= "string" or not LOCALIZATIONS[locale] then
		WARN_print(string.format("[lang] GetLocalProperName('%s'), bad arg.", tostring(locale)))
	end
	local properName = language_name_of_locale_in_locale[locale]
	return properName or locale, properName and true or false
end

function GetLocalize(str, lang)
	if not lang then
		
		lang = LOCALE
	end
	if type(lang) ~= "string" then
		ERROR_print(false, not VERBOSE,
				"[lang] Error - Non string locale name given to GetLocalize(%s, %s)",
				tostring(str), tostring(lang)
			)
		return;
	end
	lang = lang:lower()
	if str then
		if type(str) ~= str then
			str = tostring(str)
		end
	else
		ERROR_print(true, not VERBOSE, "[lang] Error - No str given to GetLocalize(%s, %s)",
				tostring(str), tostring(lang)
			)
		return;
	end
	local langTbl = get_locale_tbl(lang)
	if not langTbl or not str or not langTbl[str] then
		local langIsDev = lang == DEV_ENVIRONMENT_LOCALE
		if not langIsDev then -- Missing data, print in development lang
			count_missing_localize(lang, str)
		end
		return str, langIsDev
	end
	return langTbl[str], true
end

-- "Word", only find whole strings
-------- ConvertLocalizedWord()
function ConvertLocalizedWord(str, fromLang, toLang)
	if toLang and not fromLang then
		if toLang == _G.LOCALE then
			fromLang = DEV_ENVIRONMENT_LOCALE
		elseif toLang == DEV_ENVIRONMENT_LOCALE then
			fromLang = _G.LOCALE
		end
	elseif fromLang and not toLang then
		if fromLang == _G.LOCALE then
			toLang = DEV_ENVIRONMENT_LOCALE
		elseif fromLang == DEV_ENVIRONMENT_LOCALE then
			toLang = _G.LOCALE
		end
	end
	local fromLangTbl = get_locale_tbl(fromLang)
	local toLangTbl = get_locale_tbl(toLang)
	if not fromLangTbl or not toLangTbl then
		WARN_print(string.format("[lang] Cannot determine desired language of Lang_ConvertLocalizedWord(%s, %s, %s)",
					tostring(str), tostring(fromLang), tostring(toLang)
				)
			)
	else
		-- Got tables okay, find:
		for k,v in pairs(fromLangTbl) do -- Full locale value check. func is for rare human chat interpretation
			if v == str then
				return toLangTable[k], true
			end
		end
	end
	return str, false
end

local STR__AVAIL_CMDS = "The available locale commands are: "
RegisterLocalize(STR__AVAIL_CMDS,
		"zh", "可用的语言环境命令是: ",
		"ru", "Доступные команды локали: "
	)
RegisterLocalize("lang",
		"ru", "язык",
		"zh", "语言"
	)
local last_CLO_time = 0 
function Lang_PrintChatLocalizeOptions()
	local currTime = GameTime()
	if currTime - last_CLO_time < 4 then
		return;
	end
	last_CLO_time = currTime
	local str = GetLocalize(STR__AVAIL_CMDS)
	local enStrAll = ""
	for locale,localeTbl in pairs(LOCALIZATIONS) do
		str = string.format("%s !%s %s,",
				str,
				GetLocalize("lang", locale),
				language_name_of_locale_in_locale[locale]
			)
		enStrAll = enStrAll..locale..", "
	end
	str = string.sub(str, 1, -2)..". "..string.sub(enStrAll, 1, -3).."."
	Captain_AddChatToQueue(str, false, 0.2)
end

function Lang_IsLanguageCmd(word)
	local langWordsInLocale = locale_name_of_the_word_for_language
	for k,v in pairs(langWordsInLocale) do
		if k == word then
			return true, v
		end
	end
	return false
end

function Lang_CheckLocalizeExists(locale, withLocaleChecking)
	if type(locale) == "string" then
		local lowerLocale = string.lower(locale)
		if string.len(locale) == 2 then
			-- Find if it's a 2-char locale name
			if LOCALIZATIONS[lowerLocale] then
				return true, lowerLocale
			end
		end
		-- Find if it's a readable in the locale
		withLocaleChecking = LOCALIZATIONS[withLocaleChecking] and withLocaleChecking
				or _G.LOCALE
		local localeChecking = locale_name_of_the_name_of_a_language_for_locales[withLocaleChecking]
				or locale_name_of_the_name_of_a_language_for_locales[DEV_ENVIRONMENT_LOCALE]
		if localeChecking[locale] then
			return true, localeChecking[locale]
		end
		WARN_print(string.format("[lang] No such locale '%s' found in '%s'. Used dev locale instead: %s",
					lowerLocale, withLocaleChecking,
					not locale_name_of_the_name_of_a_language_for_locales[withLocaleChecking]
				)
			)
		Lang_PrintChatLocalizeOptions()
		return false, nil
	end
	WARN_print(string.format("[lang] locale string given Lang_CheckLocalizeExists() was not a string: %s",
				tostring(locale)
			)
		)
	return false, nil
end

-- DEV_ENVIRONMENT_LOCALE:
LOCALIZATIONS["en"] = LOCALIZATIONS["en"] or {} -- Implied, not necessary to store strs inside
locale_name_of_the_word_for_language["lang"] = "en"
locale_name_of_the_name_of_a_language_for_locales["en"] = {
		["english"] = "en",
		["russian"] = "ru",
		["chinese"] = "zh"
	}

-- DICTIONARY:
local zh = LOCALIZATIONS["zh"] or {}
LOCALIZATIONS["zh"] = zh
zh["bot"] = "底部路径"
zh["bottom"] = zh["bot"]
zh["mid"] = "中路"
zh["middle"] = zh["mid"]
zh["top"] = "顶部路径"
zh["safelane"] = "优势路"
zh["safe lane"] = zh["safelane"]
zh["jungle"] = "野区"
zh["roam"] = "游走"
zh["offlane"] = "劣势路"
zh["off lane"] = zh["offlane"]
zh["support"] = "酱油" -- "soy sauce"?????????
zh["bottle"] = "魔瓶" -- magic bottle
zh["core"] = "后期"
zh["carry"] = zh["core"]
zh["courier"] = "鸡"
zh["defence"] = "防守"
zh["defend"] = "防守"
zh["defense"] = "防守"
zh["deny"] = "反补"
zh["deward"] = "反眼"
zh["dust"] = "粉"
zh["dust of appearance"] = zh["dust"]
zh["fog"] = "雾"
zh["fow"] = zh["fog"]
zh["gank"] = "偷袭,抓"
zh["gold"] = "元"
zh["lurk"] = "蹲"
zh["nuke"] = "爆发技能"
zh["ping"] = nil--"平耀斑"
zh["power rune"] = "符"
zh["push"] = "推"
zh["role"] = "角色"
zh["pos"] = zh["role"]
zh["position"] = zh["role"]
zh["roshan"] = "肉山"
zh["smoke"] = "雾"
zh["smoke of deceit"] = zh["smoke"]
zh["stun"] = "眩晕效"
zh["support"] = "辅助"
zh["tower"] = "塔"
zh["true sight"] = "真视"
zh["observer ward"] = "黄眼" -- yellow ward
zh["sentry"] = "蓝眼" -- blue ward
zh["sentry ward"] = zh["sentry"]
zh["ward"] = "眼"

locale_name_of_the_word_for_language["语言"] = "zh"
locale_name_of_the_name_of_a_language_for_locales["zh"] = {
		["英语"] = "en",
		["俄语"] = "ru",
		["中文"] = "zh"
	}

local ru = LOCALIZATIONS["ru"] or {}
LOCALIZATIONS["ru"] = ru
ru["bot"] = "Нижняя линия"
ru["bottom"] = ru["bot"]
ru["mid"] = "Центральная линия"
ru["middle"] = ru["mid"]
ru["midlane"] = ru["mid"]
ru["mid lane"] = ru["mid"]
ru["middle lane"] = ru["mid"]
ru["top"] = "вершина линия"
ru["top lane"] = ru["top"]
ru["offlane"] = "Сложная линия"
ru["off lane"] = ru["offlane"]
ru["safelane"] = "Легкая линия"
ru["safe lane"] = ru["safelane"]
ru["ability"] = "способности"
ru["buff"] = "бафф"
ru["cooldown"] = "КД"
ru["cd"] = ru["cooldown"]
ru["courier"] = "курица"
ru["creep"] = "крип"
ru["creeps"] = "крипы"
ru["debuff"] = "дебафф"
ru["defend"] = "дефать"
ru["deny"] = "денай"
ru["dire"] = "злые"
ru["farm"] = "фарм"
ru["gank"] = "ганк" 
ru["jungle"] = "лес"
ru["map"] = "Карта"
ru["pos"] = "позиция"
ru["position"] = ru["pos"]
ru["radiant"] = "добрые"
ru["roam"] = "роумер"
ru["roamer"] = ru["roam"]
ru["role"] = ru["pos"]
ru["rune"] = "руна"
ru["tower"] = "тавер"
ru["ward"] = "вард"
ru["wardspot"] = "вардплейс"

locale_name_of_the_word_for_language["язык"] = "ru"
locale_name_of_the_name_of_a_language_for_locales["ru"] = {
		["английский"] = "en",
		["русский"] = "ru",
		["Китайский"] = "zh"
	}

for loc,readables in pairs(locale_name_of_the_name_of_a_language_for_locales) do
	for readable,lloc in pairs(readables) do
		if loc == lloc then
			language_name_of_locale_in_locale[loc] = readable -- "en" = "english"
			break;
		end
	end
end

INFO_print(string.format("[lang] lang loaded. Default locale is: '%s'", LOCALIZATIONS[LOCALE] and LOCALE or string.format("Not found! Expected \"%s\".", LOCALE)))
