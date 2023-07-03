//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

let DataBlock = require("DataBlock")
let { format, split_by_chars } = require("string")
let { ceil, floor } = require("math")
let stdMath = require("%sqstd/math.nut")
let time = require("%scripts/time.nut")
let { get_game_version, get_game_version_str } = require("app")
let { is_mplayer_host } = require("multiplayer")
let workshop = require("%scripts/items/workshop/workshop.nut")
let { updateModItem } = require("%scripts/weaponry/weaponryVisual.nut")
let workshopPreview = require("%scripts/items/workshop/workshopPreview.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { setDoubleTextToButton, setColoredDoubleTextToButton,
  placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isModResearched,
        getModificationByName,
        findAnyNotResearchedMod } = require("%scripts/weaponry/modificationInfo.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { needLogoutAfterSession, startLogout } = require("%scripts/login/logout.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { boosterEffectType, getBoostersEffects } = require("%scripts/items/boosterEffect.nut")
let { fillItemDescr, getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { setNeedShowRate } = require("%scripts/user/suggestionRateGame.nut")
let { sourcesConfig } = require("%scripts/debriefing/rewardSources.nut")
let { minValuesToShowRewardPremium, playerRankByCountries } = require("%scripts/ranks.nut")
let { getDebriefingResult, getDynamicResult, debriefingRows, isDebriefingResultFull,
gatherDebriefingResult, getCountedResultId, debriefingAddVirtualPremAcc, getTableNameById
} = require("%scripts/debriefing/debriefingFull.nut")
let { needCheckForVictory } = require("%scripts/missions/missionsUtils.nut")
let { getTournamentRewardData } = require("%scripts/userLog/userlogUtils.nut")
let { goToBattleAction,
  openLastTournamentWnd } = require("%scripts/debriefing/toBattleAction.nut")
let { checkRankUpWindow } = require("%scripts/debriefing/rankUpModal.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { hasEveryDayLoginAward } = require("%scripts/items/everyDayLoginAward.nut")
let { is_replay_turned_on, is_replay_saved, is_replay_present,
  on_save_replay, on_view_replay } = require("replays")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { is_benchmark_game_mode, get_game_mode, get_cur_game_mode_name
} = require("mission")
let { select_mission_full, stat_get_benchmark } = require("guiMission")
let { openBattlePassWnd } = require("%scripts/battlePass/battlePassWnd.nut")
let { dynamicGetLayout, dynamicGetList } = require("dynamicMission")
let { refreshUserstatUnlocks } = require("%scripts/userstat/userstat.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { stripTags, toUpper } = require("%sqstd/string.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

const DEBR_LEADERBOARD_LIST_COLUMNS = 2
const DEBR_AWARDS_LIST_COLUMNS = 3
const DEBR_MYSTATS_TOP_BAR_GAP_MAX = 6
const LAST_WON_VERSION_SAVE_ID = "lastWonInVersion"
const VISIBLE_GIFT_NUMBER = 4

enum DEBR_THEME {
  WIN       = "win"
  LOSE      = "lose"
  PROGRESS  = "progress"
}

let debriefingSkipAllAtOnce = true

let statTooltipColumnParamByType = {
  time = @(rowConfig) {
    pId = rowConfig.hideUnitSessionTimeInTooltip ? "" : "sessionTime"
    paramType = "tim"
    showEmpty = !rowConfig.hideUnitSessionTimeInTooltip
  }
  value = @(rowConfig) {
    pId = rowConfig.customValueName ?? $"{rowConfig.rowType}{rowConfig.id}"
    paramType = rowConfig.rowType
  }
  reward = @(rowConfig) {
    pId = $"{rowConfig.rewardType}{rowConfig.id}"
    paramType = rowConfig.rewardType
  }
  info = @(rowConfig) {
    pId = rowConfig?.infoName ?? ""
    paramType = rowConfig?.infoType ?? ""
  }
}

::go_debriefing_next_func <- null

::gui_start_debriefingFull <- function gui_start_debriefingFull(params = {}) {
  ::handlersManager.loadHandler(::gui_handlers.DebriefingModal, params)
}

::gui_start_debriefing_replay <- function gui_start_debriefing_replay() {
  ::gui_start_debriefing()

  ::add_msg_box("replay_question", loc("mainmenu/questionSaveReplay"), [
        ["yes", function() {
          let guiScene = ::get_gui_scene()
          guiScene.performDelayed(getroottable(), function() {
            if (::debriefing_handler != null) {
              ::debriefing_handler.onSaveReplay(null)
            }
          })
        }],
        ["no", function() { if (::debriefing_handler != null) ::debriefing_handler.onSelect(null) } ],
        ["viewAgain", function() {
          let guiScene = ::get_gui_scene()
          guiScene.performDelayed(getroottable(), function() {
            if (::debriefing_handler != null)
              ::debriefing_handler.onViewReplay(null)
          })
        }]
        ], "yes")
  ::update_msg_boxes()
}

::gui_start_debriefing <- function gui_start_debriefing() {
  if (needLogoutAfterSession.value) {
    ::destroy_session_scripted("on needLogoutAfterSession from gui_start_debriefing")
    //need delay after destroy session before is_multiplayer become false
    ::get_gui_scene().performDelayed(getroottable(), startLogout)
    return
  }

  let gm = get_game_mode()
  if (::back_from_replays != null) {
     log("gui_nav gui_start_debriefing back_from_replays");
     let temp_func = ::back_from_replays
     log("gui_nav back_from_replays = null");
     ::back_from_replays = null
     temp_func()
     ::update_gamercards()
     return
  }
  else
    log("gui_nav gui_start_debriefing back_from_replays is null");

  if (is_benchmark_game_mode()) {
    let title = ::loc_current_mission_name()
    let benchmark_data = stat_get_benchmark()
    ::gui_start_mainmenu()
    ::gui_start_modal_wnd(::gui_handlers.BenchmarkResultModal, { title = title benchmark_data = benchmark_data })
    return
  }
  if (gm == GM_CREDITS || gm == GM_TRAINING) {
     ::gui_start_mainmenu();
     return
  }
  if (gm == GM_TEST_FLIGHT) {
    if (::last_called_gui_testflight)
      ::last_called_gui_testflight()
    else
      ::gui_start_decals();
    ::update_gamercards()
    return
  }
  if (::custom_miss_flight) {
    ::custom_miss_flight = false
    ::gui_start_mainmenu()
    return
  }

  ::gui_start_debriefingFull()
}

::gui_handlers.DebriefingModal <- class extends ::gui_handlers.MPStatistics {
  sceneBlkName = "%gui/debriefing/debriefing.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  static awardsListsConfig = {
    streaks = {
      filter = {
          show = [EULT_NEW_STREAK]
          unlocks = [UNLOCKABLE_STREAK]
          filters = { popupInDebriefing = [false, null] }
          currentRoomOnly = true
          disableVisible = true
        }
      align = ALIGN.TOP
      listObjId = "awards_list_streaks"
      startplaceObId = "start_award_place_streaks"
    }
    challenges = {
      filter = {
        show = [EULT_NEW_UNLOCK]
        unlocks = [UNLOCKABLE_CHALLENGE, UNLOCKABLE_ACHIEVEMENT]
        filters = { popupInDebriefing = [false, null] }
        currentRoomOnly = true
        disableVisible = true
        checkFunc = function(userlog) { return getUnlockById(userlog.body.unlockId)?.battlePassSeason != null }
      }
      align = ALIGN.CENTER
      listObjId = "awards_list_challenges"
      startplaceObId = "start_award_place_unlocks"
    }
    unlocks = {
      filter = {
        show = [EULT_NEW_UNLOCK]
        unlocks = [UNLOCKABLE_AIRCRAFT, UNLOCKABLE_SKIN, UNLOCKABLE_DECAL, UNLOCKABLE_ATTACHABLE,
                   UNLOCKABLE_WEAPON, UNLOCKABLE_DIFFICULTY, UNLOCKABLE_ENCYCLOPEDIA, UNLOCKABLE_PILOT,
                   UNLOCKABLE_MEDAL, UNLOCKABLE_CHALLENGE, UNLOCKABLE_ACHIEVEMENT, UNLOCKABLE_TITLE, UNLOCKABLE_AWARD]
        filters = { popupInDebriefing = [false, null] }
        currentRoomOnly = true
        disableVisible = true
        checkFunc = function(userlog) { return getUnlockById(userlog.body.unlockId)?.battlePassSeason == null }
      }
      align = ALIGN.TOP
      listObjId = "awards_list_unlocks"
      startplaceObId = "start_award_place_unlocks"
    }
  }

  static armyStateAfterBattle = {
    EASAB_UNKNOWN = "unknown"
    EASAB_UNCHANGED = "unchanged"
    EASAB_RETREATING = "retreating"
    EASAB_DEAD = "dead"
  }

  isTeamplay = false
  isSpectator = false
  gameType = null
  gm = null
  mGameMode = null
  playersInfo = null //it is SessionLobby.playersInfo for debriefing statistics info

  pveRewardInfo = null
  battleTasksConfigs = {}
  shouldBattleTasksListUpdate = false

  giftItems = null
  isAllGiftItemsKnown = false

  isFirstWinInMajorUpdate = false
  isForceShowMyStatsRightBlock = false

  debugUnlocks = 0  //show at least this amount of unlocks received from userlogs even disabled.
  debriefingResult = null

  function initScreen() {
    this.debriefingResult = getDebriefingResult()
    if (this.debriefingResult == null) {
      ::script_net_assert_once("not inited debriefing result", "try to get debriefing data")
      gatherDebriefingResult()
      this.debriefingResult = getDebriefingResult()
    }
    this.gm = this.debriefingResult.gm
    this.mGameMode = this.debriefingResult.mGameMode
    this.gameType = this.debriefingResult.gameType
    this.isTeamplay = this.debriefingResult.isTeamplay
    this.isSpectator = this.debriefingResult.isSpectator
    this.playersInfo = this.debriefingResult.playersInfo
    this.isMp = this.debriefingResult.isMp
    this.isReplay = this.debriefingResult.isReplay
    this.isForceShowMyStatsRightBlock = hasFeature("Profile")

    if (::disable_network()) //for correct work in disable_menu mode
      ::update_gamercards()

    this.scene.findObject("content_frame").width = this.isForceShowMyStatsRightBlock ? "1.4@sf" : "1.0@sf"

    this.showTab("") //hide all tabs

    ::set_presence_to_player("menu")
    this.initStatsMissionParams()
    ::SessionLobby.checkLeaveRoomInDebriefing()
    ::close_cur_voicemenu()

    // Debriefing shows on on_hangar_loaded event, but looks like DoF resets in this frame too.
    // DoF changing works unstable on this frame, but works 100% good on next guiscene act.
    this.guiScene.performDelayed(this, function() { ::handlersManager.updateSceneBgBlur(true) })

    if (this.isInited)
      this.scene.findObject("debriefing_timer").setUserData(this)

    this.playerStatsObj = this.scene.findObject("stat_table")
    this.numberOfWinningPlaces = getTblValue("numberOfWinningPlaces", this.debriefingResult, -1)
    this.pveRewardInfo = getTblValue("pveRewardInfo", this.debriefingResult)
    this.giftItems = this.groupGiftsById(this.debriefingResult?.giftItemsInfo)
    foreach (idx, row in debriefingRows)
      if (row.show) {
        this.curStatsIdx = idx
        break
      }

    this.handleActiveWager()
    this.handlePveReward()

    //update title
    local resTitle = ""
    local resReward = " "
    local resTheme = DEBR_THEME.PROGRESS

    if (this.isMp) {
      let mpResult = this.debriefingResult.exp.result
      resTitle = loc("MISSION_IN_PROGRESS")

      if (this.isSpectator
           && (this.gameType & GT_VERSUS)
           && (mpResult == STATS_RESULT_SUCCESS
                || mpResult == STATS_RESULT_FAIL)) {
        if (this.isTeamplay) {
          local myTeam = Team.A
          foreach (player in this.debriefingResult.mplayers_list)
            if (getTblValue("isLocal", player, false)) {
              myTeam = player.team
              break
            }
          let winner = ((myTeam == Team.A) == this.debriefingResult.isSucceed) ? "A" : "B"
          resTitle = loc("multiplayer/team_won") + loc("ui/colon") + loc("multiplayer/team" + winner)
          resTheme = DEBR_THEME.WIN
        }
        else {
          resTitle = loc("MISSION_FINISHED")
          resTheme = DEBR_THEME.WIN
        }
      }
      else if (mpResult == STATS_RESULT_SUCCESS) {
        resTitle = loc("MISSION_SUCCESS")
        resTheme = DEBR_THEME.WIN

        let victoryBonus = (this.isMp && isDebriefingResultFull()) ? this.getMissionBonusText() : ""
        if (victoryBonus != "")
          resReward = "".concat(loc("debriefing/MissionWinReward"), loc("ui/colon"), victoryBonus)

        let currentMajorVersion = get_game_version() >> 16
        let lastWinVersion = ::load_local_account_settings(LAST_WON_VERSION_SAVE_ID, 0)
        this.isFirstWinInMajorUpdate = currentMajorVersion > lastWinVersion
        ::save_local_account_settings(LAST_WON_VERSION_SAVE_ID, currentMajorVersion)
      }
      else if (mpResult == STATS_RESULT_FAIL) {
        resTitle = loc("MISSION_FAIL")
        resTheme = DEBR_THEME.LOSE

        let loseBonus = (this.isMp && isDebriefingResultFull()) ? this.getMissionBonusText() : ""
        if (loseBonus != "")
          resReward = "".concat(loc("debriefing/MissionLoseReward"), loc("ui/colon"), loseBonus)
      }
      else if (mpResult == STATS_RESULT_ABORTED_BY_KICK) {
        resReward = colorize("badTextColor", loc("MISSION_ABORTED_BY_KICK"))
        resTheme = DEBR_THEME.LOSE
      }
      else if (mpResult == STATS_RESULT_ABORTED_BY_ANTICHEAT) {
        resReward = colorize("badTextColor", this.getKickReasonLocText())
        resTheme = DEBR_THEME.LOSE
      }
    }
    else {
      resTitle = loc(this.debriefingResult.isSucceed ? "MISSION_SUCCESS" : "MISSION_FAIL")
      resTheme = this.debriefingResult.isSucceed ? DEBR_THEME.WIN : DEBR_THEME.LOSE
    }

    this.scene.findObject("result_title").setValue(resTitle)
    this.scene.findObject("result_reward").setValue(resReward)

    this.gatherAwardsLists()

    let hasChallengeAward = this.challengesAwardsList.len() > 0
    if (hasChallengeAward)
      refreshUserstatUnlocks()

    //update mp table
    this.needPlayersTbl = this.isMp && !(this.gameType & GT_COOPERATIVE) && isDebriefingResultFull()
    this.setSceneTitle(::getCurMpTitle(), null, "dbf_title")

    if (!isDebriefingResultFull()) {
      foreach (tName in ["no_air_text", "research_list_text"]) {
        let obj = this.scene.findObject(tName)
        if (checkObj(obj))
          obj.setValue(loc("MISSION_IN_PROGRESS"))
      }
    }

    if (!this.isReplay) {
      this.setGoNext()
      if (this.gm == GM_DYNAMIC) {
        ::save_profile(true)
        if (getDynamicResult() > MISSION_STATUS_RUNNING)
          ::destroy_session_scripted("on iniScreen debriefing on finish dynCampaign")
        else
          ::g_squad_manager.setReadyFlag(true)
      }
    }
    ::first_generation <- false //for dynamic campaign
    this.isInited = false
    ::check_logout_scheduled()

    ::g_squad_utils.updateMyCountryData() //to update broken airs for squad.

    this.handleNoAwardsCaption()

    if (!this.isSpectator && !this.isReplay)
      sendBqEvent("CLIENT_BATTLE_2", "show_debriefing_screen", {
        gm = this.gm
        economicName = ::events.getEventEconomicName(this.mGameMode)
        difficulty = this.mGameMode?.difficulty ?? ::SessionLobby.getMissionData()?.difficulty ?? ""
        sessionId = this.debriefingResult?.sessionId ?? ""
        sessionTime = this.debriefingResult?.exp?.sessionTime ?? 0
        originalMissionName = ::SessionLobby.getMissionName(true)
        missionsComplete = ::my_stats.getMissionsComplete()
        result = resTheme
      })
    let sessionIdObj = this.scene.findObject("txt_session_id")
    if (sessionIdObj?.isValid())
      sessionIdObj.setValue(this.debriefingResult?.sessionId ?? "")

    ::my_stats.markStatsReset()
  }

  function gatherAwardsLists() {
    this.awardsList = []

    this.streakAwardsList = this.getAwardsList(this.awardsListsConfig.streaks.filter)

    let wpBattleTrophy = getTblValue("wpBattleTrophy", this.debriefingResult.exp, 0)
    if (wpBattleTrophy > 0)
      this.streakAwardsList.append(this.getFakeUnlockDataByWpBattleTrophy(wpBattleTrophy))

    this.challengesAwardsList = this.getAwardsList(this.awardsListsConfig.challenges.filter)
    this.unlocksAwardsList = this.getAwardsList(this.awardsListsConfig.unlocks.filter)

    ::showBtnTable(this.scene, {
      [this.awardsListsConfig.streaks.listObjId] = this.streakAwardsList.len() > 0,
      [this.awardsListsConfig.challenges.listObjId] = this.challengesAwardsList.len() > 0,
      [this.awardsListsConfig.unlocks.listObjId] = this.unlocksAwardsList.len() > 0,
    })

    if(this.unlocksAwardsList.len() == 0) {
      let listObj = this.scene.findObject(this.awardsListsConfig.streaks.listObjId)
      listObj["margin-left"] = "pw/2 - w/2"
    }

    if(this.streakAwardsList.len() == 0) {
      let listObj = this.scene.findObject(this.awardsListsConfig.unlocks.listObjId)
      listObj["margin-left"] = "pw/2 - w/2"
    }

    this.awardsList.extend(this.streakAwardsList)
    this.awardsList.extend(this.challengesAwardsList)
    this.awardsList.extend(this.unlocksAwardsList)

    this.awardsData = []
    if (this.streakAwardsList.len() > 0)
      this.awardsData.append({
        list = this.streakAwardsList
        config = this.awardsListsConfig.streaks
      })

    if (this.unlocksAwardsList.len() > 0)
      this.awardsData.append({
        list = this.unlocksAwardsList
        config = this.awardsListsConfig.unlocks
      })

    if (this.challengesAwardsList.len() > 0)
      this.awardsData.append({
        list = this.challengesAwardsList
        config = this.awardsListsConfig.challenges
      })

    if (this.awardsData.len() == 0)
      return

    let awardsItem = this.awardsData.pop()
    this.currentAwardsList = awardsItem.list
    this.currentAwardsListConfig = awardsItem.config
  }

  function getFakeUnlockData(config) {
    let res = {}
    foreach (key, value in ::default_unlock_data)
      res[key] <- (key in config) ? config[key] : value
    foreach (key, value in config)
      if (!(key in res))
        res[key] <- value
    return res
  }

  getFakeUnlockDataByWpBattleTrophy = @(wpBattleTrophy) this.getFakeUnlockData({
    iconStyle = ::trophyReward.getWPIcon(wpBattleTrophy)
    title = loc("debriefing/BattleTrophy"),
    desc = loc("debriefing/BattleTrophy/desc"),
    rewardText = Cost(wpBattleTrophy).toStringWithParams({ isWpAlwaysShown = true }),
  })

  function getAwardsList(filter) {
    let res = []
    local logsList = ::getUserLogsList(filter)
    logsList = ::combineSimilarAwards(logsList)
    for (local i = logsList.len() - 1; i >= 0; i--)
      res.append(::build_log_unlock_data(logsList[i]))

    //add debugUnlocks
    if (!::is_dev_version || this.debugUnlocks <= res.len())
      return res

    let dbgFilter = clone filter
    dbgFilter.currentRoomOnly = false
    logsList = ::getUserLogsList(dbgFilter)
    if (!logsList.len()) {
      dlog("Not found any unlocks in userlogs for debug") // warning disable: -forbidden-function
      return res
    }

    let addAmount = this.debugUnlocks - res.len()
    for (local i = 0; i < addAmount; i++)
      res.append(::build_log_unlock_data(logsList[i % logsList.len()]))

    return res
  }

  function handleNoAwardsCaption() {
    local text = ""
    local color = ""

    if (getTblValue("haveTeamkills", this.debriefingResult, false)) {
      text = loc("debriefing/noAwardsCaption")
      color = "bad"
    }
    else if (this.debriefingResult?.exp.eacKickMessage != null) {
      text = "".concat(this.getKickReasonLocText(), "\n",
        loc("multiplayer/reason"), loc("ui/colon"),
        colorize("activeTextColor", this.debriefingResult.exp.eacKickMessage))

      if (hasFeature("AllowExternalLink") && !::is_vendor_tencent())
        ::showBtn("btn_no_awards_info", true, this.scene)
      else
        text = "".concat(text, "\n",
          loc("msgbox/error_link_format_game"), loc("ui/colon"), loc("url/support/easyanticheat"))

      color = "bad"
    }
    else if (this.pveRewardInfo && this.pveRewardInfo.warnLowActivity) {
      text = loc("debriefing/noAwardsCaption/noMinActivity")
      color = "userlog"
    }

    if (text == "")
      return

    let blockObj = ::showBtn("no_awards_block", true, this.scene)
    let captionObj = blockObj && blockObj.findObject("no_awards_caption")
    if (!checkObj(captionObj))
      return
    captionObj.setValue(text)
    captionObj.overlayTextColor = color
  }

  function getKickReasonLocText() {
    if (this.debriefingResult?.exp.eacKickMessage != null)
      return loc("MISSION_ABORTED_BY_KICK/EAC")
    return loc("MISSION_ABORTED_BY_KICK/AC")
  }

  function onNoAwardsInfoBtn() {
    if (this.debriefingResult?.exp.eacKickMessage != null)
      openUrl(loc("url/support/easyanticheat/kick_reasons"), false, false, "support_eac")
  }

  function reinitTotal() {
    if (!this.is_show_my_stats())
      return

    if (this.state != debrState.showMyStats && this.state != debrState.showBonuses)
      return

    //find and update Total
    this.totalRow = this.getDebriefingRowById("Total")
    if (!this.totalRow)
      return

    let premTeaser = this.getPremTeaserInfo()

    this.totalCurValues = this.totalCurValues || {}
    this.totalTarValues = {}

    foreach (currency in [ "exp", "wp" ]) {
      foreach (suffix in [ "", "Teaser" ])
        if (!(currency + suffix in this.totalCurValues))
          this.totalCurValues[currency + suffix] <- 0

      let totalKey = getCountedResultId(this.totalRow, this.state, currency)
      this.totalCurValues[currency] <- getTblValue(currency, this.totalCurValues, 0)
      this.totalTarValues[currency] <- getTblValue(totalKey, this.debriefingResult.counted_result_by_debrState, 0)
      this.totalCurValues[currency + "Teaser"] <- getTblValue(currency + "Teaser", this.totalCurValues, 0)
      this.totalTarValues[currency + "Teaser"] <- premTeaser[currency]
    }

    let canSuggestPrem = this.canSuggestBuyPremium()

    local tooltip = ""
    if (canSuggestPrem) {
      let currencies = []
      if (premTeaser.exp > 0)
        currencies.append(Cost().setRp(premTeaser.exp).tostring())
      if (premTeaser.wp  > 0)
        currencies.append(Cost(premTeaser.wp).tostring())
      tooltip = loc("debriefing/PremiumNotEarned") + loc("ui/colon") + "\n" + loc("ui/comma").join(currencies, true)
    }

    this.totalObj = this.scene.findObject("wnd_total")
    let markup = handyman.renderCached("%gui/debriefing/debriefingTotals.tpl", {
      showTeaser = canSuggestPrem && premTeaser.isPositive
      canSuggestPrem = canSuggestPrem
      exp = Cost().setRp(this.totalCurValues["exp"]).tostring()
      wp  = Cost(this.totalCurValues["wp"]).tostring()
      expTeaser = Cost().setRp(premTeaser.exp).toStringWithParams({ isColored = false })
      wpTeaser  = Cost(premTeaser.wp).toStringWithParams({ isColored = false })
      teaserTooltip = tooltip
    })
    this.guiScene.replaceContentFromText(this.totalObj, markup, markup.len(), this)
    this.updateTotal(0.0)
  }

  function handleActiveWager() {
    let activeWagerData = getTblValue("activeWager", this.debriefingResult, null)
    if (!activeWagerData)
      return

    let wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null) // This can happen if item ended and was removed from shop.
      return

    let containerObj = this.scene.findObject("active_wager_container")
    if (!checkObj(containerObj))
      return

    containerObj.show(true)

    let iconObj = containerObj.findObject("active_wager_icon")
    if (checkObj(iconObj))
      wager.setIcon(iconObj, { bigPicture = false })

    let wagerResult = activeWagerData.wagerResult
    let isWagerHasResult = wagerResult != null
    let isResultSuccess = wagerResult == "WagerWin" || wagerResult == "WagerStageWin"
    let isWagerEnded = wagerResult == "WagerWin" || wagerResult == "WagerFail"

    if (isWagerHasResult)
      this.showActiveWagerResultIcon(isResultSuccess)

    let tooltipObj = containerObj.findObject("active_wager_tooltip")
    if (checkObj(tooltipObj)) {
      tooltipObj.setUserData(activeWagerData)
      tooltipObj.enable(!isWagerEnded && isWagerHasResult)
    }

    if (!isWagerHasResult)
      containerObj.tooltip = loc("debriefing/wager_result_will_be_later")
    else if (isWagerEnded) {
      local endedWagerText = activeWagerData.wagerText
      endedWagerText += "\n" + loc("items/wager/numWins", {
        numWins = activeWagerData.wagerNumWins,
        maxWins = wager.maxWins
      })
      endedWagerText += "\n" + loc("items/wager/numFails", {
        numFails = activeWagerData.wagerNumFails,
        maxFails = wager.maxFails
      })
      containerObj.tooltip = endedWagerText
    }

    this.handleActiveWagerText(activeWagerData)
    this.updateMyStatsTopBarArrangement()
  }

  function handleActiveWagerText(activeWagerData) {
    let wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    let wagerResult = activeWagerData.wagerResult
    if (wagerResult != "WagerWin" && wagerResult != "WagerFail")
      return
    let textObj = this.scene.findObject("active_wager_text")
    if (checkObj(textObj))
      textObj.setValue(activeWagerData.wagerText)
  }

  function onWagerTooltipOpen(obj) {
    if (!checkObj(obj))
      return
    let activeWagerData = obj.getUserData()
    if (activeWagerData == null)
      return
    let wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    this.guiScene.replaceContent(obj, "%gui/items/itemTooltip.blk", this)
    fillItemDescr(wager, obj, this)
  }

  function showActiveWagerResultIcon(success) {
    let iconObj = this.scene.findObject("active_wager_result_icon")
    if (!checkObj(iconObj))
      return
    iconObj["background-image"] = success ? "#ui/gameuiskin#favorite" : "#ui/gameuiskin#icon_primary_fail.svg"
  }

  function handlePveReward() {
    let isVisible = !!this.pveRewardInfo && this.pveRewardInfo.isVisible

    this.showSceneBtn("pve_trophy_block", isVisible)
    if (! isVisible)
      return

    let trophyItemReached =  ::ItemsManager.findItemById(this.pveRewardInfo.reachedTrophyName)
    let trophyItemReceived = ::ItemsManager.findItemById(this.pveRewardInfo.receivedTrophyName)

    this.fillPveRewardProgressBar()
    this.fillPveRewardTrophyChest(trophyItemReached)
    this.fillPveRewardTrophyContent(trophyItemReceived, this.pveRewardInfo.isRewardReceivedEarlier)
  }

  function handleGiftItems() {
    if (!this.giftItems || this.isAllGiftItemsKnown)
      return
    let obj = this.scene.findObject("inventory_gift_icon")
    let leftBlockHeight = this.scene.findObject("left_block").getSize()[1]
    let itemHeight = ::g_dagui_utils.toPixels(this.guiScene, "1@itemHeight")

    obj.smallItems = this.challengesAwardsList.len() > 0 ? "yes"
      : (itemHeight * this.giftItems.len() > leftBlockHeight / 2) ? "yes"
      : "no"

    local giftsMarkup = ""
    let showLen = min(this.giftItems.len(), VISIBLE_GIFT_NUMBER)
    this.isAllGiftItemsKnown = true
    for (local i = 0; i < showLen; i++) {
      let markup = ::trophyReward.getImageByConfig(this.giftItems[i], false)
      this.isAllGiftItemsKnown = this.isAllGiftItemsKnown && markup != ""
      giftsMarkup += markup
    }
    this.guiScene.replaceContentFromText(obj, giftsMarkup, giftsMarkup.len(), this)
  }

  function onEventItemsShopUpdate(_p) {
    if (this.state >= debrState.showMyStats)
      this.handleGiftItems()
    if (this.state >= debrState.done)
      this.updateInventoryButton()
  }

  function onViewRewards() {
    ::gui_start_open_trophy_rewards_list({ rewardsArray = this.giftItems })
  }

  function groupGiftsById(items) {
    if (!items)
      return null

    let res = [items[0]]
    for (local i = 1; i < items.len(); i++) {
      local isRepeated = false
      foreach (r in res)
        if (items[i].item == r.item) {
          r.count += items[i].count
          isRepeated = true
        }

      if (!isRepeated)
        res.append(items[i])
    }
    return res
  }

  function openGiftTrophy() {
    if (!this.giftItems?[0]?.needOpen)
      return

    let trophyItemId = this.giftItems[0].item
    let filteredLogs = ::getUserLogsList({
      show = [EULT_OPEN_TROPHY]
      currentRoomOnly = true
      disableVisible = true
      checkFunc = function(userlog) { return trophyItemId == userlog.body.id }
    })

    if (filteredLogs.len() == 0)
      return

    ::gui_start_open_trophy({ [trophyItemId] = filteredLogs })
  }

  function onEventTrophyContentVisible(params) {
    if (this.giftItems?[0]?.item && this.giftItems[0].item == params?.trophyItem?.id)
      this.fillTrophyContentDiv(params.trophyItem, "inventory_gift_icon")
  }

  function fillPveRewardProgressBar() {
    let pveTrophyPlaceObj = this.showSceneBtn("pve_trophy_progress", true)
    if (!pveTrophyPlaceObj)
      return

    let receivedTrophyName = this.pveRewardInfo.receivedTrophyName
    let rewardTrophyStages = this.pveRewardInfo.stagesTime
    let showTrophiesOnBar  = ! this.pveRewardInfo.isRewardReceivedEarlier
    let maxValue = this.pveRewardInfo.victoryStageTime
    let stage = rewardTrophyStages.len() ? [] : null
    foreach (_stageIndex, val in rewardTrophyStages) {
      let isVictoryStage = val == maxValue

      let text = isVictoryStage ? loc("debriefing/victory")
       : time.secondsToString(val, true, true)

      let trophyName = ::get_pve_trophy_name(val, isVictoryStage)
      let isReceivedInLastBattle = trophyName && trophyName == receivedTrophyName
      let trophy = showTrophiesOnBar && trophyName ?
        ::ItemsManager.findItemById(trophyName, itemType.TROPHY) : null

      stage.append({
        posX = val.tofloat() / maxValue
        text = text
        trophy = trophy ? trophy.getNameMarkup(0, false) : null
        isReceived = isReceivedInLastBattle
      })
    }

    let view = {
      maxValue = maxValue
      value = 0
      stage = stage
    }

    let data = handyman.renderCached("%gui/debriefing/pveReward.tpl", view)
    this.guiScene.replaceContentFromText(pveTrophyPlaceObj, data, data.len(), this)
  }

  function fillPveRewardTrophyChest(trophyItem) {
    let isVisible = !!trophyItem
    let trophyPlaceObj = this.showSceneBtn("pve_trophy_chest", isVisible)
    if (!isVisible || !trophyPlaceObj)
      return

    let imageData = trophyItem.getOpenedBigIcon()
    this.guiScene.replaceContentFromText(trophyPlaceObj, imageData, imageData.len(), this)
  }

  function fillPveRewardTrophyContent(trophyItem, isRewardReceivedEarlier) {
    this.showSceneBtn("pve_award_already_received", isRewardReceivedEarlier)
    this.fillTrophyContentDiv(trophyItem, "pve_trophy_content")
  }

  function fillTrophyContentDiv(trophyItem, containerObjId) {
    let trophyContentPlaceObj = this.showSceneBtn(containerObjId, !!trophyItem)
    if (!trophyItem || !trophyContentPlaceObj)
      return

    local layersData = ""
    let filteredLogs = ::getUserLogsList({
      show = [EULT_OPEN_TROPHY]
      currentRoomOnly = true
      checkFunc = function(userlog) { return trophyItem.id == userlog.body.id }
    })

    foreach (logObj in filteredLogs) {
      let layer = ::trophyReward.getImageByConfig(logObj, false)
      if (layer != "") {
        layersData += layer
        break
      }
    }

    let layerId = "item_place_container"
    local layerCfg = LayersIcon.findLayerCfg(trophyItem.iconStyle + "_" + layerId)
    if (!layerCfg)
      layerCfg = LayersIcon.findLayerCfg(layerId)

    let data = LayersIcon.genDataFromLayer(layerCfg, layersData)
    this.guiScene.replaceContentFromText(trophyContentPlaceObj, data, data.len(), this)
  }

  function updatePvEReward(dt) {
    if (!this.pveRewardInfo)
      return
    let pveTrophyPlaceObj = this.scene.findObject("pve_trophy_progress")
    if (!checkObj(pveTrophyPlaceObj))
      return

    let newSliderObj = pveTrophyPlaceObj.findObject("new_progress_box")
    if (!checkObj(newSliderObj))
      return

    let targetValue = this.pveRewardInfo.sessionTime
    local newValue = 0
    if (this.skipAnim)
      newValue = targetValue
    else
      newValue = ::blendProp(newSliderObj.getValue(), targetValue, this.statsTime, dt).tointeger()

    newSliderObj.setValue(newValue)
  }

  function switchTab(tabName) {
    if (this.state != debrState.done)
      return
    let tabsObj = this.scene.findObject("tabs_list")
    if (!checkObj(tabsObj))
      return
    for (local i = 0; i < tabsObj.childrenCount(); i++)
      if (tabsObj.getChild(i).id == tabName)
        return tabsObj.setValue(i)
  }

  function showTab(tabName) {
    foreach (name in this.tabsList) {
      let obj = this.scene.findObject(name + "_tab")
      if (!obj)
        continue
      let isShow = name == tabName
      obj.show(isShow)
      this.updateScrollableObjects(obj, name, isShow)
    }
    this.curTab = tabName
    this.updateListsButtons()

    if (this.state == debrState.done)
      this.isModeStat = tabName == "players_stats"
  }

  function animShowTab(tabName) {
    let obj = this.scene.findObject(tabName + "_tab")
    if (!obj)
      return

    obj.show(true)
    obj["color-factor"] = "0"
    obj["_transp-timer"] = "0"
    obj["animation"] = "show"
    this.curTab = tabName

    this.guiScene.playSound("deb_players_off")
  }

  function onUpdate(_obj, dt) {
    this.needPlayCount = false
    if (this.isSceneActiveNoModals() && this.debriefingResult) {
      if (this.state != debrState.done && !this.updateState(dt))
        this.switchState()
      this.updateTotal(dt)
    }
    this.playCountSound(this.needPlayCount)
  }

  function playCountSound(play) {
    if (isPlatformSony)
      return

    play = play && !this.isInProgress
    if (play != this.isCountSoundPlay) {
      if (play)
        ::start_gui_sound("deb_count")
      else
        ::stop_gui_sound("deb_count")
      this.isCountSoundPlay = play
    }
  }

  function updateState(dt) {
    switch (this.state) {
      case debrState.showPlayers:
        return this.updatePlayersTable(dt)

      case debrState.showAwards:
        return this.updateAwards(dt)

      case debrState.showMyStats:
        return this.updateMyStats(dt)

      case debrState.showBonuses:
        return this.updateBonusStats(dt)
    }
    return false
  }

  function switchState() {
    if (this.state >= debrState.done)
      return

    this.state++
    this.statsTimer = 0
    this.reinitTotal()

    if (this.state == debrState.showPlayers) {
      this.loadAwardsList()
      this.loadBattleTasksList()

      if (!this.needPlayersTbl)
        return this.switchState()

      this.showTab("players_stats")
      this.skipAnim = this.skipAnim && debriefingSkipAllAtOnce
      if (!this.skipAnim)
        this.guiScene.playSound("deb_players_on")
      this.initPlayersTable()
      this.loadBattleLog()
      this.loadChatHistory()
      this.loadWwCasualtiesHistory()
    }
    else if (this.state == debrState.showAwards) {
      this.showSceneBtn("btn_show_all", this.giftItems != null && this.giftItems.len() > VISIBLE_GIFT_NUMBER)

      if (!this.is_show_my_stats() || !this.is_show_awards_list())
        return this.switchState()

      this.skipAnim = this.skipAnim && debriefingSkipAllAtOnce
      if (this.awardDelay * this.awardsList.len() > this.awardsAppearTime)
        this.awardDelay = this.awardsAppearTime / this.awardsList.len()
    }
    else if (this.state == debrState.showMyStats) {
      if (!this.is_show_my_stats())
        return this.switchState()

      this.showTab("my_stats")
      this.skipAnim = this.skipAnim && debriefingSkipAllAtOnce
      ::showBtnTable(this.scene, {
        left_block              = this.is_show_left_block()
        inventory_gift_block    = this.is_show_inventory_gift()
        my_stats_awards_block   = this.is_show_awards_list()
        right_block             = this.is_show_right_block()
        battle_tasks_block      = this.is_show_battle_tasks_list()
        researches_scroll_block = this.is_show_research_list()
      })
      this.showMyPlaceInTable()
      this.updateMyStatsTopBarArrangement()
      this.handleGiftItems()
    }
    else if (this.state == debrState.showBonuses) {
      this.statsTimer = this.statsBonusDelay

      if (!this.is_show_my_stats())
        return this.switchState()
      if (!this.totalRow)
        return this.switchState()

      let objPlace = this.scene.findObject("bonus_ico_place")
      if (!checkObj(objPlace))
        return this.switchState()

      //Gather rewards info:
      let textArray = []

      if (this.debriefingResult.mulsList.len())
        textArray.append(loc("bonus/xpFirstWinInDayMul/tooltip"))

      let bonusNames = {
        premAcc = "charServer/chapter/premium"
        premMod = "modification/premExpMul"
        booster = "itemTypes/booster"
      }
      let tblTotal = getTblValue("tblTotal", this.debriefingResult.exp, {})
      let bonusesTotal = []
      foreach (bonusType in [ "premAcc", "premMod", "booster" ]) {
        let bonusExp = getTblValue(bonusType + "Exp", tblTotal, 0)
        let bonusWp  = getTblValue(bonusType + "Wp",  tblTotal, 0)
        if (!bonusExp && !bonusWp)
          continue
        bonusesTotal.append(loc(getTblValue(bonusType, bonusNames, "")) + loc("ui/colon") +
          Cost(bonusWp, 0, bonusExp).tostring())
      }
      if (!u.isEmpty(bonusesTotal))
        textArray.append("\n".join(bonusesTotal, true))

      let boostersText = this.getBoostersText()
      if (!u.isEmpty(boostersText))
        textArray.append(boostersText)

      if (u.isEmpty(textArray)) //no bonus
        return this.switchState()

      if (!isDebriefingResultFull() &&
          !((this.gameType & GT_RACE) &&
            this.debriefingResult.exp.result == STATS_RESULT_IN_PROGRESS))
        textArray.append(loc("debriefing/most_award_after_battle"))

      textArray.insert(0, loc("charServer/chapter/bonuses"))

      objPlace.show(true)
      this.updateMyStatsTopBarArrangement()

      let objTarget = objPlace.findObject("bonus_ico")
      if (checkObj(objTarget)) {
        objTarget["background-image"] = havePremium.value ?
          "#ui/gameuiskin#medal_premium" : "#ui/gameuiskin#medal_bonus"
        objTarget.tooltip = "\n\n".join(textArray, true)
      }

      if (!this.skipAnim) {
        let objStart = this.scene.findObject("start_bonus_place")
        ::create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = this.statsBonusTime })
        this.guiScene.playSound("deb_medal")
      }
    }
    else if (this.state == debrState.done) {
      ::showBtnTable(this.scene, {
        btn_skip = false
        skip_button   = false
        start_bonus_place = false
      })

      this.updateStartButton()
      this.fillLeaderboardChanges()
      this.updateInfoText()
      this.updateBuyPremiumAwardButton()
      this.showTabsList()
      this.updateListsButtons()
      this.fillResearchingMods()
      this.fillResearchingUnits()
      this.updateShortBattleTask()
      this.updateInventoryButton()

      this.checkPopupWindows()
      this.throwBattleEndEvent()
      this.guiScene.performDelayed(this, function() { this.ps4SendActivityFeed() })
      let tabsObj = this.getObj("tabs_list")
      ::move_mouse_on_child(tabsObj, tabsObj.getValue())
    }
    else
      this.skipAnim = this.skipAnim && debriefingSkipAllAtOnce
  }

  function ps4SendActivityFeed() {
    if (!isPlatformSony
      || !this.isMp
      || !this.debriefingResult
      || this.debriefingResult.exp.result != STATS_RESULT_SUCCESS)
      return

    let config = {
      locId = "win_session"
      subType = ps4_activity_feed.MISSION_SUCCESS
    }
    let customConfig = {
      blkParamName = "VICTORY"
    }

    if (this.isFirstWinInMajorUpdate) {
      config.locId = "win_session_after_update"
      config.subType = ps4_activity_feed.MISSION_SUCCESS_AFTER_UPDATE
      customConfig.blkParamName = "MAJOR_UPDATE"
      let ver = split_by_chars(get_game_version_str(), ".")
      customConfig.version <- ver[0] + "." + ver[1]
      customConfig.imgSuffix <- "_" + ver[0] + "_" + ver[1]
      customConfig.shouldForceLogo <- true
    }

    activityFeedPostFunc(config, customConfig, bit_activity.PS4_ACTIVITY_FEED)
  }

  function updateMyStats(dt) {
    if (this.curStatsIdx < 0)
      return false //nextState

    this.statsTimer -= dt

    this.updatePvEReward(dt)

    local haveChanges = false
    let upTo = min(this.curStatsIdx, debriefingRows.len() - 1)
    for (local i = 0; i <= upTo; i++)
      if (debriefingRows[i].show)
        haveChanges = !this.updateStat(debriefingRows[i], this.playerStatsObj, this.skipAnim ? 10 * dt : dt, i == upTo) || haveChanges

    if (haveChanges || this.curStatsIdx < debriefingRows.len()) {
      if ((this.statsTimer < 0 || this.skipAnim) && this.curStatsIdx < debriefingRows.len()) {
        do
          this.curStatsIdx++
        while (this.curStatsIdx < debriefingRows.len() && !debriefingRows[this.curStatsIdx].show)
        this.statsTimer += this.statsNextTime
      }
      return true
    }
    return false
  }

  function updateBonusStats(dt) {
    this.statsTimer -= dt
    if (this.statsTimer < 0 || this.skipAnim) {
      local haveChanges = false
      foreach (row in debriefingRows)
        if (row.show)
          haveChanges = !this.updateStat(row, this.playerStatsObj, this.skipAnim ? 10 * dt : dt, false) || haveChanges
      return haveChanges
    }
    return true
  }

  function updateStat(row, tblObj, dt, needScroll) {
    local finished = true
    local justCreated = false
    let rowId = "row_" + row.id
    local rowObj = tblObj.findObject(rowId)

    if (!("curValues" in row) || !checkObj(rowObj))
      row.curValues <- { value = 0, reward = 0 }
    if (!checkObj(rowObj)) {
      this.guiScene.setUpdatesEnabled(false, false)
      rowObj = this.guiScene.createElementByObject(tblObj, "%gui/debriefing/statRow.blk", "tr", this)
      rowObj.id = rowId
      rowObj.findObject("tooltip_").id = "tooltip_" + row.id
      rowObj.findObject("name").setValue(row.getName())

      if (!this.debriefingResult.needRewardColumn)
        this.guiScene.destroyElement(rowObj.findObject(row.canShowRewardAsValue ? "td_value" : "td_reward"))
      justCreated = true

      if ("tooltip" in row)
        rowObj.title = loc(row.tooltip)

      local rowProps = getTblValue("rowProps", row, null)
      if (u.isFunction(rowProps))
        rowProps = rowProps()

      if (rowProps != null)
        foreach (name, value in rowProps)
          rowObj[name] = value
      this.guiScene.setUpdatesEnabled(true, true)
    }
    if (needScroll)
      rowObj.scrollToView()

    foreach (p in ["value", "reward"]) {
      let obj = rowObj.findObject(p)
      if (!checkObj(obj))
        continue

      local targetValue = 0
      if (p != "value" || isInArray(row.rowType, ["wp", "exp", "gold"])) {
        let tblKey = getCountedResultId(row, this.state, p == "value" ? row.rowType : row.rewardType)
        targetValue = getTblValue(tblKey, this.debriefingResult.counted_result_by_debrState, 0)
      }

      if (targetValue == 0)
        targetValue = this.getStatValue(row, p)

      if (targetValue == null || (!justCreated && targetValue == row.curValues[p]))
        continue

      local nextValue = 0
      if (!this.skipAnim) {
        nextValue = ::blendProp(row.curValues[p], targetValue, row.isOverall ? this.totalStatsTime : this.statsTime, dt)
        if (nextValue != targetValue)
          finished = false
        if (p != "value" || !isInArray(row.rowType, ["mul", "tim", "pct", "ptm", "tnt"]))
          nextValue = nextValue.tointeger()
      }
      else
        nextValue = targetValue

      row.curValues[p] = nextValue
      let showEmpty = ((p == "value") != row.isOverall) && row.isVisibleWhenEmpty()
      local paramType = p == "value" ? row.rowType : row.rewardType

      if (row.isFreeRP && paramType == "exp")
        paramType = "frp" //show exp as FreeRP currency

      local text = this.getTextByType(nextValue, paramType, showEmpty)
      obj.setValue(text)
    }
    this.needPlayCount = this.needPlayCount || !finished
    return finished
  }

  function getStatValue(row, name, tgtName = null) {
    if (!tgtName)
      tgtName = "base"
    return !u.isTable(row[name]) ? row[name] : getTblValue(tgtName, row[name], null)
  }

  function getTextByType(value, paramType, showEmpty = false) {
    if (!showEmpty && (value == 0 || (value == 1 && paramType == "mul")))
      return ""
    switch (paramType) {
      case "wp":  return Cost(value).toStringWithParams({ isWpAlwaysShown = true })
      case "gold": return Cost(0, value).toStringWithParams({ isGoldAlwaysShown = true })
      case "exp": return Cost().setRp(value).tostring()
      case "frp": return Cost().setFrp(value).tostring()
      case "num": return value.tostring()
      case "sec": return value + loc("debriefing/timeSec")
      case "mul": return "x" + value
      case "pct": return (100.0 * value + 0.5).tointeger() + "%"
      case "tim": return time.secondsToString(value, false)
      case "ptm": return time.getRaceTimeFromSeconds(value)
      case "tnt": return stdMath.roundToDigits(value * ::KG_TO_TONS, 3).tostring()
    }
    return ""
  }

  function updateTotal(dt) {
    if (!this.isInited && (!this.totalCurValues || u.isEqual(this.totalCurValues, this.totalTarValues)))
      return

    if (this.isInited) {
      let country = this.getDebriefingCountry()
      if (country in playerRankByCountries && playerRankByCountries[country] >= ::max_country_rank) {
        this.totalTarValues.exp = this.getStatValue(this.totalRow, "exp", "prem")
        dt = 1000 //force fast blend
      }
    }

    let cost = Cost()
    foreach (p in [ "exp", "wp", "expTeaser", "wpTeaser" ])
      if (this.totalCurValues[p] != this.totalTarValues[p]) {
        this.totalCurValues[p] = this.skipAnim ? this.totalTarValues[p] :
          ::blendProp(this.totalCurValues[p], this.totalTarValues[p], this.totalStatsTime, dt).tointeger()

        let obj = this.totalObj.findObject(p)
        if (checkObj(obj)) {
          cost.wp = p.indexof("wp") != null ? this.totalCurValues[p] : 0
          cost.rp = p.indexof("exp") != null ? this.totalCurValues[p] : 0
          obj.setValue(cost.toStringWithParams({ isColored = p.indexof("Teaser") == null }))
        }
        this.needPlayCount = true
      }
  }

  function getModExp(airData) {
    if (getTblValue("expModuleCapped", airData, false))
      return airData.expInvestModule
    return airData.expModsTotal //expModsTotal recounted by bonus mul.
  }

  function fillResearchingMods() {
    if (!isDebriefingResultFull())
      return

    let usedUnitsList = []
    foreach (unitId, unitData in this.debriefingResult.exp.aircrafts) {
      let unit = getAircraftByName(unitId)
      if (unit && this.isShowUnitInModsResearch(unitId))
        usedUnitsList.append({ unit = unit, unitData = unitData })
    }

    usedUnitsList.sort(function(a, b) {
      let haveInvestA = a.unitData.investModuleName == ""
      let haveInvestB = b.unitData.investModuleName == ""
      if (haveInvestA != haveInvestB)
        return haveInvestA ? 1 : -1
      let expA = a.unitData.expTotal
      let expB = b.unitData.expTotal
      if (expA != expB)
        return (expA > expB) ? -1 : 1
      return 0
    })

    let tabObj = this.scene.findObject("modifications_objects_place")
    this.guiScene.replaceContentFromText(tabObj, "", 0, this)
    foreach (data in usedUnitsList)
      this.fillResearchMod(tabObj, data.unit, data.unitData)
  }

  function fillResearchingUnits() {
    if (!isDebriefingResultFull())
      return

    let obj = this.scene.findObject("air_item_place")
    local data = ""
    let unitItems = []
    foreach (ut in unitTypes.types) {
      let unitItem = this.getResearchUnitMarkupData(ut.name)
      if (unitItem) {
        data += ::build_aircraft_item(unitItem.id, unitItem.unit, unitItem.params)
        unitItems.append(unitItem)
      }
    }

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(obj.findObject(unitItem.id), unitItem.unit, unitItem.params)

    if (!unitItems.len()) {
      let expInvestUnitTotal = this.getExpInvestUnitTotal()
      if (expInvestUnitTotal > 0) {
        let msg = format(loc("debriefing/all_units_researched"),
          Cost().setRp(expInvestUnitTotal).tostring())
        let noUnitObj = this.scene.findObject("no_air_text")
        if (checkObj(noUnitObj))
          noUnitObj.setValue(stripTags(msg))
      }
    }
  }

  function onEventUnitBought(_p) {
    this.fillResearchingUnits()
  }

  function onEventUnitRented(_p) {
    this.fillResearchingUnits()
  }

  function isShowUnitInModsResearch(unitId) {
    let unitData = this.debriefingResult.exp.aircrafts?[unitId]
    return unitData?.expTotal && unitData?.sessionTime &&
      ((unitData?.investModuleName ?? "") != "" ||
      ::SessionLobby.isUsedPlayersOwnUnit(this.playersInfo?[::my_user_id_int64], unitId))
  }

  function hasAnyFinishedResearch() {
    if (!this.debriefingResult)
      return false
    foreach (ut in unitTypes.types) {
      let unit = getTblValue("unit", this.getResearchUnitInfo(ut.name))
      if (unit && !::isUnitInResearch(unit))
        return true
    }
    foreach (unitId, unitData in this.debriefingResult.exp.aircrafts) {
      let modName = getTblValue("investModuleName", unitData, "")
      if (modName == "")
        continue
      let unit = getAircraftByName(unitId)
      let mod = unit && getModificationByName(unit, modName)
      if (unit && mod && isModResearched(unit, mod))
        return true
    }
    return false
  }

  function getExpInvestUnitTotal() {
    local res = 0
    foreach (_unitId, unitData in this.debriefingResult.exp.aircrafts)
      res += unitData?.expInvestUnitTotal ?? 0
    return res
  }

  function getResearchUnitInfo(unitTypeName) {
    let unitId = this.debriefingResult?.exp["investUnitName" + unitTypeName] ?? ""
    let unit = getAircraftByName(unitId)
    if (!unit)
      return null
    local expInvest = this.debriefingResult?.exp["expInvestUnit" + unitTypeName] ?? 0
    expInvest = this.applyItemExpMultiplicator(expInvest)
    if (expInvest <= 0)
      return null
    return { unit = unit, expInvest = expInvest }
  }

  function getResearchUnitMarkupData(unitTypeName) {
    let info = this.getResearchUnitInfo(unitTypeName)
    if (!info)
      return null

    return {
      id = info.unit.name
      unit = info.unit
      params = {
        diffExp = info.expInvest
        tooltipParams = {
          researchExpInvest = info.expInvest
          boosterEffects = this.getBoostersTotalEffects()
        }
      }
    }
  }

  function applyItemExpMultiplicator(itemExp) {
    local multBonus = 0
    if (this.debriefingResult.mulsList.len() > 0)
      foreach (_idx, table in this.debriefingResult.mulsList)
        multBonus += getTblValue("exp", table, 0)

    itemExp = multBonus == 0 ? itemExp : itemExp * multBonus
    return itemExp
  }

  function getResearchModFromAirData(air, airData) {
    let curResearch = airData.investModuleName
    if (curResearch != "")
      return getModificationByName(air, curResearch)
    return null
  }

  function fillResearchMod(holderObj, unit, airData) {
    let unitId = unit.name
    let mod = this.getResearchModFromAirData(unit, airData)
    let diffExp = mod ? this.getModExp(airData) : 0
    let isCompleted = mod ? getTblValue("expModuleCapped", airData, false) : false

    let view = {
      id = unitId
      unitImg = ::image_for_air(unit)
      unitName = ::stringReplace(::getUnitName(unit), ::nbsp, " ")
      hasModItem = mod != null
      isCompleted = isCompleted
      unitTooltipId = ::g_tooltip.getIdUnit(unit.name, { boosterEffects = this.getBoostersTotalEffects() })
      modTooltipId =  mod
        ? MODIFICATION.getTooltipId(unit.name, mod.name, { diffExp = diffExp, curEdiff = this.getCurrentEdiff() })
        : ""
      isTooltipByHold = ::show_console_buttons
    }

    let markup = handyman.renderCached("%gui/debriefing/modificationProgress.tpl", view)
    this.guiScene.appendWithBlk(holderObj, markup, this)
    let obj = holderObj.findObject(unitId)

    if (mod) {
      let modObj = obj.findObject("mod_" + unitId)
      updateModItem(unit, mod, modObj, false, this, this.getParamsForModItem(diffExp))
    }
    else {
      local msg = "debriefing/but_all_mods_researched"
      if (findAnyNotResearchedMod(unit))
        msg = "debriefing/but_not_any_research_active"
      msg = format(loc(msg), Cost().setRp(this.getModExp(airData) || airData.expTotal).tostring())
      obj.findObject("no_mod_text").setValue(msg)
    }
  }

  function getCurrentEdiff() {
    return ::get_mission_mode()
  }

  function onEventModBought(p) {
    let unitId = getTblValue("unitName", p, "")
    let modId = getTblValue("modName", p, "")
    this.updateResearchMod(unitId, modId)
  }

  function onEventUnitModsRecount(p) {
    this.updateResearchMod(p?.unit.name, "")
  }

  function updateResearchMod(unitId, modId) {
    let airData = this.debriefingResult?.exp.aircrafts[unitId]
    if (!airData)
      return
    let unit = getAircraftByName(unitId)
    let mod = this.getResearchModFromAirData(unit, airData)
    if (!mod || (modId != "" && modId != mod.name))
      return

    let obj = this.scene.findObject("research_list")
    let modObj = checkObj(obj) ? obj.findObject("mod_" + unitId) : null
    if (!checkObj(modObj))
      return
    let diffExp = this.getModExp(airData)
    updateModItem(unit, mod, modObj, false, this, this.getParamsForModItem(diffExp))
  }

  function getParamsForModItem(diffExp) {
    return { diffExp = diffExp, limitedName = false, curEdiff = this.getCurrentEdiff() }
  }

  function fillLeaderboardChanges() {
    let lbWindgetsNestObj = this.scene.findObject("leaderbord_stats")
    if (!checkObj(lbWindgetsNestObj))
      return

    let logs = ::getUserLogsList({
        show = [EULT_SESSION_RESULT]
        currentRoomOnly = true
      })

    if (logs.len() == 0)
      return

    let { tournamentResult = null, eventId = null } = logs[0]
    if (tournamentResult == null || ::events.getEvent(eventId)?.leaderboardEventTable != null)
      return

    let gapSides = this.guiScene.calcString("@tablePad", null)
    let gapMid   = this.guiScene.calcString("@debrPad", null)
    let gapsPerRow = gapSides * 2 + gapMid * (DEBR_LEADERBOARD_LIST_COLUMNS - 1)

    let posFirst  = format("%d, %d", gapSides, gapMid)
    let posCommon = format("%d, %d", gapMid,   gapMid)
    let itemParams = {
      width  = format("(pw - %d) / %d", gapsPerRow, DEBR_LEADERBOARD_LIST_COLUMNS)
      pos    = posCommon
      margin = "0"
    }

    let now = tournamentResult.newStat
    let was = tournamentResult.oldStat

    let lbDiff = ::leaderboarsdHelpers.getLbDiff(now, was)
    let items = []
    foreach (lbFieldsConfig in ::events.eventsTableConfig) {
      if (!(lbFieldsConfig.field in now)
        || !::events.checkLbRowVisibility(lbFieldsConfig, { eventId }))
        continue

      let isFirstInRow = items.len() % DEBR_LEADERBOARD_LIST_COLUMNS == 0
      itemParams.pos = isFirstInRow ? posFirst : posCommon

      items.append(::getLeaderboardItemView(lbFieldsConfig,
        now[lbFieldsConfig.field],
        getTblValue(lbFieldsConfig.field, lbDiff, null),
        itemParams))
    }
    lbWindgetsNestObj.show(true)

    let blk = ::getLeaderboardItemWidgets({ items = items })
    this.guiScene.replaceContentFromText(lbWindgetsNestObj, blk, blk.len(), this)
    lbWindgetsNestObj.scrollToView()
  }

  function onSkip() {
    this.skipAnim = true
  }

  function checkShowTooltip(obj) {
    let showTooltip = this.skipAnim || this.state == debrState.done
    obj["class"] = showTooltip ? "" : "empty"
    return showTooltip
  }

  function onTrTooltipOpen(obj) {
    if (!this.checkShowTooltip(obj) || !this.debriefingResult)
      return

    let id = ::getTooltipObjId(obj)
    if (!id)
      return
    if (!("exp" in this.debriefingResult) || !("aircrafts" in this.debriefingResult.exp)) {
      obj["class"] = "empty"
      return
    }

    let tRow = this.getDebriefingRowById(id)
    if (!tRow || tRow.hideTooltip) {
      obj["class"] = "empty"
      return
    }

    let rowsCfg = []
    if (!tRow.joinRows) {
      if (tRow.isCountedInUnits) {
        foreach (unitId, unitData in this.debriefingResult.exp.aircrafts)
          rowsCfg.append({
            row     = tRow
            name    = ::getUnitName(unitId)
            expData = unitData
            unitId  = unitId
          })
      }
      else {
        rowsCfg.append({
          row     = tRow
          name    = tRow.getName()
          expData = this.debriefingResult.exp
        })
      }
    }

    if (tRow.joinRows || tRow.tooltipExtraRows) {
      let extraRows = []
      if (tRow.joinRows)
        extraRows.extend(tRow.joinRows)
      if (tRow.tooltipExtraRows)
        extraRows.extend(tRow.tooltipExtraRows())

      foreach (extId in extraRows) {
        let extraRow = this.getDebriefingRowById(extId)
        if (extraRow.show || extraRow.showInTooltips)
          rowsCfg.append({
            row     = extraRow
            name    = extraRow.getName()
            expData = this.debriefingResult.exp
          })
      }
    }

    if (!rowsCfg.len()) {
      obj["class"] = "empty"
      return
    }

    let tooltipView = {
      rows = this.getTrTooltipRowsView(rowsCfg, tRow)
      tooltipComment = tRow.tooltipComment ? tRow.tooltipComment() : null
    }

    let markup = handyman.renderCached("%gui/debriefing/statRowTooltip.tpl", tooltipView)
    this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }

  function getTrTooltipRowsView(rowsCfg, tRow) {
    let view = []

    let boosterEffects = this.getBoostersTotalEffects()

    foreach (cfg in rowsCfg) {
      let rowView = {
        name = cfg.name
      }

      let rowTbl = cfg.expData?[getTableNameById(cfg.row)]

      foreach (currency in [ "exp", "wp" ]) {
        if (cfg.row.rowType != currency && cfg.row.rewardType != currency)
          continue
        let currencySourcesView = []
        foreach (source in [ "noBonus", "premAcc", "premMod", "booster" ]) {
          let val = rowTbl?[$"{source}{toUpper(currency, 1)}"] ?? 0
          if (val <= 0)
            continue
          local extra = ""
          if (source == "booster") {
            let effect = getTblValue((currency == "exp" ? "xp" : currency) + "Rate", boosterEffects, 0)
            if (effect)
              extra = colorize("fadedTextColor", loc("ui/parentheses", { text = effect.tointeger().tostring() + "%" }))
          }
          currencySourcesView.append((sourcesConfig?[source] ?? {}).__merge({ text = $"{this.getTextByType(val, currency)}{extra}" }))
        }
        if (currencySourcesView.len() > 1) {
          if (!("bonuses" in rowView))
            rowView.bonuses <- []
          rowView.bonuses.append({ sources = currencySourcesView })
        }
      }

      let extraBonuses = tRow.tooltipRowBonuses(cfg?.unitId, cfg.expData)
      if (extraBonuses) {
        if (!("bonuses" in rowView))
          rowView.bonuses <- []
        rowView.bonuses.append(extraBonuses)
      }

      foreach (p in ["time", "value", "reward", "info"]) {
        let { paramType, pId, showEmpty = false } = statTooltipColumnParamByType[p](cfg.row)
        rowView[p] <- this.getTextByType(cfg.expData?[pId] ?? 0, paramType, showEmpty)
      }

      view.append(rowView)
    }

    let showColumns = { time = false, value = false, reward = false, info = false }
    foreach (rowView in view)
      foreach (col, _isShow in showColumns)
        if (!u.isEmpty(rowView[col]))
          showColumns[col] = true
    foreach (rowView in view)
      foreach (col, isShow in showColumns)
        if (isShow && u.isEmpty(rowView[col]))
          rowView[col] = ::nbsp

    let headerRow = { name = colorize("fadedTextColor", loc("options/unit")) }
    foreach (col, isShow in showColumns) {
      local title = ""
      if (isShow)
        title = col == "value" ? tRow.getIcon()
          : col == "time" ? loc("icon/timer")
          : ""
      headerRow[col] <- colorize("fadedTextColor", title)
    }
    view.insert(0, headerRow)

    return view
  }

  function getDebriefingRowById(id) {
    return u.search(debriefingRows, @(row) row.id == id)
  }

  function getPremTeaserInfo() {
    let totalWp = this.debriefingResult.exp?.wpTotal  ?? 0
    let totalRp = this.debriefingResult.exp?.expTotal ?? 0
    let virtPremAccWp = this.debriefingResult.exp?.tblTotal.virtPremAccWp  ?? 0
    let virtPremAccRp = this.debriefingResult.exp?.tblTotal.virtPremAccExp ?? 0

    let totalWithPremWp = (totalWp <= 0 || virtPremAccWp <= 0) ? 0 : (totalWp + virtPremAccWp)
    let totalWithPremRp = (totalRp <= 0 || virtPremAccRp <= 0) ? 0 : (totalRp + virtPremAccRp)

    return {
      exp  = totalWithPremRp
      wp   = totalWithPremWp
      isPositive = totalWithPremRp > 0 || totalWithPremWp > 0
    }
  }

  function canSuggestBuyPremium() {
    return !havePremium.value && hasFeature("SpendGold") && hasFeature("EnablePremiumPurchase") && isDebriefingResultFull()
  }

  function updateBuyPremiumAwardButton() {
    let isShow = this.canSuggestBuyPremium() && this.gm == GM_DOMINATION && this.checkPremRewardAmount()

    let obj = this.scene.findObject("buy_premium")
    if (!checkObj(obj))
      return

    obj.show(isShow)
    if (!isShow)
      return

    let curAwardText = this.getCurAwardText()

    let btnObj = obj.findObject("btn_buy_premium_award")
    if (checkObj(btnObj))
      btnObj.findObject("label").setValue(loc("mainmenu/earn") + "\n" + curAwardText)

    this.updateMyStatsTopBarArrangement()
  }

  function getEntitlementWithAward() {
    let priceBlk = ::OnlineShopModel.getPriceBlk()
    let l = priceBlk.blockCount()
    for (local i = 0; i < l; i++)
      if (priceBlk.getBlock(i)?.allowBuyWithAward)
        return priceBlk.getBlock(i).getBlockName()
    return null
  }

  function checkPremRewardAmount() {
    if (!this.getEntitlementWithAward())
      return false
    if (::get_premium_reward_wp() >= minValuesToShowRewardPremium.value.wp)
      return true
    let exp = ::get_premium_reward_xp()
    return exp >= minValuesToShowRewardPremium.value.exp
  }

  function onBuyPremiumAward() {
    if (havePremium.value)
      return
    let entName = this.getEntitlementWithAward()
    if (!entName) {
      assert(false, "Error: not found entitlement with premium award")
      return
    }

    let ent = getEntitlementConfig(entName)
    let entNameText = getEntitlementName(ent)
    let price = Cost(0, ent?.goldCost ?? 0)
    let cb = Callback(this.onBuyPremiumAward, this)

    let msgText = format(loc("msgbox/EarnNow"), entNameText, this.getCurAwardText(), price.getTextAccordingToBalance())
    this.msgBox("not_all_mapped", msgText,
    [
      ["ok", function() {
        if (!::check_balance_msgBox(price, cb))
          return false

        this.taskId = ::purchase_entitlement_and_get_award(entName)
        if (this.taskId >= 0) {
          ::set_char_cb(this, this.slotOpCb)
          this.showTaskProgressBox()
          this.afterSlotOp = function() { this.addPremium() }
        }
      }],
      ["cancel", @() null]
    ], "ok", { cancel_fn = @() null })
  }

  function addPremium() {
    if (!havePremium.value)
      return

    debriefingAddVirtualPremAcc()

    foreach (row in debriefingRows)
      if (!row.show)
        this.showSceneBtn("row_" + row.id, row.show)

    this.updateBuyPremiumAwardButton()
    this.reinitTotal()
    this.skipAnim = false
    this.state = debrState.showBonuses - 1
    this.switchState()
    ::update_gamercards()
  }

  function updateAwards(dt) {
    this.statsTimer -= dt

    if (this.statsTimer < 0 || this.skipAnim) {
      if (this.awardsList && this.curAwardIdx < this.awardsList.len()) {
        if (this.currentAwardsListIdx >= this.currentAwardsList.len()) {
          if (this.awardsData.len() == 0)
            return false

          let awardsItem = this.awardsData.pop()
          this.currentAwardsList = awardsItem.list
          this.currentAwardsListConfig = awardsItem.config

          if (this.challengesAwardsList.len() > 0)
            this.scene.findObject("btn_challenge_div").show(true)

          this.currentAwardsListIdx = 0
        }

        let giftsCount = this.giftItems?.len() ?? 0
        local awardSize = null
        if(this.currentAwardsListConfig == this.awardsListsConfig.challenges
          && this.currentAwardsList.len() == 1 && giftsCount == 0)
            awardSize = "2@debriefingUnlockIconSize"

        this.addAward(awardSize)
        this.statsTimer += this.awardDelay
        this.curAwardIdx++
        this.currentAwardsListIdx++
      }
      else if (this.curAwardIdx == this.awardsList.len()) {
        //finish awards update
        this.statsTimer += this.nextWndDelay
        this.curAwardIdx++
      }
      else
        return false
    }
    return true
  }

  function countAwardsOffset(obj, tgtObj, axis) {
    let size = obj.getSize()
    let maxSize = tgtObj.getSize()
    let awardSize = size[axis] * this.currentAwardsList.len()

    if(axis == 0)
      this.awardShift = max(0, (maxSize[0] - awardSize) / 2)

    //WARNING! Change the allotted height for unlock icons to the height of the workshop button if there are gifts
    let giftsCount = this.giftItems?.len() ?? 0
    if(axis == 1)
      maxSize[1] = maxSize[1] - to_pixels("0.2@debriefingUnlockIconSize") - (giftsCount > 0 ? to_pixels("1@navBarBattleButtonHeight") : 0)

    if (awardSize > maxSize[axis] && this.currentAwardsList.len() > 1)
      this.awardOffset = ((maxSize[axis] - awardSize) / (this.currentAwardsList.len() - 1) - 1).tointeger()
    else
      tgtObj[axis ? "height" : "width"] = awardSize.tostring()
  }

  function addAward(awardSize = null) {
    let config = this.currentAwardsList[this.currentAwardsListIdx]
    let objId = $"award_{this.curAwardIdx}"

    let listObj = this.scene.findObject(this.currentAwardsListConfig.listObjId)
    let obj = this.guiScene.createElementByObject(listObj, "%gui/debriefing/awardIcon.blk", "awardPlace", this)
    obj.id = objId

    let tooltipObj = obj.findObject("tooltip_")
    tooltipObj.id = $"tooltip_{this.curAwardIdx}"
    tooltipObj.setUserData(config)

    if ("needFrame" in config && config.needFrame)
      obj.findObject("move_part")["class"] = "unlockFrame"

    if (awardSize != null) {
      obj.size = $"{awardSize}, {awardSize}"
      listObj.size = $"pw, {awardSize}"
      this.guiScene.applyPendingChanges(false)
    }

    let align = this.currentAwardsListConfig.align
    let axis = (align == ALIGN.TOP || align == ALIGN.BOTTOM) ? 1 : 0
    if (this.currentAwardsListIdx == 0) //firstElem
      this.countAwardsOffset(obj, listObj, axis)
    else if (align == ALIGN.LEFT && this.awardOffset != 0)
      obj.pos = $"{this.awardOffset}, 0"
    else if (align == ALIGN.TOP && this.awardOffset != 0)
      obj.pos = $"0, {this.awardOffset}"

    if (align == ALIGN.CENTER)
      obj.pos = $"{this.currentAwardsListIdx == 0 ? this.awardShift : this.awardOffset} , 0"

    if (align == ALIGN.RIGHT)
      if (this.currentAwardsListIdx == 0)
        obj.pos = "pw - w, 0"
      else
        obj.pos = $"-2w -{this.awardOffset} ,0"

    let icoObj = obj.findObject("award_img")
    ::set_unlock_icon_by_config(icoObj, config, false, to_pixels(awardSize ?? "1@debriefingUnlockIconSize"))
    let awMultObj = obj.findObject("award_multiplier")
    if (checkObj(awMultObj)) {
      let show = config.amount > 1
      awMultObj.show(show)
      if (show) {
        let amObj = awMultObj.findObject("amount_text")
        if (checkObj(amObj))
          amObj.setValue($"x{config.amount}")
      }
    }

    if (!this.skipAnim) {
      let objStart = this.scene.findObject(this.currentAwardsListConfig.startplaceObId)
      let objTarget = obj.findObject("move_part")
      ::create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = this.awardFlyTime })

      obj["_size-timer"] = "0"
      obj.width = "0"
      this.guiScene.playSound("deb_achivement")
    }
  }

  function onGotoChallenge() {
    this.goBack()
    openBattlePassWnd({ currSheet = "challenges_sheet" })
  }

  function onViewAwards(_obj) {
    this.switchTab("awards_list")
  }

  function onAwardTooltipOpen(obj) {
    if (!this.checkShowTooltip(obj))
      return

    let config = obj.getUserData()
    ::build_unlock_tooltip_by_config(obj, config, this)
  }

  function buildPlayersTable() {
    this.playersTbl = []
    this.curPlayersTbl = [[], []]
    this.updateNumMaxPlayers(true)
    if (this.isTeamplay) {
      for (local t = 0; t < 2; t++) {
        let tbl = this.getMplayersList(t + 1)
        this.sortTable(tbl)
        this.playersTbl.append(tbl)
      }
    }
    else {
      this.sortTable(this.debriefingResult.mplayers_list)
      this.playersTbl.append([])
      this.playersTbl.append([])
      foreach (i, player in this.debriefingResult.mplayers_list) {
        let tblIdx = i >= this.numMaxPlayers ? 1 : 0
        this.playersTbl[tblIdx].append(player)
      }
    }

    foreach (tbl in this.playersTbl)
      foreach (player in tbl) {
        player.state = PLAYER_IN_FLIGHT //dont need to show laast player state in debriefing.
        player.isDead = false
      }
  }

  function initPlayersTable() {
    this.initStats()

    if (this.needPlayersTbl)
      this.buildPlayersTable()

    this.updatePlayersTable(0.0)
  }

  function updatePlayersTable(dt) {
    if (!this.playersTbl || !this.debriefingResult)
      return false

    this.statsTimer -= dt
    this.minPlayersTime -= dt
    if (this.statsTimer <= 0 || this.skipAnim) {
      if (this.playersTblDone)
        return this.minPlayersTime > 0

      this.playersTblDone = true
      for (local t = 0; t < 2; t++) {
        let idx = this.curPlayersTbl[t].len()
        if (idx in this.playersTbl[t])
          this.curPlayersTbl[t].append(this.playersTbl[t][idx])
        this.playersTblDone = this.playersTblDone && this.curPlayersTbl[t].len() == this.playersTbl[t].len()
      }
      this.updateStats({ playersTbl = this.curPlayersTbl, playersInfo = this.playersInfo }, this.debriefingResult.mpTblTeams,
        this.debriefingResult.friendlyTeam)
      this.statsTimer += this.playersRowTime
    }
    return true
  }

  function getMyPlace() {
    local place = 0
    if (this.playersTbl)
      foreach (t, tbl in this.playersTbl)
        foreach (i, player in tbl)
          if (("isLocal" in player) && player.isLocal) {
            place = i + 1
            if (!this.isTeamplay && t)
              place += this.playersTbl[0].len()
            break
          }

    return place
  }

  function showMyPlaceInTable() {
    if (!this.is_show_my_stats())
      return

    let place = this.getMyPlace()
    let hasPlace = place != 0

    let label = hasPlace && this.isTeamplay ? loc("debriefing/placeInMyTeam")
      : hasPlace && !this.isTeamplay ? (loc("mainmenu/btnMyPlace") + loc("ui/colon"))
      : !isDebriefingResultFull() ? loc("debriefing/preliminaryResults")
      : loc(this.debriefingResult.isSucceed ? "debriefing/victory" : "debriefing/defeat")

    let objTarget = this.scene.findObject("my_place_move_box")
    objTarget.show(true)
    this.scene.findObject("my_place_label").setValue(label)
    this.scene.findObject("my_place_in_mptable").setValue(hasPlace ? place.tostring() : "")

    if (!this.skipAnim && hasPlace) {
      let objStart = this.scene.findObject("my_place_move_box_start")
      ::create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = this.myPlaceTime })
    }
  }

  function updateMyStatsTopBarArrangement() {
    if (!this.is_show_my_stats())
      return

    let containerObj = this.scene.findObject("my_stats_top_bar")
    let myPlaceObj = this.scene.findObject("my_place_move_box")
    let topBarNestObj = this.scene.findObject("top_bar_nest")
    if (!checkObj(containerObj) || !checkObj(myPlaceObj) || !checkObj(topBarNestObj))
      return
    let total = containerObj.childrenCount()
    if (total < 2)
      return
    this.guiScene.applyPendingChanges(false)

    local visible = 0
    for (local i = 0; i < total; i++) {
      let obj = containerObj.getChild(i)
      if (checkObj(obj) && obj.isVisible())
        visible++
    }

    let isSingleRow = visible < 3
    let gapMin = 1.0
    let debrTopBarGAPMax = isSingleRow ? 3 : DEBR_MYSTATS_TOP_BAR_GAP_MAX
    let maxValue = isSingleRow ? 1 : 2
    let contentPadStr = isSingleRow ? "debrBarContentPad" : "debrPad"

    let gapMax = gapMin * debrTopBarGAPMax
    let gap = clamp(stdMath.lerp(total, maxValue, gapMin, gapMax, visible), gapMin, gapMax)
    let pos = $"{gap}@{contentPadStr}, 0.5ph-0.5h"

    for (local i = 0; i < containerObj.childrenCount(); i++) {
      let obj = containerObj.getChild(i)
      if (checkObj(obj))
        obj["pos"] = pos
    }

    if (isSingleRow) {                  //Single row
      topBarNestObj.flow = "horisontal"
      local totalWidth = 0.5 * (myPlaceObj.getSize()[0] + containerObj.getSize()[0])
      myPlaceObj.pos = $"0.5pw-{totalWidth}, 0.5ph-0.5h"
    }
    else {                            //Two rows
      topBarNestObj.flow = "vertical"
      myPlaceObj.pos = "0.5pw-0.5w, 0"
      containerObj.pos = "0.5pw-0.5w-0.5@debrPad, 0.5@debrPad"
    }
  }

  function loadBattleLog(filterIdx = null) {
    if (!this.needPlayersTbl)
      return
    let filters = ::HudBattleLog.getFilters()

    if (filterIdx == null) {
      filterIdx = ::loadLocalByAccount("wnd/battleLogFilterDebriefing", 0)

      let obj = this.scene.findObject("battle_log_filter")
      if (checkObj(obj)) {
        local data = ""
        foreach (f in filters)
          data += format("RadioButton { text:t='#%s'; style:t='color:@white'; RadioButtonImg{} }\n", f.title)
        this.guiScene.replaceContentFromText(obj, data, data.len(), this)
        obj.setValue(filterIdx)
      }
    }

    let obj = this.scene.findObject("battle_log_div")
    if (checkObj(obj)) {
      let logText = ::HudBattleLog.getText(filters[filterIdx].id, 0)
      obj.findObject("battle_log").setValue(logText)
    }
  }

  function loadChatHistory() {
    if (!this.needPlayersTbl)
      return
    let logText = getTblValue("chatLog", this.debriefingResult, "")
    if (logText == "")
      return
    let obj = this.scene.findObject("chat_history_div")
    if (checkObj(obj))
      obj.findObject("chat_log").setValue(logText)
  }

  function loadAwardsList() {
    let listObj = this.scene.findObject("awards_list_tab_div")
    let itemWidth = floor((listObj.getSize()[0] -
      this.guiScene.calcString("@scrollBarSize", null)
      ) / DEBR_AWARDS_LIST_COLUMNS - 1)
    foreach (list in [ this.challengesAwardsList, this.unlocksAwardsList, this.streakAwardsList ])
      foreach (award in list) {
        let obj = this.guiScene.createElementByObject(listObj, "%gui/unlocks/unlockBlock.blk", "tdiv", this)
        obj.width = itemWidth.tostring()
        ::fill_unlock_block(obj, award)
      }
  }

  function loadBattleTasksList() {
    if (!this.is_show_battle_tasks_list(false) || !this.mGameMode)
      return

    let filteredTasks = ::g_battle_tasks.getCurBattleTasksByGm(this.mGameMode?.name)
      .filter(@(t) !::g_battle_tasks.isTaskDone(t))

    let currentBattleTasksConfigs = {}
    let configsArray = filteredTasks.map(@(task) ::g_battle_tasks.generateUnlockConfigByTask(task))
    foreach (config in configsArray)
      currentBattleTasksConfigs[config.id] <- config

    if (!u.isEqual(currentBattleTasksConfigs, this.battleTasksConfigs)) {
      this.shouldBattleTasksListUpdate = true
      this.battleTasksConfigs = currentBattleTasksConfigs
      this.updateBattleTasksList()
    }
  }

  function updateBattleTasksList() {
    if (this.curTab != "battle_tasks_list" || !this.shouldBattleTasksListUpdate || !this.is_show_battle_tasks_list(false))
      return

    this.shouldBattleTasksListUpdate = false
    let msgObj = this.scene.findObject("battle_tasks_list_msg")
    if (checkObj(msgObj))
      msgObj.show(!this.is_show_battle_tasks_list())

    let listObj = this.scene.findObject("battle_tasks_list_scroll_block")
    if (!checkObj(listObj))
      return

    listObj.show(this.is_show_battle_tasks_list())
    if (!this.is_show_battle_tasks_list())
      return

    let curSelected = listObj.getValue()
    let battleTasksArray = []
    foreach (config in this.battleTasksConfigs) {
      battleTasksArray.append(::g_battle_tasks.generateItemView(config, { showUnlockImage = false }))
    }
    let data = handyman.renderCached("%gui/unlocks/battleTasksItem.tpl", { items = battleTasksArray })
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (battleTasksArray.len() > 0)
      listObj.setValue(clamp(curSelected, 0, listObj.childrenCount() - 1))
  }

  function updateBattleTasksStatusImg() {
    let tabObjStatus = this.scene.findObject("battle_tasks_list_icon")
    if (checkObj(tabObjStatus))
      tabObjStatus.show(::g_battle_tasks.canGetAnyReward())
  }

  function onSelectTask(obj) {
    this.updateBattleTasksRequirementsList() //need to check even if there is unlock

    let val = obj.getValue()
    let taskObj = obj.getChild(val)
    let taskId = taskObj?.task_id
    let task = ::g_battle_tasks.getTaskById(taskId)
    if (!task)
      return

    let isBattleTask = ::g_battle_tasks.isBattleTask(taskId)

    let isDone = ::g_battle_tasks.isTaskDone(task)
    let canGetReward = isBattleTask && ::g_battle_tasks.canGetReward(task)

    let showRerollButton = isBattleTask && !isDone && !canGetReward && !u.isEmpty(::g_battle_tasks.rerollCost)
    ::showBtn("btn_reroll", showRerollButton, taskObj)
    ::showBtn("btn_recieve_reward", canGetReward, taskObj)
    if (showRerollButton)
      placePriceTextToButton(taskObj, "btn_reroll", loc("mainmenu/battleTasks/reroll"), ::g_battle_tasks.rerollCost)
  }

  function updateBattleTasksRequirementsList() {
    local config = null
    if (this.curTab == "battle_tasks_list" && this.is_show_battle_tasks_list()) {
      let taskId = this.getCurrentBattleTaskId()
      config = this.battleTasksConfigs?[taskId]
    }

    this.showSceneBtn("btn_requirements_list", ::show_console_buttons && (config?.names ?? []).len() != 0)
  }

  function onTaskReroll(obj) {
    let config = this.battleTasksConfigs?[obj?.task_id]
    if (!config)
      return

    let task = config?.originTask
    if (!task)
      return

    if (::check_balance_msgBox(::g_battle_tasks.rerollCost))
      this.msgBox("reroll_perform_action",
             loc("msgbox/battleTasks/reroll",
                  { cost = ::g_battle_tasks.rerollCost.tostring(),
                    taskName = ::g_battle_tasks.getLocalizedTaskNameById(task)
                  }),
      [
        ["yes", @() ::g_battle_tasks.isSpecialBattleTask(task)
          ? ::g_battle_tasks.rerollSpecialTask(task)
          : ::g_battle_tasks.rerollTask(task) ],
        ["no", @() null ]
      ], "yes", { cancel_fn = @() null })
  }

  function onGetRewardForTask(obj) {
    ::g_battle_tasks.requestRewardForTask(obj?.task_id)
  }

  function getCurrentBattleTaskId() {
    let listObj = this.scene.findObject("battle_tasks_list_scroll_block")
    if (checkObj(listObj))
      return listObj.getChild(listObj.getValue())?.task_id

    return null
  }

  function onViewBattleTaskRequirements(obj) {
    local taskId = obj?.task_id
    if (!taskId)
      taskId = this.getCurrentBattleTaskId()

    let config = this.battleTasksConfigs?[taskId]
    if (!config)
      return

    let cfgNames = config?.names ?? []
    if (cfgNames.len() == 0)
      return

    let awards = cfgNames.map(@(id) ::build_log_unlock_data(
      ::build_conditions_config(
        getUnlockById(id)
    )))

    showUnlocksGroupWnd(awards, loc("unlocks/requirements"))
  }

  function updateBattleTasks() {
    this.loadBattleTasksList()
    this.updateBattleTasksStatusImg()
    this.updateShortBattleTask()
  }

  function onEventBattleTasksIncomeUpdate(_p) { this.updateBattleTasks() }
  function onEventBattleTasksTimeExpired(_p)  { this.updateBattleTasks() }
  function onEventBattleTasksFinishedUpdate(_p) { this.updateBattleTasks() }

  function getWwBattleResults() {
    if (!this.is_show_ww_casualties())
      return null

    let logs = ::getUserLogsList({
      show = [
        EULT_SESSION_RESULT
      ]
      currentRoomOnly = true
    })

    if (!logs.len())
      return null

    return ::WwBattleResults().updateFromUserlog(logs[0])
  }

  function loadWwCasualtiesHistory() {
    if (!::is_worldwar_enabled())
      return

    let wwBattleResults = this.getWwBattleResults()
    if (!wwBattleResults)
      return

    let taskCallback = Callback(function() {
      let view = wwBattleResults.getView()
      let markup = handyman.renderCached("%gui/worldWar/battleResults.tpl", view)
      let contentObj = this.scene.findObject("ww_casualties_div")
      if (checkObj(contentObj))
        this.guiScene.replaceContentFromText(contentObj, markup, markup.len(), this)
    }, this)

    let operationId = wwBattleResults.operationId
    if (operationId)
      ::g_world_war.updateOperationPreviewAndDo(operationId, taskCallback)
  }

  function showTabsList() {
    let tabsObj = this.scene.findObject("tabs_list")
    tabsObj.show(true)
    let view = { items = [] }
    local tabValue = 0
    let defaultTabName = this.is_show_ww_casualties() ? "ww_casualties" : ""
    foreach (idx, tabName in this.tabsList) {
      let checkName = "is_show_" + tabName
      if (!(checkName in this) || this[checkName]()) {
        let title = getTblValue(tabName, this.tabsTitles, "#debriefing/" + tabName)
        view.items.append({
          id = tabName
          text = title
          image = tabName == "battle_tasks_list" ? "#ui/gameuiskin#new_reward_icon.svg" : null
        })
        if (tabName == defaultTabName)
          tabValue = idx
      }
    }
    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(tabValue)
    this.onChangeTab(tabsObj)
    this.updateBattleTasksStatusImg()
  }

    //------------- <CURRENT BATTLE TASK ---------------------
  function updateShortBattleTask() {
    if (!this.is_show_battle_tasks_list(false))
      return

    let buttonObj = this.scene.findObject("current_battle_tasks")
    if (!checkObj(buttonObj))
      return

    let battleTasksArray = []
    foreach (config in this.battleTasksConfigs) {
      battleTasksArray.append(::g_battle_tasks.generateItemView(config, { isShortDescription = true }))
    }
    if (u.isEmpty(battleTasksArray))
      battleTasksArray.append(::g_battle_tasks.generateItemView({
        id = "current_battle_tasks"
        text = "#mainmenu/btnBattleTasks"
        shouldRefreshTimer = true
        }, { isShortDescription = true }))

    let data = handyman.renderCached("%gui/unlocks/battleTasksShortItem.tpl", { items = battleTasksArray })
    this.guiScene.replaceContentFromText(buttonObj, data, data.len(), this)
    ::g_battle_tasks.setUpdateTimer(null, buttonObj)
  }
  //------------- </CURRENT BATTLE TASK --------------------


  function is_show_my_stats() {
    return !this.isSpectator  && this.gm != GM_SKIRMISH
  }
  function is_show_players_stats() {
    return this.needPlayersTbl
  }
  function is_show_battle_log() {
    return this.needPlayersTbl && ::HudBattleLog.getLength() > 0
  }
  function is_show_chat_history() {
    return this.needPlayersTbl && getTblValue("chatLog", this.debriefingResult, "") != ""
  }
  function is_show_left_block() {
    return this.is_show_awards_list() || this.is_show_inventory_gift()
  }
  function is_show_awards_list() {
    return !u.isEmpty(this.awardsList)
  }
  function is_show_inventory_gift() {
    return this.giftItems != null
  }
  function is_show_ww_casualties() {
    return this.needPlayersTbl && ::is_worldwar_enabled() && ::g_mis_custom_state.getCurMissionRules().isWorldWar
  }
  function is_show_research_list() {
    foreach (unitId, _unitData in this.debriefingResult.exp.aircrafts)
      if (this.isShowUnitInModsResearch(unitId))
        return true
    foreach (ut in unitTypes.types)
      if (this.getResearchUnitInfo(ut.name))
        return true
    if (this.getExpInvestUnitTotal() > 0)
      return true
    return false
  }

  function is_show_battle_tasks_list(isNeedBattleTasksList = true) {
    return (hasFeature("DebriefingBattleTasks") && ::g_battle_tasks.isAvailableForUser()) &&
      (!isNeedBattleTasksList || this.battleTasksConfigs.len() > 0)
  }

  function is_show_right_block() {
    return this.isForceShowMyStatsRightBlock || this.is_show_research_list() || this.is_show_battle_tasks_list()
  }

  function onChangeTab(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    this.showTab(obj.getChild(value).id)
    this.updateBattleTasksList()
    this.updateBattleTasksRequirementsList()
  }

  function updateScrollableObjects(tabObj, tabName, isEnable) {
    foreach (objId, val in getTblValue(tabName, this.tabsScrollableObjs, {})) {
      let obj = tabObj.findObject(objId)
      if (checkObj(obj))
        obj["scrollbarShortcuts"] = isEnable ? val : "no"
    }
  }

  function updateListsButtons() {
    let isAnimDone = this.state == debrState.done
    let isReplayReady = hasFeature("ClientReplay") && is_replay_present() && is_replay_turned_on()
    let player = this.getSelectedPlayer()
    let buttonsList = {
      btn_view_replay = isAnimDone && isReplayReady && !this.isMp
      btn_save_replay = isAnimDone && isReplayReady && !is_replay_saved()
      btn_user_options = isAnimDone && (this.curTab == "players_stats") && player && !player.isBot && ::show_console_buttons
      btn_view_highlights = isAnimDone && ::is_highlights_inited()
    }

    foreach (btn, show in buttonsList)
      this.showSceneBtn(btn, show)
  }

  function onChatLinkClick(_obj, _itype, link) {
    if (link.len() > 3 && link.slice(0, 3) == "PL_") {
      let name = link.slice(3)
      ::gui_modal_userCard({ name = name })
    }
  }

  function onChatLinkRClick(_obj, _itype, link) {
    if (link.len() > 3 && link.slice(0, 3) == "PL_") {
      let name = link.slice(3)
      let player = this.getPlayerInfo(name)
      if (player)
        ::session_player_rmenu(this, player, this.getChatLog())
    }
  }

  function onChangeBattlelogFilter(obj) {
    if (!checkObj(obj))
      return
    let filterIdx = obj.getValue()
    ::saveLocalByAccount("wnd/battleLogFilterDebriefing", filterIdx)
    this.loadBattleLog(filterIdx)
  }

  function onViewReplay(_obj) {
    if (this.isInProgress)
      return

    ::set_presence_to_player("replay")
    reqUnlockByClient("view_replay")
    ::autosave_replay()
    on_view_replay("")
    this.isInProgress = true
  }

  function onSaveReplay(_obj) {
    if (this.isInProgress)
      return
    if (is_replay_saved() || !is_replay_present())
      return

    let afterFunc = function(newName) {
      let result = on_save_replay(newName);
      if (!result) {
        this.msgBox("save_replay_error", loc("replays/save_error"),
          [
            ["ok", function() { } ]
          ], "ok")
      }
      this.updateListsButtons()
    }
    ::gui_modal_name_and_save_replay(this, afterFunc);
  }

  function onViewHighlights() {
    if (!::is_highlights_inited())
      return

    ::show_highlights()
  }

  function setGoNext() {
    ::go_debriefing_next_func = ::gui_start_mainmenu //default func
    if (this.needShowWorldWarOperationBtn()) {
      if (!::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader())
        ::go_debriefing_next_func = function() {
          ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu) //do not need to back to debriefing
          ::g_world_war.openOperationsOrQueues(true)
        }
      return
    }

    let isMpMode = (this.gameType & GT_COOPERATIVE) || (this.gameType & GT_VERSUS)

    if (::SessionLobby.status == lobbyStates.IN_DEBRIEFING && ::SessionLobby.haveLobby())
      return
    if (isMpMode && !::is_online_available())
      return

    if (isMpMode && this.needGoLobbyAfterStatistics() && this.gm != GM_DYNAMIC) {
      ::go_debriefing_next_func = ::gui_start_mp_lobby
      return
    }

    if (this.gm == GM_CAMPAIGN) {
      if (this.debriefingResult.isSucceed) {
        log("VIDEO: campaign = " + ::current_campaign_id + "mission = " + ::current_campaign_mission)
        if ((::current_campaign_mission == "jpn_guadalcanal_m4")
            || (::current_campaign_mission == "us_guadalcanal_m4"))
          needCheckForVictory(true)
        ::select_next_avail_campaign_mission(::current_campaign_id, ::current_campaign_mission)
      }
      ::go_debriefing_next_func = ::gui_start_menuCampaign
      return
    }

    if (this.gm == GM_TEST_FLIGHT) {
      ::go_debriefing_next_func = @() ::gui_start_mainmenu_reload(true)
      return
    }

    if (this.gm == GM_DYNAMIC) {
      if (isMpMode) {
        if (::SessionLobby.isInRoom() && getDynamicResult() == MISSION_STATUS_RUNNING) {
          ::go_debriefing_next_func = ::gui_start_dynamic_summary
          if (is_mplayer_host())
            this.recalcDynamicLayout()
        }
        else
          ::go_debriefing_next_func = ::gui_start_dynamic_summary_f
        return
      }

      if (getDynamicResult() == MISSION_STATUS_RUNNING) {
        let settings = DataBlock();
        ::mission_settings.dynlist <- dynamicGetList(settings, false)

        let add = []
        for (local i = 0; i < ::mission_settings.dynlist.len(); i++) {
          let misblk = ::mission_settings.dynlist[i].mission_settings.mission
          misblk.setStr("mis_file", ::mission_settings.layout)
          misblk.setStr("chapter", get_cur_game_mode_name())
          misblk.setStr("type", get_cur_game_mode_name())
          add.append(misblk)
        }
        ::add_mission_list_full(GM_DYNAMIC, add, ::mission_settings.dynlist)
        ::go_debriefing_next_func = ::gui_start_dynamic_summary
      }
      else
        ::go_debriefing_next_func = ::gui_start_dynamic_summary_f

      return
    }

    if (this.gm == GM_SINGLE_MISSION) {
      let mission = ::mission_settings?.mission ?? ::get_current_mission_info_cached()
      ::go_debriefing_next_func = ::is_user_mission(mission)
        ? ::gui_start_menuUserMissions
        : ::gui_start_menuSingleMissions

      return
    }

    let lastEvent = ::events.getEvent(::SessionLobby.lastEventName)
    if (lastEvent?.chapter == "competitive")
      ::go_debriefing_next_func = @() openLastTournamentWnd(lastEvent)
    else
      ::go_debriefing_next_func = ::gui_start_mainmenu
  }

  function needGoLobbyAfterStatistics() {
    return !((this.gameType & GT_COOPERATIVE) || (this.gameType & GT_VERSUS))
  }

  function recalcDynamicLayout() {
    ::mission_settings.layout <- dynamicGetLayout()
    // FIXME : workaroud for host migration assert (instead of back to lobby - disconnect)
    // http://www.gaijin.lan/mantis/view.php?id=36502
    if (::mission_settings.layout) {
      let settings = DataBlock();
      ::mission_settings.dynlist <- dynamicGetList(settings, false)

      let add = []
      for (local i = 0; i < ::mission_settings.dynlist.len(); i++) {
        let misblk = ::mission_settings.dynlist[i].mission_settings.mission
        misblk.setStr("mis_file", ::mission_settings.layout)
        misblk.setStr("chapter", get_cur_game_mode_name())
        misblk.setStr("type", get_cur_game_mode_name())
        misblk.setBool("gt_cooperative", true)
        add.append(misblk)
      }
      ::add_mission_list_full(GM_DYNAMIC, add, ::mission_settings.dynlist)
      ::mission_settings.currentMissionIdx <- 0
      let misBlk = ::mission_settings.dynlist[::mission_settings.currentMissionIdx].mission_settings.mission
      misBlk.setInt("_gameMode", GM_DYNAMIC)
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]
      select_mission_full(misBlk, ::mission_settings.missionFull);
    }
    else {
      log("no mission_settings.layout, destroy session")
      ::destroy_session_scripted("on unable to recalc dynamic layout")
    }
  }

  function afterSave() {
    this.applyReturn()
  }

  function applyReturn() {
    if (::go_debriefing_next_func != ::gui_start_dynamic_summary)
      ::destroy_session_scripted("on leave debriefing")

    if (this.is_show_my_stats())
      setNeedShowRate(this.debriefingResult, this.getMyPlace())

    this.debriefingResult = null
    this.playCountSound(false)
    this.isInProgress = false

    ::HudBattleLog.reset()

    if (!::SessionLobby.goForwardAfterDebriefing())
      this.goForward(::go_debriefing_next_func)
  }

  function goBack() {
    if (this.state != debrState.done && !this.skipAnim) {
      this.onSkip()
      return
    }

    if (this.isInProgress)
      return

    if (this.needShowWorldWarOperationBtn())
      this.switchWwOperationToCurrent()

    this.isInProgress = true

    ::autosave_replay()

    if (!::go_debriefing_next_func)
      ::go_debriefing_next_func = ::gui_start_mainmenu

    ::g_crews_list.invalidate()

    if (this.isReplay)
      this.applyReturn()
    else {  //do_finalize_debriefing
      this.save()
      ::checkRemnantPremiumAccount()
    }
    this.playCountSound(false)
  }

  function onNext() {
    if (this.state != debrState.done && !this.skipAnim) {
      this.onSkip()
      return
    }

    let needGoToBattle = this.isToBattleActionEnabled()
    this.switchWwOperationToCurrent()
    this.goBack()

    if (needGoToBattle)
      goToBattleAction()
  }

  function isToBattleActionEnabled() {
    return (this.skipAnim || this.state == debrState.done)
      && (this.gm == GM_DOMINATION) && !!(this.gameType & GT_VERSUS)
      && !::checkIsInQueue()
      && !(::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady())
      && !::SessionLobby.hasSessionInLobby()
      && !this.hasAnyFinishedResearch()
      && !this.isSpectator
      && ::go_debriefing_next_func == ::gui_start_mainmenu
      && !::checkNonApprovedResearches(true, false)
      && !(::my_stats.isNewbieInited() && !::my_stats.isMeNewbie() && hasEveryDayLoginAward())
  }

  function needShowWorldWarOperationBtn() {
    return ::is_worldwar_enabled() && ::g_world_war.isLastFlightWasWwBattle
  }

  function switchWwOperationToCurrent() {
    if (!this.needShowWorldWarOperationBtn())
      return

    let wwBattleRes = this.getWwBattleResults()
    if (wwBattleRes)
      ::g_world_war.saveLastPlayed(wwBattleRes.getOperationId(), wwBattleRes.getPlayerCountry())
    else {
      let missionRules = ::g_mis_custom_state.getCurMissionRules()
      let operationId = missionRules?.missionParams?.customRules?.operationId
      if (!operationId)
        return

      ::g_world_war.saveLastPlayed(operationId.tointeger(), profileCountrySq.value)
    }

    ::go_debriefing_next_func = function() {
      ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)
      ::g_world_war.openMainWnd()
    }
  }

  function updateStartButton() {
    if (this.state != debrState.done)
      return

    let showWorldWarOperationBtn = this.needShowWorldWarOperationBtn()
    let isToBattleBtnVisible = this.isToBattleActionEnabled() && !showWorldWarOperationBtn

    ::showBtnTable(this.scene, {
      btn_next = true
      btn_back = isToBattleBtnVisible
    })

    let btnNextLocId = showWorldWarOperationBtn ? "worldWar/stayInOperation"
      : !isToBattleBtnVisible ? "mainmenu/btnOk"
      : ::g_squad_manager.isSquadMember() ? "mainmenu/btnReady"
      : getToBattleLocId()

    setDoubleTextToButton(this.scene, "btn_next", loc(btnNextLocId))

    if (isToBattleBtnVisible)
      this.scene.findObject("btn_back").setValue(loc("mainmenu/toHangar"))
  }

  function onEventSquadSetReady(_p) {
    this.updateStartButton()
  }

  function onEventSquadStatusChanged(_p) {
    this.updateStartButton()
  }

  function onEventQueueChangeState(_params) {
    this.updateStartButton()
  }

  onEventToBattleLocChanged = @(_params) this.updateStartButton()

  function onEventMatchingDisconnect(_p) {
    ::go_debriefing_next_func = startLogout
  }

  function isDelayedLogoutOnDisconnect() {
    ::go_debriefing_next_func = startLogout
    return true
  }

  function throwBattleEndEvent() {
    let eventId = getTblValue("eventId", this.debriefingResult)
    if (eventId)
      broadcastEvent("EventBattleEnded", { eventId = eventId })
    broadcastEvent("BattleEnded", { battleResult = this.debriefingResult?.exp.result })
  }

  function checkPopupWindows() {
    let country = this.getDebriefingCountry()

    //check unlocks windows
    let wnd_unlock_gained = ::getUserLogsList({
      show = [EULT_NEW_UNLOCK]
      unlocks = [UNLOCKABLE_AIRCRAFT, UNLOCKABLE_AWARD]
      filters = { popupInDebriefing = [true] }
      currentRoomOnly = true
      disableVisible = true
    })
    foreach (logObj in wnd_unlock_gained)
      ::showUnlockWnd(::build_log_unlock_data(logObj))

    //check new rank and unlock country by exp gained
    let new_rank = ::get_player_rank_by_country(country)
    local old_rank = playerRankByCountries?[country] ?? new_rank

    if (country != "" && country != "country_0" &&
        !::isCountryAvailable(country) && ::get_player_exp_by_country(country) > 0) {
      ::unlockCountry(country)
      old_rank = -1 //new country unlocked!
    }

    if (new_rank > old_rank) {
      let gained_ranks = [];

      for (local i = old_rank + 1; i <= new_rank; i++)
        gained_ranks.append(i);
      checkRankUpWindow(country, old_rank, new_rank);
    }

    //check country unlocks by N battle
    let country_unlock_gained = ::getUserLogsList({
      show = [EULT_NEW_UNLOCK]
      unlocks = [UNLOCKABLE_COUNTRY]
      currentRoomOnly = true
      disableVisible = true
    })
    foreach (logObj in country_unlock_gained) {
      ::showUnlockWnd(::build_log_unlock_data(logObj))
      if (("unlockId" in logObj) && logObj.unlockId != country && isInArray(logObj.unlockId, shopCountriesList))
        ::unlockCountry(logObj.unlockId)
    }

    //check userlog entry for tournament special rewards
    let tornament_special_rewards = ::getUserLogsList({
      show = [EULT_CHARD_AWARD]
      currentRoomOnly = true
      disableVisible = true
      filters = { rewardType = ["TournamentReward"] }
    })

    let rewardsArray = []
    foreach (logObj in tornament_special_rewards)
      rewardsArray.extend(getTournamentRewardData(logObj))

    foreach (rewardConfig in rewardsArray)
      ::showUnlockWnd(rewardConfig)

    this.openGiftTrophy()
  }

  function updateInfoText() {
    if (this.debriefingResult == null)
      return
    local infoText = ""
    local infoColor = "active"

    let wpdata = ::get_session_warpoints()

    if (this.debriefingResult.exp?.noActivityPlayer ?? false) {
      infoText = loc("MISSION_NO_ACTIVITY")
      infoColor = "bad"
    }
    else if (this.debriefingResult.exp.result == STATS_RESULT_ABORTED_BY_KICK) {
      infoText = loc("MISSION_ABORTED_BY_KICK")
      infoColor = "bad"
    }
    else if (this.debriefingResult.exp.result == STATS_RESULT_ABORTED_BY_ANTICHEAT) {
      infoText = this.getKickReasonLocText()
      infoColor = "bad"
    }
    else if ((this.gm == GM_DYNAMIC || this.gm == GM_BUILDER) && wpdata.isRewardReduced)
      infoText = loc("debriefing/award_reduced")
    else {
      local hasAnyReward = false
      foreach (source in [ "Total", "Mission" ])
        foreach (currency in [ "exp", "wp", "gold" ])
          if (getTblValue(currency + source, this.debriefingResult.exp, 0) > 0)
            hasAnyReward = true

      if (!hasAnyReward) {
        if (this.gm == GM_SINGLE_MISSION || this.gm == GM_CAMPAIGN || this.gm == GM_TRAINING) {
          if (this.debriefingResult.isSucceed)
            infoText = loc("debriefing/award_already_received")
        }
        else if (this.isMp && !isDebriefingResultFull() && this.gm == GM_DOMINATION) {
          infoText = loc("debriefing/most_award_after_battle")
          infoColor = "userlog"
        }
        else if (this.isMp && this.debriefingResult.exp.result == STATS_RESULT_IN_PROGRESS && !(this.gameType & GT_RACE))
          infoText = loc("debriefing/exp_and_reward_will_be_later")
      }
    }

    let isShow = infoText != ""
    let infoObj = this.scene.findObject("stat_info_text")
    infoObj.show(isShow)
    if (isShow) {
      infoObj.setValue(infoText)
      infoObj["overlayTextColor"] = infoColor
      this.guiScene.applyPendingChanges(false)
      infoObj.scrollToView()
    }
  }

  function getBoostersText() {
    let textsList = []
    let activeBoosters = getTblValue("activeBoosters", this.debriefingResult, [])
    if (activeBoosters.len() > 0)
      foreach (effectType in boosterEffectType) {
        let boostersArray = []
        foreach (_idx, block in activeBoosters) {
          let item = ::ItemsManager.findItemById(block.itemId)
          if (item && effectType.checkBooster(item))
            boostersArray.append(item)
        }

        if (boostersArray.len())
          textsList.append(getActiveBoostersDescription(boostersArray, effectType))
      }
    return "\n\n".join(textsList, true)
  }

  function getBoostersTotalEffects() {
    let activeBoosters = getTblValue("activeBoosters", this.debriefingResult, [])
    let boostersArray = []
    foreach (block in activeBoosters) {
      let item = ::ItemsManager.findItemById(block.itemId)
      if (item)
        boostersArray.append(item)
    }
    return getBoostersEffects(boostersArray)
  }

  function getInvetoryGiftActionData() {
    if (!this.giftItems)
      return null

    let itemDefId = this.giftItems?[0]?.item
    let wSet = workshop.getSetByItemId(itemDefId)
    if (wSet)
      return {
        btnText = loc("items/workshop")
        action = @() wSet.needShowPreview() ? workshopPreview.open(wSet)
          : ::gui_start_items_list(itemsTab.WORKSHOP, {
              curSheet = { id = wSet.getShopTabId() },
              curItem = ::ItemsManager.getInventoryItemById(itemDefId)
              initSubsetId = wSet.getSubsetIdByItemId(itemDefId)
            })
      }

    return null
  }

  function updateInventoryButton() {
    let actionData = this.getInvetoryGiftActionData()
    let actionBtn = this.showSceneBtn("btn_inventory_gift_action", actionData != null)
    if (actionData && actionBtn)
      setColoredDoubleTextToButton(this.scene, "btn_inventory_gift_action", actionData.btnText)
  }

  function onInventoryGiftAction() {
    let actionData = this.getInvetoryGiftActionData()
    if (actionData)
      actionData.action()
  }

  getUserlogsMask = @() this.state == debrState.done && this.isSceneActiveNoModals()
    ? USERLOG_POPUP.OPEN_TROPHY
    : USERLOG_POPUP.NONE

  function onEventModalWndDestroy(_p) {
    if (this.state == debrState.done && this.isSceneActiveNoModals())
      ::checkNewNotificationUserlogs()
  }

  function getChatLog() {
    return this.debriefingResult?.logForBanhammer
  }

  function getDebriefingCountry() {
    if (this.debriefingResult)
      return this.debriefingResult.country
    return ""
  }

  function getMissionBonusText() {
    if (this.gm != GM_DOMINATION)
      return ""

    let isWin = this.debriefingResult.isSucceed

    let bonusWp = (isWin ? ::get_warpoints_blk()?.winK : ::get_warpoints_blk()?.defeatK) ?? 0.0
    let wp = (bonusWp > 0) ? ceil(bonusWp * 100) : 0
    let textWp = (wp > 0) ? ::getWpPriceText($"+{wp}%", true) : ""

    let mis = ::get_current_mission_info_cached()
    let useTimeAwardingExp = mis?.useTimeAwardingEconomics ?? false
    local textRp = ""
    if (!useTimeAwardingExp) {
      let rBlk = ::get_ranks_blk()
      let missionRp = (isWin ? rBlk?.expForVictoryVersusPerSec : rBlk?.expForPlayingVersusPerSec) ?? 0.0
      let baseRp = rBlk?.expBaseVersusPerSec ?? 0
      if (missionRp > 0 && baseRp > 0) {
        let rp = ceil((missionRp.tofloat() / baseRp - 1.0) * 100)
        textRp = ::getRpPriceText($"+{rp}%", true)
      }
    }
    return loc("ui/comma").join([textRp, textWp], true)
  }

  function getCurAwardText() {
    return Cost(::get_premium_reward_wp(), 0, ::get_premium_reward_xp()).tostring()
  }

  getLocalTeam = @() ::get_local_team_for_mpstats(this.debriefingResult.localTeam)
  getMplayersList = @(team = GET_MPLAYERS_LIST) team == GET_MPLAYERS_LIST
    ? this.debriefingResult.mplayers_list
    : this.debriefingResult.mplayers_list.filter(@(player) player.team == team)
  getOverrideCountryIconByTeam = @(team) this.debriefingResult.overrideCountryIconByTeam[team]

  function initStatsMissionParams() {
    this.gameMode = this.debriefingResult.gm
    this.isOnline = ::g_login.isLoggedIn()

    this.isTeamsRandom = !this.isTeamplay || this.gameMode == GM_DOMINATION
    if (this.debriefingResult.isInRoom || this.isReplay)
      this.isTeamsWithCountryFlags = this.isTeamplay &&
        (this.debriefingResult.missionDifficultyInt > 0 || !this.debriefingResult.isSymmetric)

    this.missionObjectives = this.debriefingResult.missionObjectives
  }

  isInited = true
  state = 0
  skipAnim = false
  isMp = false
  isReplay = false
  //haveCountryExp = true

  tabsList = [ "my_stats", "players_stats", "ww_casualties", "awards_list", "battle_tasks_list", "battle_log", "chat_history" ]
  tabsTitles = { awards_list = "#profile/awards", battle_tasks_list = "#userlog/page/battletasks" }
  tabsScrollableObjs = {
    my_stats      = { my_stats_scroll_block = "yes", researches_scroll_block = "left" }
    players_stats = { players_stats_scroll_block = "yes" }
    ww_casualties = { ww_battle_results_scroll_block = "yes" }
    awards_list   = { awards_list_scroll_block = "yes" }
    battle_tasks_list = { battle_tasks_list_scroll_block = "yes" }
    battle_log    = { battle_log_div = "yes" }
    chat_history  = { chat_history_scroll_block = "yes" }
  }
  curTab = ""
  nextWndDelay = 1.0

  needPlayersTbl = false
  playersTbl = null
  curPlayersTbl = null
  playersRowTime = 0.05
  playersTblDone = false
  myPlaceTime = 0.7
  minPlayersTime = 0.7

  playerStatsObj = null
  isCountSoundPlay = false
  needPlayCount = false
  statsTimer = 0.0
  statsTime = 0.3
  statsNextTime = 0.15
  totalStatsTime = 0.6
  statsBonusTime = 0.3
  statsBonusDelay = 0.2
  curStatsIdx = -1

  totalObj = null
  totalTimer = 0.0
  totalRow = null
  totalCurValues = null
  totalTarValues = null

  awardsList = null
  curAwardIdx = 0

  streakAwardsList = null
  challengesAwardsList = null
  unlocksAwardsList = null

  currentAwardsList = null
  currentAwardsListConfig = null
  currentAwardsListIdx = 0

  awardsData = null

  awardOffset = 0
  awardShift = 0
  awardsAppearTime = 2.0 //can be lower than this, not higher
  awardDelay = 0.25
  awardFlyTime = 0.5

  usedUnitTypes = null

  isInProgress = false
}
