//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { wwGetOperationId, wwGetPlayerSide } = require("worldwar")

gui_handlers.WwCommanders <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/worldWarCommandersInfo.tpl"
  sceneBlkName = null

  groupsHandlers = null

  static groupsInColumnMax = 5
  static groupsInRowMax = 3

  function getSceneTplView() {
    return this.getGroupsArray()
  }

  function getSceneTplContainerObj() {
    return this.scene
  }

  function initScreen() {
    this.onSwitchCommandersSide(this.getObj("commanders_switch_box"))
    foreach (groupHandler in this.groupsHandlers)
      groupHandler.updateSelectedStatus()
  }

  function getGroupsArray() {
    let groupsView = []
    local useSwitchMode = false
    let view = { items = [] }
    let mapName = getOperationById(wwGetOperationId())?.getMapId() ?? ""
    this.groupsHandlers = []
    foreach (side in ::g_world_war.getSidesOrder()) {
      let groups = ::g_world_war.getArmyGroupsBySide(side)
      if (groups.len() == 0)
        continue

      local myClanGroupView = null
      let sideGroupsView = []
      let armyCountry = []
      let myClanId = ::clan_get_my_clan_id()
      foreach (_idx, group in groups) {
        let country = group.getArmyCountry()
        if (!isInArray(country, armyCountry))
          armyCountry.append(country)

        let groupHandler = ::WwArmyGroupHandler(this.scene, group)
        this.groupsHandlers.append(groupHandler)

        let groupView = group.getView()
        if (group.getClanId() == myClanId)
          myClanGroupView = groupView
        else
          sideGroupsView.append(groupView)
      }

      if (myClanGroupView)
        sideGroupsView.insert(0, myClanGroupView)

      let selected = wwGetPlayerSide() == side
      useSwitchMode = useSwitchMode || sideGroupsView.len() > this.groupsInColumnMax

      let countryFlagsList = armyCountry.map(@(country) {
        image = getCustomViewCountryData(country, mapName).icon
      })

      local teamText = loc(getCustomViewCountryData(armyCountry[0], mapName).locId)
      if (armyCountry.len() > 1) {
        let postfix = wwGetPlayerSide() == side ? "allies" : "enemies"
        teamText = loc("worldWar/side/" + postfix)
      }

      view.items.append({
        text = teamText
        image = countryFlagsList
        selected = selected
        params = "width:t='pw/2'"
      })

      groupsView.append({
        teamText = teamText
        armyCountryImg = countryFlagsList
        army = sideGroupsView
        customWidth = "pw/" + this.groupsInRowMax
      })
    }

    return {
      groups = groupsView
      hasTextAfterIcon = true
      isGroupItem = true
      addArmyClickCb = true
      checkMyArmy = true
      groupsNum = groupsView.len()
      useSwitchMode = useSwitchMode
      switchBoxItems = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    }
  }

  function onSwitchCommandersSide(obj) {
    if (!checkObj(obj))
      return

    let placeObj = this.getObj("switch_mode_items_place")
    if (!checkObj(placeObj))
      return

    let side = obj.getValue() + 1
    foreach (groupHandler in this.groupsHandlers) {
      let viewObj = placeObj.findObject(groupHandler.group.getView().getId())
      if (!checkObj(viewObj))
        return

      viewObj.show(groupHandler.group.isMySide(side))
    }
  }

  function onHoverArmyItem(obj) {
    let clanId = obj.clanId
    let groups = ::g_world_war.getArmyGroups(@(group) group.clanId == clanId)
    let groupArmyNames = []
    foreach (group in groups)
      groupArmyNames.extend(::ww_get_armies_names_of_armygroup({
        side         = ::ww_side_val_to_name(group.owner.side)
        country      = group.owner.country
        armyGroupIdx = group.owner.armyGroupIdx
      }))
    ::ww_update_popuped_armies_name(groupArmyNames)
  }

  function onClickArmy(obj) {
    ::showClanPage(obj.clanId, "", "")
  }

  function onHoverLostArmyItem(_obj) {
    ::ww_update_popuped_armies_name([])
  }

  function onEventWWArmyManagersInfoUpdated(_p) {
    let view = this.getSceneTplView()
    let data = handyman.renderCached(this.sceneTplName, view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }
}
