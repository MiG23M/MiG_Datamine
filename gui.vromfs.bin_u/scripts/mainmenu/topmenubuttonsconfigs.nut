//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { get_game_version_str } = require("app")
let { canUseIngameShop,
        getShopItemsTable,
        getEntStoreLocId,
        getEntStoreIcon,
        isEntStoreTopMenuItemHidden,
        getEntStoreUnseenIcon,
        needEntStoreDiscountIcon,
        openEntStoreTopMenuFunc } = require("%scripts/onlineShop/entitlementsStore.nut")
let contentStateModule = require("%scripts/clientState/contentState.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let { isPlatformSony,
        isPlatformPC,
        consoleRevision,
        targetPlatform } = require("%scripts/clientState/platform.nut")
let encyclopedia = require("%scripts/encyclopedia.nut")
let { openChangelog } = require("%scripts/changelog/changeLogState.nut")
let openPersonalUnlocksModal = require("%scripts/unlocks/personalUnlocksModal.nut")
let { openUrlByObj } = require("%scripts/onlineShop/url.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { getTextWithCrossplayIcon,
        needShowCrossPlayInfo,
        isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")

let { openOptionsWnd } = require("%scripts/options/handlers/optionsWnd.nut")
let topMenuHandlerClass = require("%scripts/mainmenu/topMenuHandler.nut")
let { buttonsListWatch } = require("%scripts/mainmenu/topMenuButtons.nut")
let { openCollectionsWnd, hasAvailableCollections } = require("%scripts/collections/collectionsWnd.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { isMarketplaceEnabled, goToMarketplace } = require("%scripts/items/itemsMarketplace.nut")
let { openESportListWnd } = require("%scripts/events/eSportModal.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { gui_do_debug_unlock, debug_open_url } = require("%scripts/debugTools/dbgUtils.nut")
let { isShowGoldBalanceWarning, hasMultiplayerRestritionByBalance
} = require("%scripts/user/balanceFeatures.nut")
let { isGuestLogin } = require("%scripts/user/userUtils.nut")

let template = {
  id = ""
  text = @() ""
  tooltip = @() ""
  image = @() null
  link = null
  isLink = @() false
  isFeatured = @() false
  needDiscountIcon = false
  unseenIcon = null
  onClickFunc = @(_obj, _handler = null) null
  onChangeValueFunc = @(_value) null
  isHidden = @(_handler = null) false
  isVisualDisabled = @() false
  isInactiveInQueue = false
  elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  isButton = @() this.elementType == TOP_MENU_ELEMENT_TYPE.BUTTON
  isDelayed = true
  checkbox = @() this.elementType == TOP_MENU_ELEMENT_TYPE.CHECKBOX //param name only because of checkbox.tpl
  isLineSeparator = @() this.elementType == TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
  isEmptyButton = @() this.elementType == TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  funcName = @() this.isButton() ? "onClick" : this.checkbox() ? "onChangeCheckboxValue" : null
}

let list = {
  UNKNOWN = {}
  SKIRMISH = {
    text = @() "#mainmenu/btnSkirmish"
    onClickFunc = function(_obj, handler) {
      if (!::is_custom_battles_enabled())
        return ::show_not_available_msg_box()
      if (!::check_gamemode_pkg(GM_SKIRMISH))
        return

      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      ::queues.checkAndStart(
        Callback(@() this.goForwardIfOnline(::gui_start_skirmish, false), handler),
        null,
        "isCanNewflight"
      )
    }

    isHidden = @(...) !::is_custom_battles_enabled()
    isInactiveInQueue = true
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable.value
      || hasMultiplayerRestritionByBalance()
    tooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value || hasMultiplayerRestritionByBalance())
        return loc("xbox/noMultiplayer")
      return ""
    }
  }
  WORLDWAR = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("mainmenu/btnWorldwar"))
    onClickFunc = function(_obj, handler) {
      if (!::g_world_war.checkPlayWorldwarAccess())
        return

      ::queues.checkAndStart(
        Callback(@() this.goForwardIfOnline(@() ::g_world_war.openOperationsOrQueues(), false), handler),
        null,
        "isCanNewflight"
      )
    }
    tooltip = @() ::is_worldwar_enabled() ? ::g_world_war.getCantPlayWorldwarReasonText() : ""
    isVisualDisabled = @() ::is_worldwar_enabled() && !::g_world_war.canPlayWorldwar()
    isHidden = @(...) !::is_worldwar_enabled()
    isInactiveInQueue = true
    unseenIcon = @() ::is_worldwar_enabled() && ::g_world_war.canPlayWorldwar() ?
      SEEN.WW_MAPS_AVAILABLE : null
  }
  TUTORIAL = {
    text = @() "#mainmenu/btnTutorial"
    onClickFunc = @(_obj, handler) handler.checkedNewFlight(::gui_start_tutorial)
    isHidden = @(...) !hasFeature("Tutorials")
    isInactiveInQueue = true
  }
  SINGLE_MISSION = {
    text = @() "#mainmenu/btnSingleMission"
    onClickFunc = @(_obj, handler) ::checkAndCreateGamemodeWnd(handler, GM_SINGLE_MISSION)
    isHidden = @(...) !hasFeature("ModeSingleMissions")
    isInactiveInQueue = true
  }
  DYNAMIC = {
    text = @() "#mainmenu/btnDynamic"
    onClickFunc = @(_obj, handler) ::checkAndCreateGamemodeWnd(handler, GM_DYNAMIC)
    isHidden = @(...) !hasFeature("ModeDynamic")
    isInactiveInQueue = true
  }
  CAMPAIGN = {
    text = @() "#mainmenu/btnCampaign"
    onClickFunc = function(_obj, handler) {
      if (contentStateModule.isHistoricalCampaignDownloading())
        return ::showInfoMsgBox(loc("mainmenu/campaignDownloading"), "question_wait_download")

      if (::is_any_campaign_available())
        return handler.checkedNewFlight(@() ::gui_start_campaign())
    }
    isHidden = @(...) !hasFeature("HistoricalCampaign") || !::is_any_campaign_available()
    isVisualDisabled = @() contentStateModule.isHistoricalCampaignDownloading()
    isInactiveInQueue = true
  }
  TOURNAMENTS = {
    text = @() "#mainmenu/btnTournament"
    onClickFunc = function(...) {
      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      openESportListWnd()
    }
    isHidden = @(...) !hasFeature("ESport")
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable.value
      || hasMultiplayerRestritionByBalance()
    isInactiveInQueue = true
  }
  BENCHMARK = {
    text = @() "#mainmenu/btnBenchmark"
    onClickFunc = @(_obj, handler) handler.checkedNewFlight(::gui_start_benchmark)
    isHidden = @(...) !hasFeature("Benchmark")
    isInactiveInQueue = true
  }
  USER_MISSION = {
    text = @() "#mainmenu/btnUserMission"
    onClickFunc = @(_obj, handler) ::checkAndCreateGamemodeWnd(handler, GM_USER_MISSION)
    isHidden = @(...) !hasFeature("UserMissions")
    isInactiveInQueue = true
  }
  PERSONAL_UNLOCKS = {
    text = @() "#mainmenu/btnPersonalUnlocks"
    onClickFunc = @(_obj, _handler) openPersonalUnlocksModal()
    isHidden = @(...) !hasFeature("PersonalUnlocks")
  }
  OPTIONS = {
    text = @() "#mainmenu/btnGameplay"
    onClickFunc = @(_obj, _handler) openOptionsWnd()
  }
  CONTROLS = {
    text = @() "#mainmenu/btnControls"
    onClickFunc = @(...) ::gui_start_controls()
    isHidden = @(...) !hasFeature("ControlsAdvancedSettings")
  }
  LEADERBOARDS = {
    text = @() "#mainmenu/btnLeaderboards"
    onClickFunc = @(_obj, handler) handler.goForwardIfOnline(::gui_modal_leaderboards, false, true)
    isHidden = @(...) !hasFeature("Leaderboards")
  }
  CLANS = {
    text = @() "#mainmenu/btnClans"
    onClickFunc = @(...) hasFeature("Clans") ? ::gui_modal_clans() : ::show_not_available_msg_box()
    isHidden = @(...) !hasFeature("Clans")
  }
  REPLAY = {
    text = @() "#mainmenu/btnReplays"
    onClickFunc = @(_obj, handler) isPlatformSony ? ::show_not_available_msg_box() : handler.checkedNewFlight(::gui_start_replays)
    isHidden = @(...) !hasFeature("ClientReplay")
  }
  VIRAL_AQUISITION = {
    text = @() "#mainmenu/btnGetLink"
    onClickFunc = @(...) showViralAcquisitionWnd()
    isHidden = @(...) !hasFeature("Invites") || isGuestLogin.value
  }
  CHANGE_LOG = {
    text = @() "#mainmenu/btnChangelog"
    onClickFunc = @(...) openChangelog()
    isHidden = @(...) !hasFeature("Changelog") || !::isInMenu()
  }
  EXIT = {
    text = @() "#mainmenu/btnExit"
    onClickFunc = function(...) {
      ::add_msg_box("topmenu_question_quit_game", loc("mainmenu/questionQuitGame"),
        [
          ["yes", exitGame],
          ["no", @() null ]
        ], "no", { cancel_fn = @() null })
    }
    isHidden = @(...) !isPlatformPC && !(isPlatformSony && ::is_dev_version)
  }
  DEBUG_UNLOCK = {
    text = @() "#mainmenu/btnDebugUnlock"
    onClickFunc = @(_obj, _handler) ::add_msg_box("debug unlock", "Debug unlock enabled", [["ok", gui_do_debug_unlock]], "ok")
    isHidden = @(...) !::is_dev_version
  }
  DEBUG_URL = {
    text = @() "Debug: Enter Url"
    onClickFunc = @(_obj, _handler) debug_open_url()
    isHidden = @(...) !hasFeature("DebugEnterUrl")
  }
  ENCYCLOPEDIA = {
    text = @() "#mainmenu/btnEncyclopedia"
    onClickFunc = @(...) encyclopedia.open()
    isHidden = @(...) !hasFeature("Encyclopedia")
  }
  CREDITS = {
    text = @() "#mainmenu/btnCredits"
    onClickFunc = @(_obj, handler) handler.checkedForward(::gui_start_credits)
    isHidden = @(handler = null) !hasFeature("Credits") || !(handler instanceof topMenuHandlerClass.getHandler())
  }
  TSS = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("topmenu/tss"))
    onClickFunc = function(obj, _handler) {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrlByObj(obj)
      else if (!isMultiplayerPrivilegeAvailable.value)
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@() ::showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
    }
    isDelayed = false
    link = "#url/tss"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !hasFeature("Tournaments") || ::is_me_newbie()
  }
  REPORT_AN_ISSUE = {
    text = @() loc("topmenu/reportAnIssue")
    onClickFunc = @(obj, _handler) !isPlatformPC
      ? openQrWindow({
          headerText = loc("topmenu/reportAnIssue")
          additionalInfoText = loc("qrWindow/info/reportAnIssue")
          baseUrl = loc("url/reportAnIssue", { platform = consoleRevision.len() > 0 ? $"{targetPlatform}_{consoleRevision}" : targetPlatform, version = get_game_version_str() })
          needUrlWithQrRedirect = true
        })
      : openUrlByObj(obj, true)
    isDelayed = false
    link = loc("url/reportAnIssue", { platform = consoleRevision.len() > 0 ? $"{targetPlatform}_{consoleRevision}" : targetPlatform, version = get_game_version_str() })
    isLink = @() isPlatformPC
    isFeatured = @() true
    isHidden = @(...) !hasFeature("ReportAnIssue") || (!hasFeature("AllowExternalLink") && isPlatformPC) || !::isInMenu()
  }
  STREAMS_AND_REPLAYS = {
    text = @() "#topmenu/streamsAndReplays"
    onClickFunc = @(obj, _handler) hasFeature("ShowUrlQrCode")
      ? openQrWindow({
          headerText = loc("topmenu/streamsAndReplays")
          baseUrl = loc("url/streamsAndReplays")
          needUrlWithQrRedirect = true
        })
      : openUrlByObj(obj)
    isDelayed = false
    link = "#url/streamsAndReplays"
    isLink = @() !hasFeature("ShowUrlQrCode")
    isFeatured = @() !hasFeature("ShowUrlQrCode")
    isHidden = @(...) !hasFeature("ServerReplay") || (!hasFeature("AllowExternalLink") && !hasFeature("ShowUrlQrCode"))
       || !::isInMenu()
  }
  EAGLES = {
    text = @() "#charServer/chapter/eagles"
    onClickFunc = @(_obj, handler) hasFeature("EnableGoldPurchase")
      ? handler.startOnlineShop("eagles", null, "topmenu")
      : ::showInfoMsgBox(loc("msgbox/notAvailbleGoldPurchase"))
    image = @() "#ui/gameuiskin#shop_warpoints_premium.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("SpendGold") || !::isInMenu()
  }
  PREMIUM = {
    text = @() "#charServer/chapter/premium"
    onClickFunc = @(_obj, handler) handler.startOnlineShop("premium")
    image = @() "#ui/gameuiskin#sub_premiumaccount.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("EnablePremiumPurchase") || !::isInMenu()
  }
  WARPOINTS = {
    text = @() "#charServer/chapter/warpoints"
    onClickFunc = @(_obj, handler) handler.startOnlineShop("warpoints")
    image = @() "#ui/gameuiskin#shop_warpoints.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("SpendGold") || !::isInMenu()
  }
  INVENTORY = {
    text = @() "#items/inventory"
    onClickFunc = @(...) ::gui_start_inventory()
    image = @() "#ui/gameuiskin#inventory_icon.svg"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu()
    unseenIcon = @() SEEN.INVENTORY
  }
  ITEMS_SHOP = {
    text = @() "#items/shop"
    onClickFunc = @(...) ::gui_start_itemsShop()
    image = @() "#ui/gameuiskin#store_icon.svg"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu() || !hasFeature("ItemsShopInTopMenu")
    unseenIcon = @() SEEN.ITEMS_SHOP
  }
  WORKSHOP = {
    text = @() "#items/workshop"
    onClickFunc = @(...) ::gui_start_items_list(itemsTab.WORKSHOP)
    image = @() "#ui/gameuiskin#btn_modifications.svg"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu() || !workshop.isAvailable()
    unseenIcon = @() SEEN.WORKSHOP
  }
  WARBONDS_SHOP = {
    text = @() "#mainmenu/btnWarbondsShop"
    onClickFunc = @(...) ::g_warbonds.openShop()
    image = @() "#ui/gameuiskin#wb.svg"
    isHidden = @(...) !::g_battle_tasks.isAvailableForUser()
      || !::g_warbonds.isShopAvailable()
      || !::isInMenu()
    unseenIcon = @() SEEN.WARBONDS_SHOP
  }
  ONLINE_SHOP = {
    text = getEntStoreLocId
    onClickFunc = openEntStoreTopMenuFunc
    link = ""
    isLink = @() !canUseIngameShop()
    isFeatured = @() !canUseIngameShop()
    image = getEntStoreIcon
    needDiscountIcon = needEntStoreDiscountIcon
    isHidden = isEntStoreTopMenuItemHidden
    unseenIcon = getEntStoreUnseenIcon
  }
  MARKETPLACE = {
    text = @() "#mainmenu/marketplace"
    onClickFunc = @(_obj, _handler) goToMarketplace()
    link = ""
    isLink = @() true
    isFeatured = @() true
    image = @() "#ui/gameuiskin#gc.svg"
    isHidden = @(...) !isMarketplaceEnabled() || !::isInMenu()
  }
  COLLECTIONS = {
    text = @() "#mainmenu/btnCollections"
    onClickFunc = @(...) openCollectionsWnd()
    image = @() "#ui/gameuiskin#collection.svg"
    isHidden = @(...) !hasAvailableCollections() || !::isInMenu()
  }
  WINDOW_HELP = {
    text = @() "#flightmenu/btnControlsHelp"
    onClickFunc = function(_obj, handler) {
      if (!("getWndHelpConfig" in handler))
        return

      ::gui_handlers.HelpInfoHandlerModal.open(handler.getWndHelpConfig(), handler.scene)
    }
    isHidden = @(handler = null) !("getWndHelpConfig" in handler) || !hasFeature("HangarWndHelp")
  }
  FAQ = {
    text = @() "#mainmenu/faq"
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = "#url/faq"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !::isInMenu()
  }
  SUPPORT = {
    text = @() "#mainmenu/support"
    onClickFunc = @(obj, _handler) hasFeature("ShowUrlQrCode")
      ? openQrWindow({
          headerText = loc("mainmenu/support")
          baseUrl = loc("url/support")
        })
      : openUrlByObj(obj)
    isDelayed = false
    link = "#url/support"
    isLink = @() !hasFeature("ShowUrlQrCode")
    isFeatured = @() !hasFeature("ShowUrlQrCode")
    isHidden = @(...) (!hasFeature("AllowExternalLink") && !hasFeature("ShowUrlQrCode"))
      || !::isInMenu()
  }
  WIKI = {
    text = @() "#mainmenu/wiki"
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = "#url/wiki"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !::isInMenu()
  }
  EULA = {
    text = @() "#mainmenu/licenseAgreement"
    onClickFunc = @(obj, _handler) (hasFeature("AllowExternalLink"))
      ? openUrlByObj(obj)
      : ::gui_start_eula(true)
    isDelayed = false
    link = "#url/eula"
    isLink = @() hasFeature("AllowExternalLink")
    isFeatured = true
    isHidden = @(...) !hasFeature("EulaInMenu") || !::isInMenu()
  }
  DEBUG_PS4_SHOP_DATA = {
    text = @() "Debug PS4 Data" //intentionally without localization
    onClickFunc = function(_obj, _handler) {
      let itemInfo = []
      foreach (_id, item in getShopItemsTable()) {
        itemInfo.append(item.id)
        itemInfo.append(item.imagePath)
        itemInfo.append(item.getDescription())
      }
      let data = "\n".join(itemInfo, true)
      log(data)
      ::script_net_assert("PS4 Internal debug shop data")
    }
    isHidden = @(...) !hasFeature("DebugLogPS4ShopData")
  }
  EMPTY = {
    elementType = TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  }
  LINE_SEPARATOR = {
    elementType = TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
  }
}

let fillButtonConfig = function(buttonCfg, name) {
  return template.__merge(buttonCfg.__merge({
    id = name.tolower()
    typeName = name
  }))
}

buttonsListWatch(list.map(fillButtonConfig))

return {
  addButtonConfig = function(newBtnConfig, name) {
    buttonsListWatch.value[name] <- fillButtonConfig(newBtnConfig, name)
  }
}
