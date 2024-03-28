from "%scripts/dagui_natives.nut" import get_option_xray_kill
from "%scripts/dagui_library.nut" import *
from "hitCamera" import *

let { get_mission_time } = require("mission")
let { g_hud_enemy_debuffs } = require("%scripts/hud/hudEnemyDebuffsType.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { eventbus_subscribe } = require("eventbus")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { get_game_params_blk } = require("blkGetters")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let { get_mission_difficulty_int } = require("guiMission")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")
let { isInFlight } = require("gameplayBinding")
let { format } =  require("string")
let stdMath = require("%sqstd/math.nut")

const TIME_TITLE_SHOW_SEC = 3
const TIME_TO_SUM_CREW_LOST_SEC = 1 //To sum up the number of crew losses from multiple bullets in a single salvo
const TIME_TO_SUM_RELATIVE_CREW_LOST = 0.15

let animTimerPid = dagui_propid_add_name_id("_transp-timer")
let animSizeTimerPid = dagui_propid_add_name_id("_size-timer")

let styles = {
  [DM_HIT_RESULT_NONE]      = "none",
  [DM_HIT_RESULT_RICOSHET]  = "ricochet",
  [DM_HIT_RESULT_BOUNCE]    = "bounce",
  [DM_HIT_RESULT_HIT]       = "hit",
  [DM_HIT_RESULT_BURN]      = "burn",
  [DM_HIT_RESULT_CRITICAL]  = "critical",
  [DM_HIT_RESULT_KILL]      = "kill",
  [DM_HIT_RESULT_METAPART]  = "hull",
  [DM_HIT_RESULT_AMMO]      = "ammo",
  [DM_HIT_RESULT_FUEL]      = "fuel",
  [DM_HIT_RESULT_CREW]      = "crew",
  [DM_HIT_RESULT_TORPEDO]   = "torpedo",
  [DM_HIT_RESULT_BREAKING]  = "breaking",
  [DM_HIT_RESULT_INVULNERABLE] = "invulnerable",
}

let debuffTemplates = {
  [ES_UNIT_TYPE_TANK] = "%gui/hud/hudEnemyDebuffsTank.blk",
  [ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDebuffsShip.blk",
  [ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDebuffsShip.blk",
}

let damageStatusTemplates = {
  [ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDamageStatusShip.blk",
  [ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDamageStatusShip.blk",
}

let importantEventKeys = ["partEvent", "ammoEvent"]

let debuffsListsByUnitType = {}
let trackedPartNamesByUnitType = {}

local scene     = null
local titleObj  = null
local infoObj   = null
local damageStatusObj = null
local isEnabled = true
local isVisible = false
local stopFadeTimeS = -1
local hitResult = DM_HIT_RESULT_NONE
local curUnitId = -1
local curUnitVersion = -1
local curUnitType = ES_UNIT_TYPE_INVALID
local camInfo   = {}
local unitsInfo = {}
local minAliveCrewCount = 2
local canShowCritAnimation = false

function getMinAliveCrewCount() {
  let diffCode = get_mission_difficulty_int()
  let settingsName = g_difficulty.getDifficultyByDiffCode(diffCode).settingsName
  let path = $"difficulty_settings/baseDifficulty/{settingsName}/changeCrewTime"
  let changeCrewTime = getBlkValueByPath(get_game_params_blk(), path)
  return changeCrewTime != null ? 1 : 2
}

let getDamageStatusByHealth = @(health)
  health == 100 ? "none"
    : health >= 70  ? "minor"
    : health >= 30  ? "moderate"
    : health > 0    ? "critical"
    : health == 0   ? "fatal"
    : "none"

function setDamageStatus(statusObjId, health, text = null) {
  if (!damageStatusObj?.isValid())
    return

  let obj = damageStatusObj.findObject(statusObjId)
  if (!obj?.isValid())
    return

  obj.damage = getDamageStatusByHealth(health)

  if (text == null)
    return

  let labelObj = obj.findObject("label")
  if (!labelObj?.isValid())
    return

  labelObj.setValue(text)
}

function updateDebuffItem(item, unitInfo, partName = null, dmgParams = null) {
  let data = item.getInfo(camInfo, unitInfo, partName, dmgParams)
  let isShow = data != null

  if (!(infoObj?.isValid() ?? false))
    return

  let obj = infoObj.findObject(item.id)
  if (!(obj?.isValid() ?? false))
    return
  obj.show(isShow)
  if (!isShow)
    return

  obj.state = data.state
  let labelObj = obj.findObject("label")
  if (labelObj?.isValid() ?? false)
    labelObj.setValue(data.label)
}

function updateFadeAnimation() {
  let needFade = stopFadeTimeS > 0
  scene["transp-time"] = needFade ? (stopFadeTimeS * 1000).tointeger() : 1
  scene["transp-base"] = needFade ? 255 : 0
  scene["transp-end"]  = needFade ? 0 : 255
  scene.setFloatProp(animTimerPid, 0.0)
}

let getHitCameraAABB = @() getDaguiObjAabb(scene)
let isKillingHitResult = @(result) result >= DM_HIT_RESULT_KILL && result != DM_HIT_RESULT_INVULNERABLE

function reset() {
  isVisible = false
  stopFadeTimeS = -1
  hitResult = DM_HIT_RESULT_NONE
  curUnitId = -1
  curUnitVersion = -1
  curUnitType = ES_UNIT_TYPE_INVALID
  canShowCritAnimation = false

  camInfo.clear()
  unitsInfo.clear()
}

function getTargetInfo(unitId, unitVersion, unitType, isUnitKilled) {
  if (!(unitId in unitsInfo) || unitsInfo[unitId].unitVersion != unitVersion)
    unitsInfo[unitId] <- {
      unitId
      unitVersion
      unitType
      parts = {}
      trackedPartNames = trackedPartNamesByUnitType?[unitType] ?? []
      isKilled = isUnitKilled
      isKillProcessed = false
      time = 0
      crewCount = -1
      crewTotalCount = 0
      crewLostCount = 0
      crewRelative = -1
      crewLostRelative = 0
      importantEvents = {}
    }

  let info = unitsInfo[unitId]
  info.time = get_mission_time()
  info.isKilled = info.isKilled || isUnitKilled

  return info
}

function cleanupUnitsInfo() {
  let old = get_mission_time() - 5.0
  let oldUnits = []
  foreach (unitId, info in unitsInfo) {
    info.importantEvents.clear()
    if (info.isKilled && info.time < old)
      oldUnits.append(unitId)
  }
  foreach (unitId in oldUnits)
    unitsInfo.$rawdelete(unitId)
}

function getNextImportantTitle() {
  let curInfo = getTargetInfo(curUnitId, curUnitVersion, curUnitType,
    isKillingHitResult(hitResult))

  let ammoEvent = curInfo.importantEvents?.ammoEvent[0]
  if (ammoEvent != null) {
    curInfo.importantEvents.ammoEvent.remove(0)
    return loc($"part_destroyed/{ammoEvent.munition}")
  }

  let partEvent = curInfo.importantEvents?.partEvent[0]
  if (partEvent != null) {
    curInfo.importantEvents.partEvent.remove(0)
    return loc($"part_destroyed/{partEvent.partName}")
  }

  return ""
}

function showCritAnimation() {
  if (!canShowCritAnimation || !(scene?.isValid() ?? false))
    return

  canShowCritAnimation = false
  let animObj = scene.findObject("critAnim")
  animObj["_size-timer"] = "0"
  animObj.width = 1
  animObj.setFloatProp(animSizeTimerPid, 0.0)
  animObj.setFloatProp(animTimerPid, 0.0)
  animObj["color-factor"] = "255"
  animObj.needAnim = "yes"
}

function updateTitle() {
  clearTimer(updateTitle)
  if (!isVisible || !(titleObj?.isValid() ?? false))
    return

  let title = getNextImportantTitle()
  if (title != "") {
    setTimeout(TIME_TITLE_SHOW_SEC, updateTitle)
    scene.result = "kill"
    titleObj.show(true)
    titleObj.setValue(title)
    return
  }

  let style = styles?[hitResult] ?? "none"
  scene.result = style
  let isVisibleTitle = hitResult != DM_HIT_RESULT_NONE
  titleObj.show(isVisibleTitle)
  if (isVisibleTitle) {
    titleObj.setValue(utf8ToUpper(loc($"hitcamera/result/{style}")))
    setTimeout(TIME_TITLE_SHOW_SEC, updateTitle)
    hitResult = DM_HIT_RESULT_NONE
  }
}

function showRelativeCrewLoss() {
  let unitInfo = getTargetInfo(curUnitId, curUnitVersion, curUnitType, isKillingHitResult(hitResult))
  let { crewRelative, crewLostRelative } = unitInfo

  let hasCrewChange = crewLostRelative < -1 || crewRelative % 1 - crewLostRelative < 0
  if (!crewLostRelative || !hasCrewChange || !(scene?.isValid() ?? false))
    return

  unitInfo.crewLostRelative = 0

  let crewNestObj = scene.findObject("crew_relative_nest")
  crewNestObj._blink = "yes"


  let lostTxt = format("%2.f%s", min(stdMath.round(crewLostRelative), -1), loc("measureUnits/percent"))
  let data = "".concat("hitCamLostCrewRelativeText { text:t='", lostTxt, "' }")
  get_cur_gui_scene().prependWithBlk(crewNestObj.findObject("crew_relative_lost"), data, this)
}

function showCrewCount() {
  let unitInfo = getTargetInfo(curUnitId, curUnitVersion,
    curUnitType, isKillingHitResult(hitResult))
  let { crewCount, crewTotalCount, crewLostCount } = unitInfo
  unitInfo.crewLostCount = 0
  if (!isVisible || crewLostCount == 0)
    return
  if (!(scene?.isValid() ?? false))
    return

  let crewNestObj = scene.findObject("crew_nest")
  crewNestObj._blink = "yes"

  let data = "".concat("hitCameraLostCrewText { text:t='",
    colorize("warningTextColor", crewLostCount), "' }")
  get_cur_gui_scene().prependWithBlk(
    crewNestObj.findObject("lost_crew_count"), data, this)

  let crewColor = crewCount <= minAliveCrewCount ? "warningTextColor" : "activeTextColor"
  crewNestObj.findObject("crew_count").setValue(colorize(crewColor, crewCount))
  let totalText = crewTotalCount > 0 ? $"{loc("ui/slash")}{crewTotalCount}" : ""
  crewNestObj.findObject("max_crew_count").setValue(totalText)
}

function updateCrewCount(unitInfo, data = null) {
  clearTimer(showCrewCount)
  clearTimer(showRelativeCrewLoss)
  if (!(scene?.isValid() ?? false))
    return
  let isShowCrew = !unitInfo.isKilled
    && (curUnitType == ES_UNIT_TYPE_SHIP || curUnitType == ES_UNIT_TYPE_BOAT)
  if (!isShowCrew) {
    scene.findObject("crew_nest")._blink = "no"
    return
  }

  unitInfo.crewTotalCount = data?.crewTotalCount ?? camInfo?.crewTotal ?? -1
  let crewCount = data?.crewAliveCount ?? camInfo?.crewAlive ?? -1
  if (unitInfo.crewCount == -1)
    unitInfo.crewCount = crewCount
  let crewLostCount = crewCount - unitInfo.crewCount

  let minCrewCount = data?.crewAliveMin ?? camInfo?.crewAliveMin ?? 0
  let bestMinCrewCount = camInfo?.bestMinCrewCount ?? minCrewCount
  let maxCrewLeftPercent = (1.0 + (bestMinCrewCount.tofloat() - minCrewCount) / unitInfo.crewTotalCount) * 100
  let newCrewRelative = clamp(stdMath.lerp(minCrewCount - 1, unitInfo.crewTotalCount, 0, maxCrewLeftPercent, crewCount), 0, 100)

  let crewChangeRelative = unitInfo.crewRelative > 0 ? newCrewRelative - unitInfo.crewRelative : 0
  unitInfo.crewRelative = newCrewRelative
  if (!(data?.updateDebuffsOnly ?? true) && crewChangeRelative < 0.0)
    unitInfo.crewLostRelative += crewChangeRelative

  setTimeout(TIME_TO_SUM_RELATIVE_CREW_LOST, showRelativeCrewLoss)

  if (crewCount != -1 && crewLostCount < 0) {
    unitInfo.crewLostCount = unitInfo.crewLostCount + crewLostCount
    unitInfo.crewCount = crewCount
  }
  if (unitInfo.crewLostCount == 0)
    return

  minAliveCrewCount = data?.crewAliveMin ?? camInfo?.crewAliveMin ?? minAliveCrewCount
  setTimeout(TIME_TO_SUM_CREW_LOST_SEC, showCrewCount)
}

let fullHealthColor = "#909E35"
let healthColorConfig = [
  { remainingHp = 0.25, color = "#FD0001" }
  { remainingHp = 0.75,  color = "#F6B236" }
]

//

























function update() {
  if (!(scene?.isValid() ?? false))
    return

  scene.show(isVisible)
  if (!isVisible)
    return

  updateFadeAnimation()
  updateTitle()
}

function hitCameraReinit() {
  isEnabled = get_option_xray_kill()
  update()
}

function onHitCameraEvent(mode, result, info) {
  let newUnitType = info?.unitType ?? curUnitType
  let needResetUnitType = newUnitType != curUnitType

  let needFade   = mode == HIT_CAMERA_FADE_OUT
  let isStarted  = mode == HIT_CAMERA_START
  isVisible      = isEnabled && (isStarted || needFade || mode == HIT_CAMERA_FADE_IN || mode == HIT_CAMERA_START)
  stopFadeTimeS  = needFade ? (info?.stopFadeTime ?? -1) : -1
  hitResult      = result
  curUnitId      = info?.unitId ?? curUnitId
  curUnitVersion = info?.unitVersion ?? curUnitVersion
  curUnitType    = newUnitType
  if (isStarted) {
    camInfo      = info
    if ((scene?.isValid() ?? false)) {
      let animObj = scene.findObject("critAnim")
      animObj["color-factor"] = "0"
      animObj.needAnim = "no"
    }
    canShowCritAnimation = true
  }

  if (needResetUnitType && (infoObj?.isValid() ?? false)) {
    let guiScene = infoObj.getScene()
    let markupFilename = debuffTemplates?[curUnitType]
    if (markupFilename)
      guiScene.replaceContent(infoObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(infoObj, "", 0, this)
  }

  if (needResetUnitType && damageStatusObj?.isValid()) {
    let guiScene = damageStatusObj.getScene()
    let markupFilename = damageStatusTemplates?[curUnitType]
    if (markupFilename)
      guiScene.replaceContent(damageStatusObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(damageStatusObj, "", 0, this)
  }

  if (isVisible) {
    let unitInfo = getTargetInfo(curUnitId, curUnitVersion,
      curUnitType, isKillingHitResult(hitResult))
    foreach (item in (debuffsListsByUnitType?[curUnitType] ?? []))
      updateDebuffItem(item, unitInfo)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
    updateCrewCount(unitInfo)
  }
  else
    cleanupUnitsInfo()

  update()
}

function onHitCameraUpdateFiresEvent(fireArr) {
  if ((fireArr?.len() ?? 0) == 0)
    return
  // Something or other
}

function onEnemyPartDamage(data) {
  if (!isEnabled)
    return

  let unitInfo = getTargetInfo(data?.unitId ?? -1, data?.unitVersion ?? -1,
    data?.unitType ?? ES_UNIT_TYPE_INVALID, data?.unitKilled ?? false)

  local partName = null
  local partDmName = null
  local isPartKilled = data?.partKilled ?? false

  if (!unitInfo.isKilled) {
    partName = data?.partName
    if (!partName || !isInArray(partName, unitInfo.trackedPartNames))
      return

    let parts = unitInfo.parts
    if (!(partName in parts))
      parts[partName] <- { dmParts = {} }

    partDmName = data?.partDmName
    if (partDmName != null) {
      if (!(partDmName in parts[partName].dmParts))
        parts[partName].dmParts[partDmName] <- { partKilled = isPartKilled }
      let dmPart = parts[partName].dmParts[partDmName]

      isPartKilled = isPartKilled ||  dmPart.partKilled
      dmPart.partKilled = isPartKilled

      foreach (k, v in data)
        dmPart[k] <- v

      let isPartDead = dmPart?.partDead ?? false
      let partHp  = dmPart?.partHp ?? 1.0
      dmPart._hp <- (isPartKilled || isPartDead) ? 0.0 : partHp
    }
  }

  if (isVisible && unitInfo.unitId == curUnitId) {
    let isKill = isPartKilled || (unitInfo.isKilled && !unitInfo.isKillProcessed)

    foreach (item in (debuffsListsByUnitType?[unitInfo.unitType] ?? []))
      if (!item.isUpdateByEnemyDamageState && isKill && item.parts.contains(partName))
        updateDebuffItem(item, unitInfo, partName, data)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
  }
}

function onHitCameraImportantEvents(data) {
  if (!isVisible)
    return

  let { unitId, unitVersion, unitType } = data
  let unitInfo = getTargetInfo(unitId, unitVersion,
    unitType, isKillingHitResult(hitResult))
  foreach (key in importantEventKeys) {
    let events = data?[key] ?? []
    if (events.len() == 0)
      continue
    let unitInfoEvents = unitInfo.importantEvents?[key] ?? []
    if (type(events) == "table")
      unitInfoEvents.append(events)
    else
      unitInfoEvents.extend(events)
    unitInfo.importantEvents[key] <- unitInfoEvents
  }

  showCritAnimation()
  updateTitle()
}

function onEnemyDamageState(event) {
  if (curUnitType in (damageStatusTemplates)) {
    let { artilleryTotalCount  = 5, torpedoTotalCount = 5, artilleryHealth = 100, hasFire = false, engineHealth = 100,
      torpedoTubesHealth = 100, ruddersHealth = 100, hasBreach = false  } = event
    let artilleryText = format("%d/%d", stdMath.round(artilleryHealth*artilleryTotalCount/100.), artilleryTotalCount)
    let torpedoText =
      torpedoTotalCount != 0 ? format("%d/%d", stdMath.round(torpedoTubesHealth*torpedoTotalCount/100.), torpedoTotalCount) : ""
    setDamageStatus("artillery_health", artilleryHealth, artilleryText)
    setDamageStatus("fire_status", hasFire ? 1 : -1)
    setDamageStatus("engine_health", engineHealth, format("%d%%", engineHealth))
    setDamageStatus("torpedo_tubes_health", torpedoTubesHealth, torpedoText)
    setDamageStatus("rudders_health", ruddersHealth)
    setDamageStatus("breach_status", hasBreach ? 1 : -1)
  }

  let unitInfo = getTargetInfo(curUnitId, curUnitVersion,
    curUnitType, isKillingHitResult(hitResult))
  foreach (item in (debuffsListsByUnitType?[curUnitType] ?? []))
    if (item.isUpdateByEnemyDamageState)
      updateDebuffItem(item, unitInfo, null, event)

  updateCrewCount(unitInfo, event)
  //


}

function hitCameraInit(nest) {
  if (!(nest?.isValid() ?? false))
    return

  if ((scene?.isValid() ?? false) && scene.isEqual(nest))
    return

  scene = nest
  titleObj = scene.findObject("title")
  infoObj  = scene.findObject("info")
  damageStatusObj = scene.findObject("damageStatus")

  if (!hasFeature("HitCameraTargetStateIconsTank") && (ES_UNIT_TYPE_TANK in debuffTemplates))
    debuffTemplates.$rawdelete(ES_UNIT_TYPE_TANK)

  foreach (unitType, _fn in debuffTemplates) {
    debuffsListsByUnitType[unitType] <- g_hud_enemy_debuffs.getTypesArrayByUnitType(unitType)
    trackedPartNamesByUnitType[unitType] <- g_hud_enemy_debuffs.getTrackedPartNamesByUnitType(unitType)
  }

  minAliveCrewCount = getMinAliveCrewCount()

  g_hud_event_manager.subscribe("EnemyDamageState", onEnemyDamageState, this)
  g_hud_event_manager.subscribe("HitCameraImportanEvents", onHitCameraImportantEvents, this)

  reset()
  hitCameraReinit()
}

addListenersWithoutEnv({
  function LoadingStateChange(_) {
    if (!isInFlight())
      reset()
  }
})

eventbus_subscribe("EnemyPartsDamage", function(allDamageData) {
  foreach (data in allDamageData) {
    onEnemyPartDamage(data)
  }
})

eventbus_subscribe("on_hit_camera_event", function(event) {
  let {mode, result, info} = event
  onHitCameraEvent(mode, result, info)
  if (isKillingHitResult(result))
    g_hud_event_manager.onHudEvent("HitcamTargetKilled", info)
})

eventbus_subscribe("on_hitcamera_update_fires_event", function(event) {
  let {fireArr} = event
  onHitCameraUpdateFiresEvent(fireArr)
})

::get_hit_camera_aabb <- getHitCameraAABB // called from client

return {
  hitCameraInit
  hitCameraReinit
  getHitCameraAABB
}
