//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { TIME_HOUR_IN_SECONDS } = require("%sqstd/time.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsStore.nut")
let { debriefingRows } = require("%scripts/debriefing/debriefingFull.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { register_command } = require("console")
let { is_running } = require("steam")
let { request_review } = require("%xboxLib/impl/store.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { get_charserver_time_sec } = require("chard")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")

let steamOpenReviewWnd = require("%scripts/user/steamRateGameWnd.nut")

let { addPromoAction } = require("%scripts/promo/promoActions.nut")

let logP = log_with_prefix("[ShowRate] ")
let needShowRateWnd = mkWatched(persist, "needShowRateWnd", false) //need this, because debriefing data destroys after debriefing modal is closed

let winsInARow = mkWatched(persist, "winsInARow", 0)
let haveMadeKills = mkWatched(persist, "haveMadeKills", false)
let havePurchasedSpecUnit = mkWatched(persist, "havePurchasedSpecUnit", false)
let havePurchasedPremium = mkWatched(persist, "havePurchasedPremium", false)

const RATE_WND_SAVE_ID = "seen/rateWnd"
const RATE_WND_TIME_SAVE_ID = "seen/rateWndTime"
const AFTER_IMPROVEMENT_RATE_WND_TIME_SAVE_ID = "seen/afterImprovementRateWndTime"
const MORE_IMPROVEMENT_RATE_WND_TIME_SAVE_ID = "seen/moreImprovementRateWndTime"

const SHOW_RATE_SAVE_ID = "seen/showRateWnd"
const SHOW_AFTER_IMPROVEMENT_RATE_SAVE_ID = "seen/showAfterImprovementRateWnd"
const SHOW_MORE_IMPROVEMENT_RATE_SAVE_ID = "seen/showMoreImprovementRateWnd"

const FEEDBACK_RATE_SAVE_ID = "seen/feedbackRateWnd"
const FEEDBACK_AFTER_IMPROVEMENT_RATE_SAVE_ID = "seen/feedbackAfterImprovementRateWnd"
const FEEDBACK_MORE_IMPROVEMENT_RATE_SAVE_ID = "seen/feedbackMoreImprovementRateWnd"

local isConfigInited = false
let cfg = { // Overridden by gui.blk values
  totalPvpBattlesMin = 7
  totalPlayedHoursMax = 300
  minPlaceOnWin = 3
  totalWinsInARow = 3
  minKillsNum = 1
  hideSteamRateLanguages = ""
  hideSteamRateLanguagesArray = []
  reqUnlock = ""
}

let function initConfig() {
  if (isConfigInited)
    return
  isConfigInited = true

  let guiBlk = GUI.get()
  let cfgBlk = guiBlk?.suggestion_rate_game
  foreach (k, _v in cfg)
    cfg[k] = cfgBlk?[k] ?? cfg[k]
  cfg.hideSteamRateLanguagesArray = cfg.hideSteamRateLanguages.split(";")
}

let function setNeedShowRate(debriefingResult, myPlace) {
  //can be on any platform in future,
  //no need to specify platform in func name
  if ((!isPlatformXboxOne && !is_running()) || debriefingResult == null)
    return

  if (loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) ||
      loadLocalAccountSettings(AFTER_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, 0) ||
      loadLocalAccountSettings(MORE_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, 0)
  ) {
    logP("Already seen by time")
    return
  }

  if (loadLocalAccountSettings(RATE_WND_SAVE_ID, false)) {
    //Save for already seen window too
    //It must not be rewritten, because of check by time before
    saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
    logP("Already seen")
    return
  }

  initConfig()

  //Record reqUnlock will be prior before other old checks
  //Because checks such as wins or sessions could be written in unlock config
  //So no need to continue check old terms
  if (cfg.reqUnlock != "") {
    logP("Check only unlock")
    if (isUnlockOpened(cfg.reqUnlock)) {
      logP("Passed by unlock")
      needShowRateWnd(true)
    }
    return
  }

  // Newbies
  if (::my_stats.getPvpPlayed() < cfg.totalPvpBattlesMin) {
    logP("Break checks by battle stats, player is newbie")
    return
  }

  // Old players
  if (!::my_stats.isStatsLoaded()
    || (::my_stats.getTotalTimePlayedSec() / TIME_HOUR_IN_SECONDS) > cfg.totalPlayedHoursMax) {
    logP("Break checks by old player, too long playing, or no stats loaded at all")
    return
  }

  let isWin = debriefingResult?.isSucceed && (debriefingResult?.gm == GM_DOMINATION)
  if (isWin && (havePurchasedPremium.value || havePurchasedSpecUnit.value || myPlace <= cfg.minPlaceOnWin)) {
    logP($"Passed by win and prem {havePurchasedPremium.value || havePurchasedSpecUnit.value} or win and place {myPlace} condition")
    needShowRateWnd(true)
    return
  }

  if (isWin) {
    winsInARow(winsInARow.value + 1)

    local totalKills = 0
    debriefingRows.each(function(b) {
      if (b.id.contains("Kills"))
        totalKills += debriefingResult.exp?[$"num{b.id}"] ?? 0
    })

    haveMadeKills(haveMadeKills.value || totalKills >= cfg.minKillsNum)
    logP($"Update kills count {totalKills}; haveMadeKills {haveMadeKills.value}")
  }
  else {
    winsInARow(0)
    haveMadeKills(false)
  }

  if (winsInARow.value >= cfg.totalWinsInARow && haveMadeKills.value) {
    logP("Passed by wins in a row and kills")
    needShowRateWnd(true)
    return
  }
}

let function openSteamRateReview(params) {
  steamOpenReviewWnd.open(params.__merge({
    onApplyFunc = function(openedBrowser) {
      let reason = params?.reason ?? ""
      local id = "FEEDBACK_RATE_SAVE_ID"
      if(reason == "SteamRateImprove")
        id = "FEEDBACK_AFTER_IMPROVEMENT_RATE_SAVE_ID"
      if(reason == "SteamRateMoreImprove")
        id = "FEEDBACK_MORE_IMPROVEMENT_RATE_SAVE_ID"
      saveLocalAccountSettings(id, openedBrowser)

      sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam", openedBrowser, reason })
    }
  }))
}

let function tryOpenXboxRateReviewWnd() {
  if (!isPlatformXboxOne || loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) > 0)
    return false

  saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "xbox" })
  request_review(null)
  return true
}

let function implOpenSteamRateReview() {
  saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam" })
  openSteamRateReview({ descLocId = "msgbox/steam/rate_review" })
}

let function implOpenSteamAfterImprovementRateReview() {
  saveLocalAccountSettings(AFTER_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  let reasonForShow = "SteamRateImprove"
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam", reason = reasonForShow })
  openSteamRateReview({
    descLocId = "msgbox/steam/rate_review_after_improve"
    backgroundImg = "#ui/images/cat_fix"
    reason = reasonForShow
  })
}

let function implOpenSteamMoreImprovementRateReview() {
  saveLocalAccountSettings(MORE_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  let reasonForShow = "SteamRateMoreImprove"
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam", reason = reasonForShow })
  openSteamRateReview({
    descLocId = "msgbox/steam/rate_review_more_improvement"
    backgroundImg = "#ui/images/cat_fix"
    reason = reasonForShow
  })
}

let function tryOpenSteamRateReview() {
  if (!hasFeature("SteamRateGame") || loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) > 0)
    return false

  implOpenSteamRateReview()
  return true
}

let function tryOpenSteamAfterImprovementRateReview() {
  if (!hasFeature("SteamRateImprove") || loadLocalAccountSettings(AFTER_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, 0) > 0)
    return false

  implOpenSteamAfterImprovementRateReview()
  return true
}

let function tryOpenSteamMoreImprovementRateReview() {
  if (!hasFeature("SteamRateMoreImprove") || loadLocalAccountSettings(MORE_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, 0) > 0)
    return false

  implOpenSteamMoreImprovementRateReview()
  return true
}

let function forceOpenSteamRateReview() {
  implOpenSteamRateReview()
  saveLocalAccountSettings(SHOW_RATE_SAVE_ID, true)
  return true
}

let function forceOpenSteamAfterImprovementRateReview() {
  implOpenSteamAfterImprovementRateReview()
  saveLocalAccountSettings(SHOW_AFTER_IMPROVEMENT_RATE_SAVE_ID, true)
  return true
}

let function forceOpenSteamMoreImprovementRateReview() {
  implOpenSteamMoreImprovementRateReview()
  saveLocalAccountSettings(SHOW_MORE_IMPROVEMENT_RATE_SAVE_ID, true)
  return true
}

let forceOpenSteamRateReviewWnd = @() steamOpenReviewWnd.open()

let function checkShowRateWnd() {
  if (needShowRateWnd.value && isPlatformXboxOne) {
    tryOpenXboxRateReviewWnd()
    needShowRateWnd(false)
    return
  }

  if (!is_running())
    return
  if (cfg.hideSteamRateLanguagesArray.contains(getLanguageName()))
    return

  if (tryOpenSteamMoreImprovementRateReview())
    return
  if (tryOpenSteamAfterImprovementRateReview())
    return
  if (needShowRateWnd.value)
    tryOpenSteamRateReview()
  needShowRateWnd(false)
}

addListenersWithoutEnv({
  UnitBought = function(p) {
    let unit = getAircraftByName(p?.unitName)
    if (unit && ::isUnitSpecial(unit))
      havePurchasedSpecUnit(true)
  }
  EntitlementStoreItemPurchased = function(p) {
    if (getShopItem(p?.id)?.isMultiConsumable == false) //isMultiConsumable == true - eagles
      havePurchasedSpecUnit(true)
  }
  OnlineShopPurchaseSuccessful = function(p) {
    if (p?.purchData.chapter == ONLINE_SHOP_TYPES.PREMIUM)
      havePurchasedPremium(true)
  }
})

register_command(forceOpenSteamRateReviewWnd, "debug.show_steam_rate_wnd")
register_command(tryOpenXboxRateReviewWnd, "debug.show_xbox_rate_wnd")

let configPromoBlockForReviewWnd = {
  SteamRateGame = {
    isVisible = @() loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) > 0
      && !loadLocalAccountSettings(SHOW_RATE_SAVE_ID, false)
      && !loadLocalAccountSettings(FEEDBACK_RATE_SAVE_ID, true)
    show = forceOpenSteamRateReview
  }
  SteamRateImprove = {
    isVisible = @() loadLocalAccountSettings(AFTER_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, 0) > 0
      && !loadLocalAccountSettings(SHOW_AFTER_IMPROVEMENT_RATE_SAVE_ID, false)
      && !loadLocalAccountSettings(FEEDBACK_AFTER_IMPROVEMENT_RATE_SAVE_ID, true)
    show = forceOpenSteamAfterImprovementRateReview
  }
  SteamRateMoreImprove = {
    isVisible = @() loadLocalAccountSettings(MORE_IMPROVEMENT_RATE_WND_TIME_SAVE_ID, 0) > 0
      && !loadLocalAccountSettings(SHOW_MORE_IMPROVEMENT_RATE_SAVE_ID, false)
      && !loadLocalAccountSettings(FEEDBACK_MORE_IMPROVEMENT_RATE_SAVE_ID, true)
    show = forceOpenSteamMoreImprovementRateReview
  }
}

addPromoAction("steam_popup",
  function(_handler, params, _obj) {
    configPromoBlockForReviewWnd?[params?[0] ?? ""].show()
  },
  function(params) {
    return configPromoBlockForReviewWnd?[params?[0] ?? ""].isVisible() ?? false
  }
)

return {
  setNeedShowRate
  checkShowRateWnd
  tryOpenSteamRateReview
}