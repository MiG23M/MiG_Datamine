//checked for plus_string
from "%scripts/dagui_library.nut" import *

from "hitCamera" import *
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { get_mission_difficulty_int } = require("guiMission")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")
let { isInFlight } = require("gameplayBinding")

const TIME_TITLE_SHOW_SEC = 3
const TIME_TO_SUM_CREW_LOST_SEC = 1 //To sum up the number of crew losses from multiple bullets in a single salvo

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

let function getMinAliveCrewCount() {
  let diffCode = get_mission_difficulty_int()
  let settingsName = ::g_difficulty.getDifficultyByDiffCode(diffCode).settingsName
  let path = $"difficulty_settings/baseDifficulty/{settingsName}/changeCrewTime"
  let changeCrewTime = get_blk_value_by_path(::dgs_get_game_params(), path)
  return changeCrewTime != null ? 1 : 2
}

let getDamageStatusByHealth = @(health)
  health == 100 ? "none"
    : health >= 70  ? "minor"
    : health >= 40  ? "moderate"
    : health >= 10  ? "major"
    : health > 0    ? "critical"
    : health == 0   ? "fatal"
    : "none"

let function setDamageStatus(statusObjId, health) {
  if (!damageStatusObj?.isValid())
    return

  let obj = damageStatusObj.findObject(statusObjId)
  if (!obj?.isValid())
    return

  obj.damage = getDamageStatusByHealth(health)
}

let function updateDebuffItem(item, unitInfo, partName = null, dmgParams = null) {
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

let function updateFadeAnimation() {
  let needFade = stopFadeTimeS > 0
  scene["transp-time"] = needFade ? (stopFadeTimeS * 1000).tointeger() : 1
  scene["transp-base"] = needFade ? 255 : 0
  scene["transp-end"]  = needFade ? 0 : 255
  scene.setFloatProp(animTimerPid, 0.0)
}

let getHitCameraAABB = @() getDaguiObjAabb(scene)
let isKillingHitResult = @(result) result >= DM_HIT_RESULT_KILL && result != DM_HIT_RESULT_INVULNERABLE

let function reset() {
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

let function getTargetInfo(unitId, unitVersion, unitType, isUnitKilled) {
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
      importantEvents = {}
    }

  let info = unitsInfo[unitId]
  info.time = ::get_usefull_total_time()
  info.isKilled = info.isKilled || isUnitKilled

  return info
}

let function cleanupUnitsInfo() {
  let old = ::get_usefull_total_time() - 5.0
  let oldUnits = []
  foreach (unitId, info in unitsInfo) {
    info.importantEvents.clear()
    if (info.isKilled && info.time < old)
      oldUnits.append(unitId)
  }
  foreach (unitId in oldUnits)
    delete unitsInfo[unitId]
}

let function getNextImportantTitle() {
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

let function showCritAnimation() {
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

let function updateTitle() {
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
  if (isVisibleTitle)
    titleObj.setValue(utf8ToUpper(loc($"hitcamera/result/{style}")))
}

let function showCrewCount() {
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

let function updateCrewCount(unitInfo, data = null) {
  clearTimer(showCrewCount)
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

























let function update() {
  if (!(scene?.isValid() ?? false))
    return

  scene.show(isVisible)
  if (!isVisible)
    return

  updateFadeAnimation()
  updateTitle()
}

let function hitCameraReinit() {
  isEnabled = ::get_option_xray_kill()
  update()
}

let function onHitCameraEvent(mode, result, info) {
  let newUnitType = info?.unitType ?? curUnitType
  let needResetUnitType = newUnitType != curUnitType

  let needFade   = mode == HIT_CAMERA_FADE_OUT
  let isStarted  = mode == HIT_CAMERA_START
  isVisible      = isEnabled && (isStarted || needFade)
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

let function onEnemyPartDamage(data) {
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

let function onHitCameraImportantEvents(data) {
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

let function onEnemyDamageState(event) {
  if (curUnitType in (damageStatusTemplates)) {
    setDamageStatus("artillery_health", event?.artilleryHealth ?? 1)
    setDamageStatus("fire_status", (event?.hasFire ?? false) ? 1 : -1)
    setDamageStatus("engine_health", event?.engineHealth ?? 1)
    setDamageStatus("torpedo_tubes_health", event?.torpedoTubesHealth ?? 1)
    setDamageStatus("rudders_health", event?.ruddersHealth ?? 1)
    setDamageStatus("breach_status", (event?.hasBreach ?? false) ? 1 : -1)
  }

  let unitInfo = getTargetInfo(curUnitId, curUnitVersion,
    curUnitType, isKillingHitResult(hitResult))
  foreach (item in (debuffsListsByUnitType?[curUnitType] ?? []))
    if (item.isUpdateByEnemyDamageState)
      updateDebuffItem(item, unitInfo, null, event)

  updateCrewCount(unitInfo, event)
  //


}

let function hitCameraInit(nest) {
  if (!(nest?.isValid() ?? false))
    return

  if ((scene?.isValid() ?? false) && scene.isEqual(nest))
    return

  scene = nest
  titleObj = scene.findObject("title")
  infoObj  = scene.findObject("info")
  damageStatusObj = scene.findObject("damageStatus")

  if (!hasFeature("HitCameraTargetStateIconsTank") && (ES_UNIT_TYPE_TANK in debuffTemplates))
    delete debuffTemplates[ES_UNIT_TYPE_TANK]

  foreach (unitType, _fn in debuffTemplates) {
    debuffsListsByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTypesArrayByUnitType(unitType)
    trackedPartNamesByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTrackedPartNamesByUnitType(unitType)
  }

  minAliveCrewCount = getMinAliveCrewCount()

  ::g_hud_event_manager.subscribe("EnemyPartDamage", onEnemyPartDamage, this)
  ::g_hud_event_manager.subscribe("EnemyDamageState", onEnemyDamageState, this)
  ::g_hud_event_manager.subscribe("HitCameraImportanEvents", onHitCameraImportantEvents, this)

  reset()
  hitCameraReinit()
}

addListenersWithoutEnv({
  function LoadingStateChange(_) {
    if (!isInFlight())
      reset()
  }
})

::on_hit_camera_event <- function on_hit_camera_event(mode, result = DM_HIT_RESULT_NONE, info = {}) { // called from client
  onHitCameraEvent(mode, result, info)

  if (isKillingHitResult(result))
    ::g_hud_event_manager.onHudEvent("HitcamTargetKilled", info)
}

::get_hit_camera_aabb <- getHitCameraAABB // called from client

return {
  hitCameraInit
  hitCameraReinit
  getHitCameraAABB
}
