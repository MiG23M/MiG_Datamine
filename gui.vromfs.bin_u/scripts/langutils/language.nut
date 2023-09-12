//-file:plus-string
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { split_by_chars } = require("string")
let { register_command } = require("console")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { get_default_lang } = require("platform")
let { GUI } = require("%scripts/utils/configs.nut")

::g_language <- {}

let steamLanguages = freeze({
  English = "english"
  French = "french"
  Italian = "italian"
  German = "german"
  Spanish = "spanish"
  Russian = "russian"
  Polish = "polish"
  Czech = "czech"
  Turkish = "turkish"
  Chinese = "schinese"
  Japanese = "japanese"
  Portuguese = "portuguese"
  Ukrainian = "ukrainian"
  Hungarian = "hungarian"
  Korean = "koreana"
  TChinese = "tchinese"
  HChinese = "schinese"
})

local needCheckLangPack = false
let langsByChatId = {}
let langsListForInventory = {}
local currentLanguage = null
let currentLanguageW = Watched(currentLanguage)
let curLangShortName = Watched("")
local currentSteamLanguage = ""
local isListInited = false

let langsList = []
let langsById = {}


let function getLanguageName() {
  return currentLanguage
}

let function getShortName() {
  return curLangShortName.value
}

let isChineseHarmonized = @() getLanguageName() == "HChinese" //we need to check language too early when get_language from profile not work

let isVietnameseVersion = @() getLanguageName() == "Vietnamese" //we need to check language too early when get_language from profile not work

let function isChineseVersion() {
  let language = getLanguageName()
  return language == "Chinese"
    || language == "TChinese"
    || language == "Korean"
}

let canSwitchGameLocalization = @() !isPlatformSony && !isPlatformXboxOne
  && !isChineseHarmonized() && !isVietnameseVersion()

let function _addLangOnce(id, icon = null, chatId = null, hasUnitSpeech = null, isDev = false) {
  if (id in langsById)
    return

  let langInfo = ::g_language.getEmptyLangInfo()
  langInfo.id = id
  langInfo.title = "".concat(isDev ? "[DEV] " : "", loc($"language/{id}"))
  langInfo.icon = icon || ""
  langInfo.chatId = chatId || "en"
  langInfo.isMainChatId = true
  langInfo.hasUnitSpeech = !!hasUnitSpeech

  langsList.append(langInfo)
  langsById[id] <- langInfo

  if (chatId && !(chatId in langsByChatId))
    langsByChatId[chatId] <- langInfo
  else
    langInfo.isMainChatId = false
}

let function checkInitList() {
  if (isListInited)
    return
  isListInited = true

  langsList.clear()
  langsById.clear()
  langsByChatId.clear()
  langsListForInventory.clear()

  let locBlk = DataBlock()
  ::get_localization_blk_copy(locBlk)
  let ttBlk = locBlk?.text_translation ?? DataBlock()
  let existingLangs = ttBlk % "lang"

  let guiBlk = GUI.get()
  let blockName = isVietnameseVersion() ? "vietnam" : "default"
  let preset = guiBlk?.game_localization[blockName] ?? DataBlock()
  for (local l = 0; l < preset.blockCount(); l++) {
    let lang = preset.getBlock(l)
    if (isInArray(lang.id, existingLangs))
      _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech)
  }

  if (::is_dev_version) {
    let blk = guiBlk?.game_localization ?? DataBlock()
    for (local p = 0; p < blk.blockCount(); p++) {
      let devPreset = blk.getBlock(p)
      for (local l = 0; l < devPreset.blockCount(); l++) {
        let lang = devPreset.getBlock(l)
        _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech, true)
      }
    }

    foreach (langId in existingLangs)
      _addLangOnce(langId)
  }

  let curLangId = getLanguageName()
  _addLangOnce(curLangId)

  let inventoryBlk = locBlk?.inventory_abbreviated_languages_table ?? DataBlock()
  for (local l = 0; l < inventoryBlk.paramCount(); ++l) {
    let param = inventoryBlk.getParamValue(l)
    if (type(param) != "string")
      continue

    let abbrevName = inventoryBlk.getParamName(l)
    langsListForInventory[param] <- abbrevName
  }
}


let function getLangInfoById(id) {
  checkInitList()
  return langsById?[id]
}

::g_language.getCurLangInfo <- function getCurLangInfo() {
  return getLangInfoById(currentLanguage)
}

let function onChangeLanguage() {
  currentSteamLanguage = steamLanguages?[currentLanguage] ?? "english"
  currentLanguageW(currentLanguage)
}

let function saveLanguage(langName) {
  if (currentLanguage == langName)
    return
  currentLanguage = langName
  curLangShortName(loc("current_lang"))
  onChangeLanguage()
}

saveLanguage(::get_settings_blk()?.language ?? ::get_settings_blk()?.game_start?.language ?? get_default_lang())


::g_language.setGameLocalization <- function setGameLocalization(langId, reloadScene = false, suggestPkgDownload = false, isForced = false) {
  if (langId == currentLanguage && !isForced)
    return

  handlersManager.shouldResetFontsCache = true
  ::setSystemConfigOption("language", langId)
  ::set_language(langId)
  saveLanguage(langId)

  if (suggestPkgDownload)
    needCheckLangPack = true

  let handler = handlersManager.getActiveBaseHandler()
  if (reloadScene && handler)
    handler.fullReloadScene()
  else
    handlersManager.markfullReloadOnSwitchScene()

  broadcastEvent("GameLocalizationChanged")
  currentLanguageW(currentLanguage)
}

::g_language.reload <- function reload() {
  ::g_language.setGameLocalization(currentLanguage, true, false, true)
}

::g_language.onEventNewSceneLoaded <- function onEventNewSceneLoaded(_p) {
  if (!needCheckLangPack)
    return

  ::check_localization_package_and_ask_download()
  needCheckLangPack = false
}

::g_language.getEmptyLangInfo <- function getEmptyLangInfo() {
  let langInfo = {
    id = "empty"
    title = "empty"
    icon = ""
    chatId = ""
    isMainChatId = true
    hasUnitSpeech = false
  }
  return langInfo
}


::g_language.getGameLocalizationInfo <- function getGameLocalizationInfo() {
  checkInitList()
  return langsList
}


::g_language.getLangInfoByChatId <- function getLangInfoByChatId(chatId) {
  checkInitList()
  return langsByChatId?[chatId]
}

/*
  return localized text from @config (table or datablock) by id
  if text value require to be localized need to start it with #

  defaultValue returned when not fount id in config.
  if defaultValue == null  - it will return id instead

  example config:
  {
    text = "..."   //default text. returned when not found lang specific.
    text_ru = "#locId"  //russian text, taken from localization  loc("locId")
    text_en = "localized text"  //english text. already localized.
  }
*/
::g_language.getLocTextFromConfig <- function getLocTextFromConfig(config, id = "text", defaultValue = null) {
  local res = null
  let key = id + "_" + curLangShortName.value
  if (key in config)
    res = config[key]
  else
    res = config?[id] ?? res

  if (type(res) != "string")
    return defaultValue || id

  if (res.len() > 1 && res.slice(0, 1) == "#")
    return loc(res.slice(1))
  return res
}

::g_language.isAvailableForCurLang <- function isAvailableForCurLang(block) {
  if (!(block?.showForLangs ?? false))
    return true

  let availableForLangs = split_by_chars(block.showForLangs, ";")
  return isInArray(getLanguageName(), availableForLangs)
}

::g_language.onEventInitConfigs <- function onEventInitConfigs(_p) {
  isListInited = false
}

::get_current_language <- function get_current_language() {
  return getLanguageName()
}

// using from C++ to convert current language to inventory's abbreviation language
// to properly load localization for its goods
::get_abbreviated_language_for_inventory <- function get_abbreviated_language_for_inventory(fullLang) {
  local abbrevLang = "en"
  if (fullLang in ::g_language.langsListForInventory)
    abbrevLang = ::g_language.langsListForInventory[fullLang]

  return abbrevLang
}

// called from native playerProfile on language change, so at this point we can use get_language
::on_language_changed <- function on_language_changed() {
  saveLanguage(::get_language())
}

::g_language.getCurrentSteamLanguage <- function getCurrentSteamLanguage() {
  return currentSteamLanguage
}

// used in native code
::get_current_steam_language <- function get_current_steam_language() {
  return ::g_language.getCurrentSteamLanguage()
}

::g_language.__update(freeze({
  langsList
  langsById
  getLanguageName
  getShortName
}))

::cross_call_api.language <- ::g_language

subscribe_handler(::g_language, ::g_listener_priority.DEFAULT_HANDLER)

register_command(@() ::g_language.reload(), "ui.language_reload")

return {
  currentLanguageW
  curLangShortName
  isChineseHarmonized
  isVietnameseVersion
  isChineseVersion
  canSwitchGameLocalization
}
