from "%scripts/dagui_library.nut" import *
from "%scripts/mainmenu/topMenuConsts.nut" import TOP_MENU_ELEMENT_TYPE
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { addButtonConfig } = require("%scripts/mainmenu/topMenuButtons.nut")
let { getOperationById, hasAvailableMapToBattle, getMapByName
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getUnlocksByType } = require("%scripts/unlocks/unlocksCache.nut")
let { openUrlByObj } = require("%scripts/onlineShop/url.nut")
let { wwGetOperationId, wwIsOperationLoaded } = require("worldwar")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

let template = {
  category = -1
  value = @() ::g_world_war_render.isCategoryEnabled(this.category)
  onChangeValueFunc = @(value) ::g_world_war_render.setCategory(this.category, value)
  isHidden = @(...) !::g_world_war_render.isCategoryVisible(this.category)
  elementType = TOP_MENU_ELEMENT_TYPE.CHECKBOX
}

let list = {
  WW_MAIN_MENU = {
    text = "#worldWar/menu/mainMenu"
    onClickFunc = @(_obj, _handler) ::g_world_war.openOperationsOrQueues()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_OPERATIONS = {
    text = "#worldWar/menu/selectOperation"
    onClickFunc = function(_obj, _handler) {
      let curOperation = getOperationById(wwGetOperationId())
      if (!curOperation)
        return ::g_world_war.openOperationsOrQueues()

      ::g_world_war.openOperationsOrQueues(false, getMapByName(curOperation.data.map))
    }
    isHidden = @(...) !hasFeature("WWOperationsList")
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_HANGAR = {
    text = "#worldWar/menu/quitToHangar"
    onClickFunc = function(_obj, handler) {
      ::g_world_war.stopWar()
      if (!wwIsOperationLoaded())
        handler?.goBack()
    }
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_FILTER_RENDER_ZONES = {
    category = ERC_ZONES
    text = loc("worldwar/renderMap/render_zones")
    image = @() "#ui/gameuiskin#render_zones"
  }
  WW_FILTER_RENDER_ARROWS = {
    category = ERC_ALL_ARROWS
    text = loc("worldwar/renderMap/render_arrows")
    image = @() "#ui/gameuiskin#btn_weapons.svg"
    isHidden = @(...) true
  }
  WW_FILTER_RENDER_ARROWS_FOR_SELECTED = {
    category = ERC_ARROWS_FOR_SELECTED_ARMIES
    text = loc("worldwar/renderMap/render_arrows_for_selected")
    image = @() "#ui/gameuiskin#render_arrows"
  }
  WW_FILTER_RENDER_BATTLES = {
    category = ERC_BATTLES
    text = loc("worldwar/renderMap/render_battles")
    image = @() "#ui/gameuiskin#battles_open"
  }
  WW_FILTER_RENDER_MAP_PICTURES = {
    category = ERC_MAP_PICTURE
    text = loc("worldwar/renderMap/render_map_picture")
    image = @() "#ui/gameuiskin#battles_open"
    isHidden = @(...) true
  }
  WW_FILTER_RENDER_DEBUG = {
    value = @() ::g_world_war.isDebugModeEnabled()
    text = "#mainmenu/btnDebugUnlock"
    image = @() "#ui/gameuiskin#battles_closed"
    onChangeValueFunc = @(value) ::g_world_war.setDebugMode(value)
    isHidden = @(...) !hasFeature("worldWarMaster")
  }
  WW_LEADERBOARDS = {
    text = "#mainmenu/titleLeaderboards"
    onClickFunc = @(_obj, _handler) loadHandler(gui_handlers.WwLeaderboard,
      { beginningMode = "ww_clans" })
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_ACHIEVEMENTS = {
    text = "#mainmenu/btnUnlockAchievement"
    onClickFunc = @(_obj, handler) handler?.onOpenAchievements()
    isHidden = @(...) getUnlocksByType("achievement").findindex(
      @(u) u?.chapter && u.chapter == "worldwar" && u?.hidden != true) == null
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_VEHICLE_SET = {
    text = "#worldWar/menu/createVehicleSet"
    onClickFunc = @(_obj, handler) handler?.openVehiclesPresetModal()
    isHidden = @(...) !hasAvailableMapToBattle()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
    unseenIcon = @() SEEN.WW_OPERATION_AVAILABLE
  }
  WW_SCENARIO_DESCR = {
    text = "#worldwar/scenarioDescription"
    onClickFunc = @(_obj, handler) handler?.openOperationsListModal()
    isHidden = @(...) !hasAvailableMapToBattle()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_OPERATION_LIST = {
    text = "#worldwar/operationsList"
    onClickFunc = @(_obj, handler) handler?.onOperationListSwitch()
    isHidden = @(...) !hasFeature("WWOperationsList")
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_WIKI = {
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = ""
    isLink = @() true
    isFeatured = @() true
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
}

list.each(@(buttonCfg, name) addButtonConfig(template.__merge(buttonCfg), name))
