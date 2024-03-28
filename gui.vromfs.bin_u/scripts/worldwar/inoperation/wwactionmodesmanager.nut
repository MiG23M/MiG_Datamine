from "%scripts/dagui_natives.nut" import ww_get_selected_armies_names, ww_send_operation_request, ww_find_army_name_by_coordinates, ww_convert_map_to_world_position
from "%scripts/dagui_library.nut" import *
let DataBlock = require("DataBlock")
let { wwSetCurrActionType, wwGetCurrActionType, wwGetMapCellByCoords,
  wwArtillerySetAttackRadius, wwArtilleryGetAttackRadius,
  wwGetUnloadArmyFromTransportError, wwGetLoadArmyToTransportError } = require("worldwar")
let transportManager = require("%scripts/worldWar/inOperation/wwTransportManager.nut")
let { addTask } = require("%scripts/tasker.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { addPopup } = require("%scripts/popups/popups.nut")

function setActionMode(modeId = AUT_None) {
  wwSetCurrActionType(modeId)
  wwEvent("ArmyStatusChanged")
}

function onSuccessAction() {
  transportManager.clearCacheLoadedTransport()
  setActionMode()
}

function useTransportAction(clickPos, requestActionCb) {
  let loadArmyName = ww_find_army_name_by_coordinates(clickPos.x, clickPos.y) ?? ""
  let cellIdx = wwGetMapCellByCoords(clickPos.x, clickPos.y)
  foreach (armyName in ww_get_selected_armies_names())
    if (::g_world_war.getArmyByName(armyName).isTransport())
      requestActionCb(armyName, loadArmyName, cellIdx)
}

let actionModesById = {
  [AUT_ArtilleryFire] = {
    startArtilleryFire = function startArtilleryFire(mapPos, army) {
      let blk = DataBlock()
      blk.setStr("army", army.name)
      blk.setStr("point", $"{mapPos.x},{mapPos.y}")
      blk.setStr("radius", wwArtilleryGetAttackRadius().tostring())

      let taskId = ww_send_operation_request("cln_ww_artillery_strike", blk)
      addTask(taskId, null, @() setActionMode(),
        Callback(function (_errorCode) {
          ::g_world_war.popupCharErrorMsg("cant_fire", this.getTitle())
        }, this))
    }
    makeArtilleryFire = function makeArtilleryFire(mapPos, army) {
      if (army.canFire()) {
        get_cur_gui_scene()?.playSound("ww_artillery_player")
        this.startArtilleryFire(mapPos, army)
      }
      else
        addPopup(this.getTitle(), loc("worldwar/artillery/notReadyToFire"),
          null, null, null, "cant_fire")
    }
    useAction = function useAction(clickPos) {
      let mapPos = ww_convert_map_to_world_position(clickPos.x, clickPos.y)
      let selectedArmies = ww_get_selected_armies_names()
      for (local i = 0; i < selectedArmies.len(); i++) {
        let army = ::g_world_war.getArmyByName(selectedArmies[i])
        if (army.hasArtilleryAbility)
          this.makeArtilleryFire(mapPos, army)
      }
    }
    setMode = @() setActionMode(AUT_ArtilleryFire)
    getTitle = @() loc("worldwar/artillery/cant_fire")
    onMouseWheel = function onMouseWheel(is_up) {
      let attackRadius = wwArtilleryGetAttackRadius() + (is_up ? 0.5 : -0.5)
      wwArtillerySetAttackRadius(attackRadius)
    }
  },
  [AUT_TransportLoad] = {
    errorGroupName = "load_transport_army_error"
    requestAction = function requestAction(transportName, armyName, _cellIdx) {
      let errorId = wwGetLoadArmyToTransportError(transportName, armyName)
      if (errorId != "") {
        ::g_world_war.popupCharErrorMsg(this.errorGroupName, "", errorId)
        return
      }

      let params = DataBlock()
      params.setStr("transportName", transportName)
      params.setStr("armyName", armyName)
      let taskId = ww_send_operation_request("cln_ww_load_transport", params)
      addTask(taskId, null, @() onSuccessAction(),
        Callback(@(_errorCode) ::g_world_war.popupCharErrorMsg(this.errorGroupName), this))
    }
    useAction = @(clickPos) useTransportAction(clickPos, this.requestAction)
    setMode = @() setActionMode(AUT_TransportLoad)
    getTitle = @() loc("worldwar/cant_use_transport")
  },
  [AUT_TransportUnload] = {
    errorGroupName = "unload_transport_army_error"
    requestAction = function requestAction(transportName, armyName, cellIdx) {
      let errorId = wwGetUnloadArmyFromTransportError(transportName, armyName, cellIdx)
      if (errorId != "") {
        ::g_world_war.popupCharErrorMsg(this.errorGroupName, "", errorId)
        return
      }

      let params = DataBlock()
      params.setStr("transportName", transportName)
      params.setStr("armyName", armyName)
      params.setInt("cellIdx", cellIdx)
      let taskId = ww_send_operation_request("cln_ww_unload_transport", params)
      addTask(taskId, null, @() onSuccessAction(),
        Callback(@(_errorCode) ::g_world_war.popupCharErrorMsg(this.errorGroupName), this))
    }
    requestActionForAllLoadedArmy = function requestActionForAllLoadedArmy(transportName, _armyName, cellIdx) {
      let loadedTransportArmy = transportManager.getLoadedTransport()?[transportName]
      if (loadedTransportArmy != null) {
        let armiesBlk =  loadedTransportArmy.armies
        for (local i = 0; i < armiesBlk.blockCount(); i++)
          this.requestAction(transportName, armiesBlk.getBlock(i).getBlockName(), cellIdx)
      }
    }
    useAction = @(clickPos) useTransportAction(clickPos, this.requestActionForAllLoadedArmy)
    setMode = @() setActionMode(AUT_TransportUnload)
    getTitle = @() loc("worldwar/cant_use_transport")
  }
}

let getCurActionModeId = @() wwGetCurrActionType()
let getCurActionMode = @() actionModesById?[getCurActionModeId()]

function trySetActionModeOrCancel(modeId) {
  if (getCurActionModeId() == modeId) {
    setActionMode()
    return
  }

  let armiesNames = ww_get_selected_armies_names()
  if (!armiesNames.len())
    return

  if (armiesNames.len() > 1)
    return addPopup(actionModesById?[modeId].getTitle() ?? "",
      loc("worldwar/artillery/selectOneArmy"), null, null, null, "select_one_army")

  setActionMode(modeId)
}

return {
  setActionMode
  trySetActionModeOrCancel
  getCurActionModeId
  getCurActionMode
}