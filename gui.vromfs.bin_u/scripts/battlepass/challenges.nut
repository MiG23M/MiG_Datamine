//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { getTimestampFromStringUtc, buildDateStr } = require("%scripts/time.nut")
let {  addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { season, seasonLevel, getLevelByExp } = require("%scripts/battlePass/seasonState.nut")
let { activeUnlocks, getUnlockRewardMarkUp } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { refreshUserstatUnlocks } = require("%scripts/userstat/userstat.nut")
let { getUnlockConditions, getHeaderCondition,
  isTimeRangeCondition } = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")

let battlePassChallenges = Watched([])
let curSeasonChallenges = Computed(@() battlePassChallenges.value
  .filter(@(unlock) unlock.battlePassSeason == season.value))

curSeasonChallenges.subscribe(function(value) {
  foreach (challenge in value) {
    let userstatUnlock = activeUnlocks.value?[challenge.id]
    if (!(userstatUnlock?.isCompleted ?? false) && ::is_unlocked_scripted(-1, challenge.id)) {
      refreshUserstatUnlocks()
      return
    }
  }
})

let function getLevelFromConditions(conditions) {
  let battlepassLevel = conditions.findvalue(@(cond) cond?.type == "battlepassLevel")
  if (battlepassLevel)
    return battlepassLevel.level

  let battlepassProgress = conditions.findvalue(@(cond) cond?.type == "battlepassProgress")
  if (battlepassProgress)
    return getLevelByExp(battlepassProgress.progress)

  return null
}

let curSeasonChallengesByStage = Computed(function() {
  let res = {}
  foreach (challenge in curSeasonChallenges.value) {
    let mode = challenge?.mode
    if (mode == null)
      continue

    let level = getLevelFromConditions(getUnlockConditions(mode))
    if (level == null)
      continue

    res[level] <- challenge
  }
  return res
})

let mainChallengeOfSeasonId = Computed(@() $"battlepass_season_{season.value}_challenge_all")
let mainChallengeOfSeason = Computed(@() curSeasonChallenges.value
  .findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.value))

let function invalidateUnlocksCache() {
  battlePassChallenges([])
  broadcastEvent("BattlePassCacheInvalidate")
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateUnlocksCache()
})

let function updateChallenges() {
  if (::g_login.isLoggedIn())
    battlePassChallenges(getAllUnlocksWithBlkOrder()
      .filter(@(unlock) (unlock?.battlePassSeason != null) && isUnlockVisible(unlock)))
}

let function getChallengeStatus(userstatUnlock, unlockConfig) {
  if (userstatUnlock?.hasReward ?? false)
    return "complete"
  if (userstatUnlock?.isCompleted ?? false)
    return "done"
  if (unlockConfig.isExpired)
    return "expired"
  return null
}

let function getConditionInTitleConfig(unlockBlk) {
  let res = {
    addTitle = ""
    titleIcon = "#ui/gameuiskin#challenge_medal.svg"
  }
  let mode = unlockBlk?.mode
  if (mode == null)
    return res

  let condition = getUnlockConditions(mode)
  let level = getLevelFromConditions(condition)
  if (level != null) {
    if (level > seasonLevel.value)
      return {
        addTitle = loc("ui/parentheses/space", {
          text = loc("condition/unlockByLevel", { level = level })
        })
        titleIcon = "#ui/gameuiskin#calendar_event.svg"
      }
  }

  let timeCond = condition.findvalue(@(cond) isTimeRangeCondition(cond.type))
  if (timeCond != null) {
    let beginTime = getTimestampFromStringUtc(timeCond.beginDate)
    if (beginTime > ::get_charserver_time_sec())
      return {
        addTitle = loc("ui/parentheses/space", {
          text = loc("condition/unlockByTime", { date = buildDateStr(beginTime) })
        })
        titleIcon = "#ui/gameuiskin#calendar_date.svg"
      }
  }

  return res
}

let function getChallengeView(config, paramsCfg = {}) {
  let id = config.id
  let userstatUnlock = activeUnlocks.value?[id]
  let unlockConfig = ::build_conditions_config(config)
  ::build_unlock_desc(unlockConfig)

  let title = getUnlockNameText(unlockConfig.unlockType, id)
  let { addTitle, titleIcon } = getConditionInTitleConfig(config)
  let headerCond = getHeaderCondition(unlockConfig.conditions)

  let progressData = unlockConfig?.getProgressBarData()
  let progressBarValue = unlockConfig?.curVal != null && unlockConfig.curVal >= 0
    ? (unlockConfig.curVal.tofloat() / (unlockConfig?.maxVal ?? 1) * 1000)
    : 0
  let challengeStatus = getChallengeStatus(userstatUnlock, unlockConfig)
  let isInteractive = paramsCfg?.isInteractive ?? true

  return {
    id = id
    title = $"{title}{addTitle}"
    taskStatus = challengeStatus
    taskDifficultyImage = titleIcon
    taskHeaderCondition = headerCond ? loc("ui/parentheses/space", { text = headerCond }) : null
    description = ::g_battle_tasks.getTaskDescription(unlockConfig, paramsCfg)
    reward = getUnlockRewardMarkUp(userstatUnlock)
    canGetReward = isInteractive && (userstatUnlock?.hasReward ?? false)
    needShowProgressValue = challengeStatus == null && config?.curVal != null
      && config.curVal >= 0 && config?.maxVal != null && config.maxVal >= 0
    progressValue = config?.curVal
    progressMaxValue = config?.maxVal
    needShowProgressBar = progressData?.show
    progressBarValue = progressBarValue.tointeger()
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    isFavorite = isInteractive ? (isUnlockFav(id) ? "yes" : "no") : null
    hoverAction = paramsCfg?.hoverAction
    rewardOnTop = true
  }
}

let hasChallengesReward = Computed(@() battlePassChallenges.value
  .findindex(@(unlock) activeUnlocks.value?[unlock.id].hasReward ?? false) != null)

return {
  updateChallenges
  curSeasonChallenges
  getChallengeView
  mainChallengeOfSeasonId
  mainChallengeOfSeason
  curSeasonChallengesByStage
  hasChallengesReward
}
