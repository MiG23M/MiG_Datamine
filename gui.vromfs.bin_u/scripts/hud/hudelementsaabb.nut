//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let hudState = require("hudState")
let { getHitCameraAABB } = require("%scripts/hud/hudHitCamera.nut")
let { subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { actionBarItems } = require("%scripts/hud/actionBarState.nut")
let { getActionBarObjId } = require("%scripts/hud/hudActionBar.nut")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")

let function getAabbObjFromHud(hudFuncName) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (handler == null || !(hudFuncName in handler))
    return null

  return getDaguiObjAabb(handler[hudFuncName]())
}

let dmPanelStatesAabb = mkWatched(persist, "dmPanelStatesAabb", {})

local prevHashAabbParams = ""

let function getHashAabbParams(params) {
  let {pos = [0, 0], size = [0, 0], visible = false} = params
  return ";".concat(pos[0], pos[1], size[0], size[1], visible)
}

let function update_damage_panel_state(params) {
  let hashAabbParams = getHashAabbParams(params)
  if(prevHashAabbParams == hashAabbParams)
    return
  prevHashAabbParams = hashAabbParams
  dmPanelStatesAabb(params)
}

let function getDamagePannelAabb() {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (!handler)
    return null
  let hudType = handler.getHudType()
  return hudType == HUD_TYPE.SHIP || hudType == HUD_TYPE.TANK ? dmPanelStatesAabb.value
    : getDaguiObjAabb(handler.getDamagePannelObj())
}

let function getAircraftInstrumentsAabb() {
  let bbox = hudState.getHudAircraftInstrumentsBbox()
  if (bbox == null || bbox.x2 == 0 || bbox.y2 == 0)
    return null
  return {
    pos  = [ bbox.x1, bbox.y1 ]
    size = [ bbox.x2 - bbox.x1, bbox.y2 - bbox.y1 ]
    visible = true
  }
}

let function getActionBarItemAabb(actionTypeName = null) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  let actionBarObj = handler?.getHudActionBarObj()
  if (!actionBarObj?.isValid())
    return null

  if (actionTypeName == null)
    return getDaguiObjAabb(actionBarObj)

  let actionTypeCode = ::g_hud_action_bar_type?[actionTypeName].code ?? -1
  if (actionTypeCode == -1)
    return null

  let actionItemId = actionBarItems.value.findvalue(@(a) a.type == actionTypeCode)?.id ?? -1
  if (actionItemId == -1)
    return null

  let actionObj = actionBarObj.findObject(getActionBarObjId(actionItemId))
  if (!actionObj?.isValid())
    return null

  return getDaguiObjAabb(actionObj)
}

let aabbList = {
  map = @() getAabbObjFromHud("getTacticalMapObj")
  hitCamera = @() getHitCameraAABB()
  multiplayerScore = @() getAabbObjFromHud("getMultiplayerScoreObj")
  dmPanel = getDamagePannelAabb
  tankDebuffs = @() getAabbObjFromHud("getTankDebufsObj")
  aircraftInstruments = getAircraftInstrumentsAabb
  actionBarItem = getActionBarItemAabb
}

let function getHudElementAabb(elemId) {
  let [name = null, params = null] = elemId?.split("|")
  return params == null
    ? aabbList?[name]()
    : aabbList?[name](params)
}

::get_ingame_map_aabb <- function get_ingame_map_aabb() { return aabbList.map() }  //this function used in native code

subscribe("update_damage_panel_state", @(value) update_damage_panel_state(value))

return {
  getHudElementAabb
  dmPanelStatesAabb
}