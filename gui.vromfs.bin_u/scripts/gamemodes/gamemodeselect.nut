//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let mapPreferencesModal = require("%scripts/missions/mapPreferencesModal.nut")
let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let openClustersMenuWnd = require("%scripts/onlineInfo/clustersMenuWnd.nut")

::dagui_propid.add_name_id("modeId")

::gui_handlers.GameModeSelect <- class extends ::gui_handlers.BaseGuiHandlerWT {
  sceneTplName = "%gui/gameModeSelect/gameModeSelect.tpl"
  shouldBlurSceneBgFn = needUseHangarDof
  needAnimatedSwitchScene = false

  restoreFromModal = false
  newIconWidgetsByGameModeID = {}
  gameModesWithTimer = {}

  filledGameModes = []

  categories = [
    {
      id = "general_game_modes"
      separator = false
      modesGenFunc = "createGameModesView"
      textWhenEmpty = "#mainmenu/gamemodesNotLoaded/desc"
    }
    {
      id = "featured_game_modes"
      separator = true
      modesGenFunc = "createFeaturedModesView"
    }
    {
      id = "debug_game_modes"
      separator = false
      modesGenFunc = "createDebugGameModesView"
    }
  ]

  static basePanelConfig = [
    ES_UNIT_TYPE_AIRCRAFT,
    ES_UNIT_TYPE_TANK,
    ES_UNIT_TYPE_SHIP
  ]

  static function open() {
    ::gui_start_modal_wnd(::gui_handlers.GameModeSelect)
  }

  function getSceneTplView() {
    return { categories = this.categories }
  }

  function initScreen() {
    this.backSceneFunc = ::gui_start_mainmenu
    this.updateContent()
  }

  function fillModesList() {
    this.filledGameModes.clear()

    foreach (cat in this.categories) {
      let modes = this[cat.modesGenFunc]()
      if (modes.len() == 0) {
        this.filledGameModes.append({
          isEmpty = true
          textWhenEmpty = cat?.textWhenEmpty || ""
          isMode = false
        })
        continue
      }

      if (cat?.separator)
        this.filledGameModes.append({ separator = true, isMode = false })
      this.filledGameModes.extend(modes)
    }

    let placeObj = this.scene.findObject("general_game_modes")
    if (!checkObj(placeObj))
      return

    let data = handyman.renderCached("%gui/gameModeSelect/gameModeBlock.tpl", { block = this.filledGameModes })
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    this.setGameModesTimer()
  }

  function updateContent() {
    this.gameModesWithTimer.clear()
    this.newIconWidgetsByGameModeID.clear()

    this.fillModesList()

    this.registerNewIconWidgets()
    this.updateClusters()
    this.updateButtons()
    this.updateEventDescriptionConsoleButton(::game_mode_manager.getCurrentGameMode())

    this.updateSelection()
  }

  function updateSelection() {
    let curGM = ::game_mode_manager.getCurrentGameMode()
    if (curGM == null)
      return

    let curGameModeObj = this.scene.findObject("general_game_modes")
    if (!checkObj(curGameModeObj))
      return

    let index = this.filledGameModes.findindex(@(gm) gm.isMode && gm?.hasContent && gm.modeId == curGM.id) ?? -1
    curGameModeObj.setValue(index)
    ::move_mouse_on_child(curGameModeObj, index)
  }

  function registerNewIconWidgets() {
    foreach (gameMode in this.filledGameModes) {
      if (!gameMode.isMode || !gameMode?.hasContent)
        continue

      let widgetObj = this.scene.findObject(this.getWidgetId(gameMode.id))
      if (!checkObj(widgetObj))
        continue

      let widget = ::NewIconWidget(this.guiScene, widgetObj)
      this.newIconWidgetsByGameModeID[gameMode.id] <- widget
      widget.setWidgetVisible(!::game_mode_manager.isSeen(gameMode.id))
    }
  }

  function createFeaturedModesView() {
    let view = []
    view.extend(this.getViewArray(::game_mode_manager.getPveBattlesGameModes()))
    view.extend(this.getViewArray(::game_mode_manager.getFeaturedGameModes()))
    view.extend(this.createFeaturedLinksView())
    view.extend(this.getViewArray(::game_mode_manager.getClanBattlesGameModes()))
    return view
  }

  function getViewArray(gameModesArray) {
    let view = []
    // First go all wide featured game modes then - non-wide.
    local numNonWideGameModes = 0
    foreach (isWide in [ true, false ]) {
      while (true) {
        let gameMode = this.getGameModeByCondition(gameModesArray,
          @(gameMode) gameMode.displayWide == isWide) // warning disable: -iterator-in-lambda
        if (gameMode == null)
          break
        if (!isWide)
          ++numNonWideGameModes
        let index = u.find_in_array(gameModesArray, gameMode)
        gameModesArray.remove(index)
        view.append(this.createGameModeView(gameMode))
      }
    }
    this.sortByUnitType(view)
    // Putting a dummy block to show featured links in one line.
    if ((numNonWideGameModes & 1) == 1)
      view.append(this.createGameModeView(null))
    return view
  }

  function sortByUnitType(gameModeViews) {
    gameModeViews.sort(function(a, b) { // warning disable: -return-different-types
      foreach (unitType in unitTypes.types) {
        if (b.isWide != a.isWide)
          return b.isWide <=> a.isWide
        let isAContainsType = a.gameMode.unitTypes.indexof(unitType.esUnitType) != null
        let isBContainsType = b.gameMode.unitTypes.indexof(unitType.esUnitType) != null
        if (! isAContainsType && ! isBContainsType)
          continue
        return isBContainsType <=> isAContainsType
        || b.gameMode.unitTypes.len() <=> a.gameMode.unitTypes.len()
      }
      return 0
    })
  }

  function createDebugGameModesView() {
    let view = []
    let debugGameModes = ::game_mode_manager.getDebugGameModes()
    foreach (gameMode in debugGameModes)
      view.append(this.createGameModeView(gameMode))
    return view
  }

  function createFeaturedLinksView() {
    let res = []
    foreach (_idx, mode in ::featured_modes) {
      if (!mode.isVisible())
        continue

      let id = ::game_mode_manager.getGameModeItemId(mode.modeId)
      let hasNewIconWidget = mode.hasNewIconWidget && !::game_mode_manager.isSeen(id)
      let newIconWidgetContent = hasNewIconWidget ? ::NewIconWidget.createLayout() : null

      res.append({
        id = id
        modeId = mode.modeId
        hasContent = true
        isMode = true
        text  = mode.text
        textDescription = mode.textDescription
        hasCountries = false
        isWide = mode.isWide
        image = mode.image()
        gameMode = mode
        checkBox = false
        linkIcon = true
        isFeatured = true
        onClick = "onGameModeSelect"
        onHover = "markGameModeSeen"
        showEventDescription = false
        newIconWidgetId = this.getWidgetId(id)
        newIconWidgetContent = newIconWidgetContent
        inactiveColor = mode?.inactiveColor ?? @() false
        crossPlayRestricted = mode?.crossPlayRestricted ?? @() false
        crossplayTooltip = mode?.crossplayTooltip
        isCrossPlayRequired = mode?.isCrossPlayRequired ?? @() false
        tooltip = mode?.getTooltipText ?? @() ""
      })
      if (mode?.updateByTimeFunc)
        this.gameModesWithTimer[id] <- mode.updateByTimeFunc
    }
    return res
  }

  function createGameModesView() {
    let gameModesView = []
    let partitions = ::game_mode_manager.getGameModesPartitions()
    foreach (partition in partitions) {
      let partitionView = this.createGameModesPartitionView(partition)
      if (partitionView)
        gameModesView.extend(partitionView)
    }
    return gameModesView
  }

  function createGameModeView(gameMode, _separator = false, isNarrow = false) {
    if (gameMode == null)
      return {
        hasContent = false
        isNarrow = isNarrow
        isMode = true
      }

    let countries = this.createGameModeCountriesView(gameMode)
    let isLink = gameMode.displayType.showInEventsWindow
    let event = ::game_mode_manager.getGameModeEvent(gameMode)
    let trophyName = ::events.getEventPVETrophyName(event)

    let id = ::game_mode_manager.getGameModeItemId(gameMode.id)
    let hasNewIconWidget = !::game_mode_manager.isSeen(id)
    let newIconWidgetContent = hasNewIconWidget ? ::NewIconWidget.createLayout() : null

    let crossPlayRestricted = isMultiplayerPrivilegeAvailable.value && !this.isCrossPlayEventAvailable(event)
    let inactiveColor = !isMultiplayerPrivilegeAvailable.value || crossPlayRestricted

    if (gameMode?.updateByTimeFunc)
      this.gameModesWithTimer[id] <- this.mode.updateByTimeFunc

    return {
      id = id
      modeId = gameMode.id
      hasContent = true
      isMode = true
      isConsoleBtn = ::show_console_buttons
      text = gameMode.text
      getEvent = gameMode?.getEvent
      textDescription = getTblValue("textDescription", gameMode, null)
      tooltip = gameMode.getTooltipText()
      hasCountries = countries.len() != 0
      countries = countries
      isCurrentGameMode = gameMode.id == ::game_mode_manager.getCurrentGameModeId()
      isWide = gameMode.displayWide
      isNarrow = isNarrow
      image = gameMode.image
      videoPreview = gameMode.videoPreview
      checkBox = !isLink
      linkIcon = isLink
      newIconWidgetId = this.getWidgetId(id)
      newIconWidgetContent = newIconWidgetContent
      isFeatured = true
      onClick = "onGameModeSelect"
      onHover = "markGameModeSeen"
      // Used to easily backtrack corresponding game mode.
      gameMode = gameMode
      inactiveColor = (gameMode?.inactiveColor ?? @() false)() || inactiveColor
      crossPlayRestricted = crossPlayRestricted
      crossplayTooltip = this.getRestrictionTooltipText(event)
      isCrossPlayRequired = crossplayModule.needShowCrossPlayInfo() && !::events.isEventPlatformOnlyAllowed(event)
      showEventDescription = !isLink && ::events.isEventNeedInfoButton(event)
      eventTrophyImage = this.getTrophyMarkUpData(trophyName)
      isTrophyRecieved = trophyName == "" ? false : !::can_receive_pve_trophy(-1, trophyName)
      mapPreferences = this.isShowMapPreferences(gameMode?.getEvent())
      prefTitle = mapPreferencesParams.getPrefTitle(gameMode?.getEvent())
    }
  }

  function getRestrictionTooltipText(event) {
    if (!isMultiplayerPrivilegeAvailable.value)
      return loc("xbox/noMultiplayer")

    if (!crossplayModule.needShowCrossPlayInfo()) //No need tooltip on other platforms
      return null

    //Always send to other platform if enabled
    //Need to notify about it
    if (crossplayModule.isCrossPlayEnabled())
      return loc("xbox/crossPlayEnabled")

    //If only platform - no need to notify
    if (::events.isEventPlatformOnlyAllowed(event))
      return null

    //Notify that crossplay is strongly required
    return loc("xbox/crossPlayRequired")
  }

  function isCrossPlayEventAvailable(event) {
    return crossplayModule.isCrossPlayEnabled()
           || ::events.isEventPlatformOnlyAllowed(event)
  }

  function getWidgetId(gameModeId) {
    return gameModeId + "_widget"
  }

  function getTrophyMarkUpData(trophyName) {
    if (u.isEmpty(trophyName))
      return null

    let trophyItem = ::ItemsManager.findItemById(trophyName, itemType.TROPHY)
    if (!trophyItem)
      return null

    return trophyItem.getNameMarkup(0, false)
  }

  function createGameModeCountriesView(gameMode) {
    let res = []
    local countries = gameMode.countries
    if (!countries.len() || countries.len() >= ::g_crews_list.get().len())
      return res

    local needShowLocked = false
    if (countries.len() >= 0.7 * ::g_crews_list.get().len()) {
      let lockedCountries = []
      foreach (countryData in ::g_crews_list.get()) {
        let country = countryData.country
        if (!isInArray(country, countries))
          lockedCountries.append(country)
      }

      needShowLocked = true
      countries = lockedCountries
    }

    foreach (country in countries)
      res.append({ img = ::get_country_icon(country, false, needShowLocked) })
    return res
  }

  function createGameModesPartitionView(partition) {
    if (partition.gameModes.len() == 0)
      return null

    let gameModes = partition.gameModes
    let needEmptyGameModeBlocks = !!u.search(gameModes, @(gm) !gm.displayWide)
    let view = []
    foreach (_idx, esUnitType in this.basePanelConfig) {
      let gameMode = this.chooseGameModeEsUnitType(gameModes, esUnitType, this.basePanelConfig)
      if (gameMode)
        view.append(this.createGameModeView(gameMode, false, true))
      else if (needEmptyGameModeBlocks)
        view.append(this.createGameModeView(null, false, true))
    }

    return view
  }

  /**
   * Find appropriate game mode from array and returns it.
   * If game mode is not null, it will be removed from array.
   */
  function chooseGameModeEsUnitType(gameModes, esUnitType, esUnitTypesFilter) {
    return this.getGameModeByCondition(gameModes,
      @(gameMode) u.max(::game_mode_manager.getRequiredUnitTypes(gameMode).filter(
        @(esUType) isInArray(esUType, esUnitTypesFilter))) == esUnitType)
  }

  function getGameModeByCondition(gameModes, conditionFunc) {
    return u.search(gameModes, conditionFunc)
  }

  function onGameModeSelect(obj) {
    this.markGameModeSeen(obj)
    let gameModeView = u.search(this.filledGameModes, @(gm) gm.isMode && gm?.hasContent && gm.modeId == obj.modeId)
    this.performGameModeSelect(gameModeView.gameMode)
  }

  function performGameModeSelect(gameMode) {
    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    if (gameMode?.diffCode == DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    let event = ::game_mode_manager.getGameModeEvent(gameMode)
    if (event && !this.isCrossPlayEventAvailable(event)) {
      checkAndShowCrossplayWarning(@() ::showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
      return
    }

    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.goBack()

      if ("startFunction" in gameMode)
        gameMode.startFunction()
      else if (gameMode?.displayType?.showInEventsWindow)
        ::gui_start_modal_events({ event = event?.name })
      else
        ::game_mode_manager.setCurrentGameModeById(gameMode.modeId, true)
    })
  }

  function markGameModeSeen(obj) {
    if (!obj?.id || ::game_mode_manager.isSeen(obj.id))
      return

    let widget = getTblValue(obj.id, this.newIconWidgetsByGameModeID)
    if (!widget)
      return

    ::game_mode_manager.markShowingGameModeAsSeen(obj.id)
    widget.setWidgetVisible(false)
  }

  function onGameModeGamepadSelect(obj) {
    let val = obj.getValue()
    if (val < 0 || val >= obj.childrenCount())
      return

    let gmView = this.filledGameModes[val]
    let modeObj = this.scene.findObject(gmView.id)

    this.markGameModeSeen(modeObj)
    this.updateEventDescriptionConsoleButton(gmView.gameMode)
  }

  function onOpenClusterSelect(obj) {
    openClustersMenuWnd(obj)
  }

  function onEventClusterChange(_params) {
    this.updateClusters()
  }

  function updateClusters() {
    clustersModule.updateClusters(this.scene.findObject("cluster_select_button"))
  }

  function onClusterSelectActivate(obj) {
    let value = obj.getValue()
    let childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (checkObj(childObj))
      this.onOpenClusterSelect(childObj)
  }

  function onGameModeActivate(obj) {
    let value = ::get_obj_valid_index(obj)
    if (value < 0)
      return

    this.performGameModeSelect(this.filledGameModes[value].gameMode)
  }

  function onEventDescription(obj) {
    this.openEventDescription(::game_mode_manager.getGameModeById(obj.modeId))
  }

  function onGamepadEventDescription(_obj) {
    let gameModesObject = this.getObj("general_game_modes")
    if (!checkObj(gameModesObject))
      return

    let value = gameModesObject.getValue()
    if (value < 0)
      return

    this.openEventDescription(this.filledGameModes[value].gameMode)
  }

  function openEventDescription(gameMode) {
    let event = ::game_mode_manager.getGameModeEvent(gameMode)
    if (event != null) {
      this.restoreFromModal = true
      ::events.openEventInfo(event)
    }
  }

  function updateEventDescriptionConsoleButton(gameMode) {
    this.showSceneBtn("event_description_console_button", gameMode != null
      && gameMode?.forClan
      && ::show_console_buttons
      && isMultiplayerPrivilegeAvailable.value
    )

    let prefObj = this.showSceneBtn("map_preferences_console_button", this.isShowMapPreferences(gameMode?.getEvent())
      && ::show_console_buttons)

    if (!checkObj(prefObj))
      return

    prefObj.setValue(mapPreferencesParams.getPrefTitle(gameMode?.getEvent()))
    prefObj.modeId = gameMode?.id
  }

  function onEventCurrentGameModeIdChanged(_p) { this.updateContent() }
  function onEventGameModesUpdated(_p) { this.updateContent() }
  function onEventWWLoadOperation(_p) { this.updateContent() }
  function onEventWWStopWorldWar(_p) { this.updateContent() }
  function onEventWWGlobalStatusChanged(_p) { this.updateContent() }
  function onEventCrossPlayOptionChanged(_p) { this.updateContent() }
  function onEventXboxMultiplayerPrivilegeUpdated(_p) { this.updateContent() }

  function updateButtons() {
    ::showBtn("wiki_link", hasFeature("AllowExternalLink") && !::is_vendor_tencent(), this.scene)
  }

  function setGameModesTimer() {
    let timerObj = this.scene.findObject("game_modes_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(this.gameModesWithTimer.len() ? this : null)
  }

  function onTimerUpdate(_obj, _dt) {
    foreach (gameModeId, updateFunc in this.gameModesWithTimer) {
      updateFunc(this.scene, gameModeId)
    }
  }

  function isShowMapPreferences(curEvent) {
    return hasFeature("MapPreferences") && !::is_me_newbie()
      && isMultiplayerPrivilegeAvailable.value
      && mapPreferencesParams.hasPreferences(curEvent)
      && ((curEvent?.maxDislikedMissions ?? 0) > 0 || (curEvent?.maxBannedMissions ?? 0) > 0)
  }

  function onMapPreferences(obj) {
    let curEvent = obj?.modeId != null
      ? ::game_mode_manager.getGameModeById(obj.modeId)?.getEvent()
      : ::game_mode_manager.getCurrentGameMode()?.getEvent()
    ::g_squad_utils.checkSquadUnreadyAndDo(
      Callback(@() mapPreferencesModal.open({ curEvent = curEvent }), this),
      null, this.shouldCheckCrewsReady)
  }
}
