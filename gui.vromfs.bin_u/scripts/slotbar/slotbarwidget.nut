//-file:plus-string
from "%scripts/dagui_natives.nut" import is_player_unit_alive, is_crew_slot_was_ready_at_host, get_auto_refill, get_cur_circuit_name, shop_get_first_win_wp_rate, get_crew_slot_cost, get_player_unit_name, is_first_win_reward_earned, shop_get_first_win_xp_rate, is_respawn_screen
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getObjValidIndex, toPixels } = require("%sqDagui/daguiUtil.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let selectUnitHandler = require("%scripts/slotbar/selectUnitHandler.nut")
let { getWeaponsStatusName, checkUnitWeapons } = require("%scripts/weaponry/weaponryInfo.nut")
let { getNearestSelectableChildIndex } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { getBitStatus } = require("%scripts/unit/unitStatus.nut")
let { getUnitItemStatusText } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRequireUnlockShortText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isCountrySlotbarHasUnits, isUnitUnlockedInSlotbar, isUnitEnabledForSlotbar, initSelectedCrews,
  selectCrew, getSelectedCrews
} = require("%scripts/slotbar/slotbarState.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { setShowUnit, getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getAvailableRespawnBases } = require("guiRespawn")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { getUnlockIdsByCountry } = require("%scripts/unlocks/unlockMarkers.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { startsWith } = require("%sqstd/string.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { isInFlight } = require("gameplayBinding")
let { bit_unit_status, isRequireUnlockForUnit } = require("%scripts/unit/unitInfo.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { selectCountryForCurrentOverrideSlotbar } = require("%scripts/slotbar/slotbarOverride.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { buildUnitSlot, fillUnitSlotTimers, getSlotObjId, getSlotObj, getUnitSlotRankText
} = require("%scripts/slotbar/slotbarView.nut")
let { getUnlockedCountries, isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")

const SLOT_NEST_TAG = "unitItemContainer { {0} }"

function initSlotbarTopBar(slotbarObj, boxesShow) {
  if (!checkObj(slotbarObj))
    return

  showObjById("slotbar_buttons_place", true, slotbarObj)
  let mainObj = showObjById("autorefill-settings", true, slotbarObj)
  if (!checkObj(mainObj))
    return

  let repObj = showObjById("slots-autorepair", boxesShow, mainObj)
  let weapObj = showObjById("slots-autoweapon", boxesShow, mainObj)
  if (!boxesShow)
    return

  if (checkObj(repObj))
    repObj.setValue(get_auto_refill(0))

  if (checkObj(weapObj))
    weapObj.setValue(get_auto_refill(1))
}

gui_handlers.SlotbarWidget <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/slotbar/slotbar.blk"
  ownerWeak = null
  slotbarOninit = false

  //slotbar config
  singleCountry = null //country name to show it alone in slotbar
  crewId = null //crewId to force select. reset after init
  shouldSelectCrewRecruit = false //should select crew recruit slot on create slotbar.
  isCountryChoiceAllowed = true //When false, not allow to change country, but show all countries.
                               //(look like it almost duplicate of singleCountry)
  customCountry = null //country name when not isCountryChoiceAllowed mode.
  showTopPanel = true  //need to show panel with repair checkboxes. ignored in singleCountry or when not isCountryChoiceAllowed modes
  showRepairBox = true  //need to show repair checkboxes
  hasResearchesBtn = false //offset from left border for Researches button
  hasActions = true
  missionRules = null
  showNewSlot = null //bool
  showEmptySlot = null //bool
  emptyText = "#shop/chooseAircraft" //text to show on empty slot
  alwaysShowBorder = false //should show focus border when no showConsoleButtons.value
  checkRespawnBases = false //disable slot when no available respawn bases for unit
  hasExtraInfoBlock = null //bool
  unitForSpecType = null //unit to show crew specializations
  shouldSelectAvailableUnit = null //bool
  needPresetsPanel = null //bool
  countriesToShow = null

  //!!FIX ME: Better to remove parameters group below, and replace them by isUnitEnabled function
  mainMenuSlotbar = false //is slotbar in mainmenu
  roomCreationContext = null //check enbled by roomCreation context
  availableUnits = null //available units table
  customUnitsList = null //custom units table to filter unsuitable units in unit selecting
  customUnitsListName = null //string. Custom list name for unit select option filter
  eventId = null //string. Used to check unit availability
  gameModeName = null //string. Custom mission name for unit select option filter

  toBattle = false //has toBattle button
  haveRespawnCost = false //!!FIX ME: should to take this from mission rules
  haveSpawnDelay = false  //!!FIX ME: should to take this from mission rules
  totalSpawnScore = -1 //to disable slots by spawn score //!!FIX ME: should to take this from mission rules
  sessionWpBalance = 0 //!!FIX ME: should to take this from mission rules

  shouldCheckQueue = null //bool.  should check queue before select unit. !isInFlight by default.
  needActionsWithEmptyCrews = true //allow create crew and choose unit to crew while select empty crews.
  applySlotSelectionOverride = null //full override slot selection instead of selectCrew
  beforeSlotbarSelect = null //function(onContinueCb, onCancelCb) to do before apply slotbar select.
                             //must call one of listed callbacks on finidh.
                             //when onContinueCb will be called, slotbar will aplly unit selection
                             //when onCancelCb will be called, slotbar will return selection to previous state
  afterSlotbarSelect = null //function() will be called after unit selection applied.
  onSlotDblClick = null //function(crew) when not set will open unit modifications window
  onSlotActivate = null //function(crew) when activate chosen crew
  onCountryChanged = null //function()
  onCountryDblClick = null
  beforeFullUpdate = null //function()
  afterFullUpdate = null //function()
  onSlotBattleBtn = null //function()
  getLockedCountryData = null //function()


  //******************************* self slotbar params ***********************************//
  isSceneLoaded = false
  loadedCountries = null //loaded countries versions
  lastUpdatedVersion = null // version IDX which has already updated

  curSlotCountryId = -1
  curSlotIdInCountry = -1
  slotbarActions = null
  isShaded = false

  ignoreCheckSlotbar = false
  skipCheckCountrySelect = false
  skipCheckAirSelect = false

  headerObj = null
  crewsObj = null
  selectedCrewData = null
  customViewCountryData = null
  slotbarBehavior = null
  needFullSlotBlock = false
  showAlwaysFullSlotbar = false
  needCheckUnitUnlock = false
  slotbarHintText = ""

  static function create(params) {
    let nest = params?.scene
    if (!checkObj(nest))
      return null

    if (params?.shouldAppendToObject ?? true) { //we append to nav-bar by default
      let data = "slotbarDiv { id:t='nav-slotbar' }"
      nest.getScene().appendWithBlk(nest, data)
      params.scene = nest.findObject("nav-slotbar")
    }

    return handlersManager.loadHandler(gui_handlers.SlotbarWidget, params)
  }

  function destroy() {
    if (checkObj(this.scene))
      this.guiScene.replaceContentFromText(this.scene, "", 0, null)
    this.scene = null
  }

  function initScreen() {
    this.headerObj = this.scene.findObject("header_countries")
    this.crewsObj =  this.scene.findObject("countries_crews")

    this.loadedCountries = {}
    this.isSceneLoaded = true
    this.refreshAll()

    if (this.hasResearchesBtn) {
      let slotbarHeaderNestObj = this.scene.findObject("slotbar_buttons_place")
      if (checkObj(slotbarHeaderNestObj))
        slotbarHeaderNestObj["offset"] = "yes"
    }
  }

  function setParams(params) {
    base.setParams(params)
    if (this.ownerWeak)
      this.ownerWeak = this.ownerWeak.weakref()
    this.validateParams()
    if (this.isSceneLoaded) {
      this.loadedCountries.clear() //params can change visual style and visibility of crews
      this.refreshAll()
    }
  }

  function validateParams() {
    this.showNewSlot = this.showNewSlot ?? !this.singleCountry
    this.showEmptySlot = this.showEmptySlot ?? !this.singleCountry
    this.hasExtraInfoBlock = this.hasExtraInfoBlock ?? !this.singleCountry
    this.shouldSelectAvailableUnit = this.shouldSelectAvailableUnit ?? isInFlight()
    this.needPresetsPanel = this.needPresetsPanel ?? (!this.singleCountry && this.isCountryChoiceAllowed)
    this.shouldCheckQueue = this.shouldCheckQueue ?? !isInFlight()
    this.onSlotDblClick = this.onSlotDblClick ?? this.getDefaultDblClickFunc()
    this.onSlotActivate = this.onSlotActivate ?? this.defaultOnSlotActivateFunc

    //update callbacks
    foreach (funcName in ["beforeSlotbarSelect", "afterSlotbarSelect", "onSlotDblClick", "onCountryChanged",
        "beforeFullUpdate", "afterFullUpdate", "onSlotBattleBtn", "applySlotSelectionOverride"])
      if (this[funcName])
        this[funcName] = callback.make(this[funcName], this.ownerWeak)
  }

  function refreshAll() {
    this.fillCountries()

    if (!this.singleCountry)
      setShowUnit(this.getCurSlotUnit(), this.getHangarFallbackUnitParams())

    if (this.crewId != null)
      this.crewId = null
    if (this.ownerWeak) //!!FIX ME: Better to presets list self catch canChangeCrewUnits
      this.ownerWeak.setSlotbarPresetsListAvailable(this.needPresetsPanel && ::SessionLobby.canChangeCrewUnits())
  }

  function getForcedCountry() { //return null if you have countries choice
    if (this.singleCountry)
      return this.singleCountry
    if (!::SessionLobby.canChangeCountry())
      return profileCountrySq.value
    if (!this.isCountryChoiceAllowed)
      return this.customCountry || profileCountrySq.value
    return null
  }

  function addCrewData(list, params) {
    let crew = params?.crew
    let data = {
      crew = crew,
      unit = null,
      isUnlocked = true,
      status = bit_unit_status.owned
      idInCountry = crew?.idInCountry ?? -1 //for recruit slots, but correct for all
      idCountry = crew?.idCountry ?? -1         //for recruit slots, but correct for all
    }.__update(params)

    data.crewIdVisible <- data?.crewIdVisible ?? list.len()

    let canSelectEmptyCrew = this.shouldSelectCrewRecruit
      || !this.needActionsWithEmptyCrews
      || (crew?.country != null && !isCountrySlotbarHasUnits(crew.country) && data.idInCountry == 0)
    data.isSelectable <- data?.isSelectable
      ?? ((data.isUnlocked || !this.shouldSelectAvailableUnit) && (canSelectEmptyCrew || data.unit != null))
    let isControlledUnit = !is_respawn_screen()
      && is_player_unit_alive()
      && get_player_unit_name() == data.unit?.name
    if (this.haveRespawnCost
        && data.isSelectable
        && data.unit
        && this.totalSpawnScore >= 0
        && (this.totalSpawnScore < data.unit.getSpawnScore() || this.totalSpawnScore < data.unit.getMinimumSpawnScore())
        && !isControlledUnit)
      data.isSelectable = false

    list.append(data)
    return data
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null) {
    let res = []
    let country = this.getForcedCountry()
    let needNewSlot = !::g_crews_list.isCrewListOverrided && this.showNewSlot
    let needShowLockedSlots = this.missionRules == null || this.missionRules.needShowLockedSlots
    let needEmptySlot = !::g_crews_list.isCrewListOverrided && needShowLockedSlots && this.showEmptySlot

    let crewsListFull = ::g_crews_list.get()
    for (local c = 0; c < crewsListFull.len(); c++) {
      if (onlyForCountryIdx != null && onlyForCountryIdx != c)
        continue

      let visibleCountries = this.countriesToShow ?? getShopVisibleCountries()
      let listCountry = crewsListFull[c].country
      if ((this.singleCountry != null && this.singleCountry != listCountry)
        || visibleCountries.indexof(listCountry) == null
        || (!needEmptySlot && !isCountrySlotbarHasUnits(listCountry)))
        continue

      let countryData = {
        country = listCountry
        id = c
        isEnabled = !country || country == listCountry
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      let crewsList = crewsListFull[c].crews
      foreach (crew in crewsList) {
        let unit = this.getCrewUnit(crew)

        if (!unit && !needEmptySlot)
          continue

        let unitName = unit?.name || ""
        let isUnitEnabledByRandomGroups = !this.missionRules || this.missionRules.isUnitEnabledByRandomGroups(unitName)
        let isUnlocked = (!this.needCheckUnitUnlock || !isRequireUnlockForUnit(unit))
          && isUnitUnlockedInSlotbar(unit, crew, country, this.missionRules, true)
        local status = bit_unit_status.empty
        let isUnitForcedVisible = this.missionRules && this.missionRules.isUnitForcedVisible(unitName)
        let isUnitForcedHiden = this.missionRules && this.missionRules.isUnitForcedHiden(unitName)
        if (unit) {
          status = getBitStatus(unit)
          if (!isUnlocked)
            status = bit_unit_status.locked
          else if (!is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, false))
            status = bit_unit_status.broken
          else {
            local disabled = !isUnitEnabledForSlotbar(unit, this)
            if (this.checkRespawnBases)
              disabled = disabled || !getAvailableRespawnBases(unit.tags).len()
            if (disabled)
              status = bit_unit_status.disabled
          }
        }

        let isAllowedByLockedSlots = isUnitForcedVisible || needShowLockedSlots
          || status == bit_unit_status.owned || status == bit_unit_status.empty
        if (unit && (!isAllowedByLockedSlots || !isUnitEnabledByRandomGroups || isUnitForcedHiden))
          continue

        this.addCrewData(countryData.crews,
          { crew = crew, unit = unit, isUnlocked = isUnlocked, status = status })
      }

      if (!needNewSlot)
        continue

      let slotCostTbl = get_crew_slot_cost(listCountry)
      if (!slotCostTbl || (slotCostTbl.costGold > 0 && !hasFeature("SpendGold")))
        continue

      this.addCrewData(countryData.crews,
        { idInCountry = crewsList.len()
          idCountry = c
          cost = Cost(slotCostTbl.cost, slotCostTbl.costGold)
        })
    }
    return res
  }

  //calculate selected crew and country by slotbar params
  function calcSelectedCrewData(crewsConfig) {
    let forcedCountry = this.getForcedCountry()
    local unitShopCountry = forcedCountry || profileCountrySq.value
    local curUnit = getShowedUnit()
    local curCrewId = this.crewId

    if (!forcedCountry && !curCrewId) {
      let unlockedCountries = getUnlockedCountries()
      if (!isCountryAvailable(unitShopCountry) && unlockedCountries.len() > 0)
        unitShopCountry = unlockedCountries[0]
      if (curUnit && curUnit.shopCountry != unitShopCountry)
        curUnit = null
    }
    else if (forcedCountry && this.curSlotIdInCountry >= 0) {
      let curCrew = getCrew(this.curSlotCountryId, this.curSlotIdInCountry)
      if (curCrew)
        curCrewId = curCrew.id
    }

    if (curCrewId || this.shouldSelectCrewRecruit)
      curUnit = null

    local isFoundCurUnit = false
    local selCrewData = null
    foreach (countryData in crewsConfig) {
      if (!countryData.isEnabled)
        continue

      //when current crew not available in this mission, first available crew will be selected.
      local firstAvailableCrewData = null
      let selCrewidInCountry = getSelectedCrews(countryData.id)
      foreach (crewData in countryData.crews) {
        let crew = crewData.crew
        let unit = crewData.unit
        let isSelectable = crewData.isSelectable
        if ((crew?.id != null && curCrewId == crew.id)
          || (unit && unit == curUnit)
          || (!crew && this.shouldSelectCrewRecruit)) {
          selCrewData = crewData
          isFoundCurUnit = true
          if (isSelectable)
            break
        }

        if (isSelectable
          && (!firstAvailableCrewData || selCrewidInCountry == crew?.idInCountry))
          firstAvailableCrewData = crewData
      }

      if (isFoundCurUnit && selCrewData.isSelectable)
        break

      if (firstAvailableCrewData
          && (!selCrewData || !selCrewData.isSelectable || unitShopCountry == countryData.country))
        selCrewData = firstAvailableCrewData

      if (!selCrewData && countryData.crews.len())
        selCrewData = countryData.crews[0] //select not selectable when nothing found
    }

    return selCrewData
  }

  //get crew data selected in country (getSelectedCrews(curSlotCountryId))
  function getSelectedCrewDataInCountry(countryData) {
    local selCrewData = null
    let selCrewIdInCountry = getSelectedCrews(countryData.id)
    foreach (crewData in countryData.crews) {
      if (crewData.idInCountry == selCrewIdInCountry) {
        selCrewData = crewData
        break
      }

      if (!selCrewData || (crewData.isSelectable && !selCrewData.isSelectable))
        selCrewData = crewData
    }
    return selCrewData
  }

  function fillCountries() {
    if (!::g_login.isLoggedIn())
      return
    if (this.slotbarOninit) {
      script_net_assert_once("slotbar recursion", "init_slotbar: recursive call found")
      return
    }

    if (!::g_crews_list.get().len()) {
      if (::g_login.isLoggedIn() && (::isProductionCircuit() || get_cur_circuit_name() == "nightly"))
        scene_msg_box("no_connection", null, loc("char/no_connection"), [["ok", startLogout ]], "ok")
      return
    }

    this.slotbarOninit = true
    initSelectedCrews()
    ::update_crew_skills_available()
    let crewsConfig = this.gatherVisibleCrewsConfig()
    this.selectedCrewData = this.calcSelectedCrewData(crewsConfig)

    let isFullSlotbar = crewsConfig.len() > 1 || this.showAlwaysFullSlotbar
    let hasCountryTopBar = isFullSlotbar && this.showTopPanel && !this.singleCountry
    if (hasCountryTopBar)
      initSlotbarTopBar(this.scene, this.showRepairBox) //show autorefill checkboxes

    this.crewsObj.hasHeader = !hasCountryTopBar ? "yes" : "no"
    this.crewsObj.hasBackground = isFullSlotbar ? "no" : "yes"
    let hObj = this.scene.findObject("slotbar_background")
    hObj.show(isFullSlotbar)
    hObj.hasPresetsPanel = this.needPresetsPanel ? "yes" : "no"
    if (showConsoleButtons.value)
      this.updateConsoleButtonsVisible(hasCountryTopBar)

    let countriesView = {
      hasNotificationIcon = this.hasResearchesBtn
      countries = []
    }
    local selCountryIdx = 0
    let ediff = getShopDiffCode()
    foreach (idx, countryData in crewsConfig) {
      let country = countryData.country
      if (countryData.id == this.selectedCrewData?.idCountry)
        selCountryIdx = idx

      local bonusData = null
      if (!is_first_win_reward_earned(country, ::INVALID_USER_ID))
        bonusData = this.getCountryBonusData(country)

      let cEnabled = countryData.isEnabled
      let cUnlocked = isCountryAvailable(country)
      let tooltipText = !cUnlocked ? loc("mainmenu/countryLocked/tooltip")
        : loc(country)
      countriesView.countries.append({
        countryIdx = countryData.id
        country = this.customViewCountryData?[country].locId ?? country
        tooltipText = tooltipText
        countryIcon = getCountryIcon(
          this.customViewCountryData?[country].icon ?? country, false, !cUnlocked || !cEnabled)
        bonusData = bonusData
        isEnabled = cEnabled && cUnlocked
        seenIconCfg = bhvUnseen.makeConfigStr(seenList.id,
          getUnlockIdsByCountry(country, ediff))
      })
    }

    let countriesNestObj = this.scene.findObject("header_countries")
    let countriesObjsCount = countriesNestObj.childrenCount()
    local needUpdateCountriesMarkup = countriesObjsCount != countriesView.countries.len()
    if (!needUpdateCountriesMarkup)
      for (local i = 0; i < countriesObjsCount; i++) {
         needUpdateCountriesMarkup = countriesView.countries.findindex(
           function(v) {
             let countryObj = countriesNestObj.getChild(i)
             return v.country == countryObj?.countryId && v.isEnabled == countryObj.isEnabled()
           }) == null
         if (needUpdateCountriesMarkup)
           break
      }
    if (needUpdateCountriesMarkup) {
      let countriesData = handyman.renderCached("%gui/slotbar/slotbarCountryItem.tpl", countriesView)
      this.guiScene.replaceContentFromText(countriesNestObj, countriesData, countriesData.len(), this)
    }

    let needUpdateCountryContent = countriesNestObj.getValue() == selCountryIdx
    countriesNestObj.setValue(selCountryIdx)
    if (needUpdateCountryContent)
      this.onHeaderCountry(countriesNestObj)

    if (this.selectedCrewData) {
      let selItem = getSlotObj(this.crewsObj, this.selectedCrewData.idCountry, this.selectedCrewData.idInCountry)
      if (selItem)
        this.guiScene.performDelayed(this, function() {
          if (checkObj(selItem) && selItem.isVisible())
            selItem.scrollToView()
        })
    }

    this.slotbarOninit = false
    this.guiScene.applyPendingChanges(false)

    let countriesNestMaxWidth = toPixels(this.guiScene, "1@slotbarCountriesMaxWidth")
    let countriesNestWithBtnsObj = this.scene.findObject("header_countries_nest")
    if (countriesNestWithBtnsObj.getSize()[0] > countriesNestMaxWidth)
      countriesNestObj.isShort = "yes"

    let needEvent = this.selectedCrewData
      && ((this.curSlotCountryId >= 0 && this.curSlotCountryId != this.selectedCrewData.idCountry)
        || (this.curSlotIdInCountry >= 0 && this.curSlotIdInCountry != this.selectedCrewData.idInCountry))
    if (needEvent) {
      let cObj = this.scene.findObject("airs_table_" + this.selectedCrewData.idCountry)
      if (checkObj(cObj)) {
        this.skipCheckAirSelect = true
        this.onSlotbarSelect(cObj)
      }
    }
    else {
      this.curSlotCountryId   = this.selectedCrewData?.idCountry ?? -1
      this.curSlotIdInCountry = this.selectedCrewData?.idInCountry ?? -1
      selectCrew(this.curSlotCountryId, this.curSlotIdInCountry)
    }
  }

  getCountryBonusData = @(country) ::getBonus(
    shop_get_first_win_xp_rate(country),
    shop_get_first_win_wp_rate(country), "item")

  function fillCountryContent(countryData, tblObj) {
    this.updateSlotbarHint()
    if (this.loadedCountries?[countryData.id] == ::g_crews_list.version
      || !checkObj(tblObj))
      return

    this.loadedCountries[countryData.id] <- ::g_crews_list.version
    this.lastUpdatedVersion = ::g_crews_list.version

    let selCrewData = this.selectedCrewData?.idCountry == countryData.id
      ? this.selectedCrewData
      : this.getSelectedCrewDataInCountry(countryData)

    this.updateSlotRowView(countryData, tblObj)
    if (selCrewData)
      tblObj.setValue(selCrewData.crewIdVisible)

    foreach (crewData in countryData.crews)
      if (crewData.unit) {
        let id = getSlotObjId(countryData.id, crewData.idInCountry)
        fillUnitSlotTimers(tblObj.findObject(id), crewData.unit)
        ::showAirExpWpBonus(tblObj.findObject($"{id}-bonus"), crewData.unit.name)
      }
  }

  function checkUpdateCountryInScene(countryIdx) {
    if (this.loadedCountries?[countryIdx] == ::g_crews_list.version)
      return

    let countryData = this.gatherVisibleCrewsConfig(countryIdx)?[0]
    if (!countryData)
      return

    this.fillCountryContent(countryData, this.scene.findObject("airs_table_" + countryData.id))
  }

  function getCurSlotUnit() {
    return ::g_crew.getCrewUnit(getCrew(this.curSlotCountryId, this.curSlotIdInCountry))
  }

  function getCurCrew() { //will return null when selected recruitCrew
    return getCrew(this.curSlotCountryId, this.curSlotIdInCountry)
  }

  function getCurCountry() {
    return ::g_crews_list.get()?[this.curSlotCountryId]?.country ?? ""
  }

  function getCurrentEdiff() {
    if (u.isFunction(this.ownerWeak?.getCurrentEdiff))
      return this.ownerWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function getSlotbarActions() {
    return this.slotbarActions ?? this.ownerWeak?.getSlotbarActions?()
  }

  function getCurrentAirsTable() {
    return this.scene.findObject("airs_table_" + this.curSlotCountryId)
  }

  function getCurrentCrewSlot() {
    return getSlotObj(this.scene, this.curSlotCountryId, this.curSlotIdInCountry)
  }

  function getHangarFallbackUnitParams() {
    return {
      country = this.getCurCountry()
      slotbarUnits = (::g_crews_list.get()?[this.curSlotCountryId].crews ?? [])
        .map(@(crew) ::g_crew.getCrewUnit(crew))
        .filter(@(unit) unit != null)
    }
  }

  function getSlotIdByObjId(slotObjId, countryId) {
    let prefix = "td_slot_" + countryId + "_"
    if (!startsWith(slotObjId, prefix))
      return -1
    return to_integer_safe(slotObjId.slice(prefix.len()), -1)
  }

  function getSelSlotDataByObj(obj) {
    let res = {
      isValid = false
      countryId = -1
      crewIdInCountry = -1
    }

    let countryIdStr = ::getObjIdByPrefix(obj, "airs_table_")
    if (!countryIdStr)
      return res
    res.countryId = countryIdStr.tointeger()

    let curValue = getObjValidIndex(obj)
    if (curValue < 0)
      return res

    let curSlotId = obj.getChild(curValue).id
    res.crewIdInCountry = this.getSlotIdByObjId(curSlotId, res.countryId)
    res.isValid = res.crewIdInCountry >= 0
    return res
  }

  function onSlotbarSelect(obj) {
    if (!checkObj(obj))
      return

    if (this.slotbarOninit || this.skipCheckAirSelect || !this.shouldCheckQueue) {
      this.onSlotbarSelectImpl(obj)
      this.skipCheckAirSelect = false
    }
    else
      this.checkedAirChange(
         function() {
          if (checkObj(obj))
            this.onSlotbarSelectImpl(obj)
        },
         function() {
          if (checkObj(obj)) {
            this.skipCheckAirSelect = true
            this.selectTblAircraft(obj, getSelectedCrews(this.curSlotCountryId))
          }
        }
      )
  }

  function onSlotbarSelectImpl(obj) {
    if (!checkObj(obj))
      return

    let selSlot = this.getSelSlotDataByObj(obj)
    if (!selSlot.isValid)
      return
    if (this.curSlotCountryId == selSlot.countryId
        && this.curSlotIdInCountry == selSlot.crewIdInCountry)
      return

    if (this.beforeSlotbarSelect) {
      this.ignoreCheckSlotbar = true
      this.beforeSlotbarSelect(
        Callback(function() {
          this.ignoreCheckSlotbar = false
          if (checkObj(obj))
            this.applySlotSelection(obj, selSlot)
        }, this),
        Callback(function() {
          this.ignoreCheckSlotbar = false
          if (this.curSlotCountryId != selSlot.countryId)
            this.setCountry(::g_crews_list.get()?[this.curSlotCountryId]?.country)
          else if (checkObj(obj))
            this.selectTblAircraft(obj, this.curSlotIdInCountry)
        }, this),
        selSlot
      )
    }
    else
      this.applySlotSelection(obj, selSlot)
  }

  function applySlotSelectionDefault(_prevSlot, restorePrevSelection) {
    let crew = getCrew(this.curSlotCountryId, this.curSlotIdInCountry)
    if (crew) {
      let unit = this.getCrewUnit(crew)
      if (unit != null || (!isCountrySlotbarHasUnits(crew.country) && this.curSlotIdInCountry == 0))
        this.setCrewUnit(unit)
      if (!unit && this.needActionsWithEmptyCrews)
        this.onSlotChangeAircraft()
      return
    }

    if (!this.needActionsWithEmptyCrews || (this.curSlotCountryId not in ::g_crews_list.get()))
      return

    let country = ::g_crews_list.get()[this.curSlotCountryId].country

    let rawCost = get_crew_slot_cost(country)
    let cost = rawCost ? Cost(rawCost.cost, rawCost.costGold) : Cost()
    if (!checkBalanceMsgBox(cost)) {
      restorePrevSelection()
      return
    }

    if (cost <= ::zero_money) {
      this.purchaseNewSlot(country)
      return
    }

    let msgText = warningIfGold(
      format(loc("shop/needMoneyQuestion_purchaseCrew"),
        cost.getTextAccordingToBalance()),
      cost)
    this.ignoreCheckSlotbar = true
    this.msgBox("need_money", msgText,
      [["ok",
        function() {
          this.ignoreCheckSlotbar = false
          this.purchaseNewSlot(country)
        }
       ],
       ["cancel", restorePrevSelection ]
      ], "ok")
  }

  function applySlotSelection(obj, selSlot) {
    let prevSlot = { countryId = this.curSlotCountryId, crewIdInCountry = this.curSlotIdInCountry }
    this.curSlotCountryId = selSlot.countryId
    this.curSlotIdInCountry = selSlot.crewIdInCountry

    if (!this.slotbarOninit)
      (this.applySlotSelectionOverride ?? this.applySlotSelectionDefault)(prevSlot,
        Callback(function() {
          if (this.curSlotCountryId != selSlot.countryId)
            return
          this.ignoreCheckSlotbar = false
          this.selectTblAircraft(obj, getSelectedCrews(this.curSlotCountryId))
        }, this))
    this.afterSlotbarSelect?()
  }

  /**
   * Selects crew in slotbar with specified id
   * as if player clicked slot himself.
   */
  function selectCrew(crewIdInCountry) {
    let objId = "airs_table_" + this.curSlotCountryId
    let obj = this.scene.findObject(objId)
    if (checkObj(obj))
      this.selectTblAircraft(obj, crewIdInCountry)
  }

  function selectTblAircraft(tblObj, slotIdInCountry = 0) {
    if (!checkObj(tblObj) || slotIdInCountry < 0)
      return
    let slotIdx = this.getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
    if (slotIdx < 0)
      return
    tblObj.setValue(slotIdx)
  }

  function getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry) {
    if (!tblObj.childrenCount())
      return -1
    if (tblObj?.id != "airs_table_" + this.curSlotCountryId) {
      let tblObjId = tblObj?.id         // warning disable: -declared-never-used
      let countryId = this.curSlotCountryId  // warning disable: -declared-never-used
      script_net_assert_once("bad slot country id", "Error: Try to select crew from wrong country")
      return -1
    }
    let prefix = "td_slot_" + this.curSlotCountryId + "_"
    for (local i = 0; i < tblObj.childrenCount(); i++) {
      let id = ::getObjIdByPrefix(tblObj.getChild(i), prefix)
      if (!id) {
        let objId = tblObj.getChild(i).id // warning disable: -declared-never-used
        script_net_assert_once("bad slot id", "Error: Bad slotbar slot id")
        continue
      }

      if (to_integer_safe(id) == slotIdInCountry)
        return i
    }

    return -1
  }

  function onSlotbarDblClick() {
    if (!this.isValid())
      return
    let cellObj = this.scene.findObject($"td_slot_{this.curSlotCountryId}_{this.curSlotIdInCountry}")
    if (!cellObj?.isValid() || !cellObj.isHovered())
      return
    this.onSlotDblClick(this.getCurCrew())
  }

  function checkSelectCountryByIdx(obj) {
    let idx = obj.getValue()
    let countryIdx = to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(idx), "header_country"), this.curSlotCountryId)
    if (this.curSlotCountryId >= 0 && this.curSlotCountryId != countryIdx && countryIdx in ::g_crews_list.get()
        && !isCountryAvailable(::g_crews_list.get()[countryIdx].country) && getUnlockedCountries().len()) {
      this.msgBox("notAvailableCountry", loc("mainmenu/countryLocked/tooltip"),
             [["ok",  function() {
               if (checkObj(obj))
                 obj.setValue(this.curSlotCountryId)
             } ]], "ok")
      return false
    }
    return true
  }

  function checkCreateCrewsNest(countryData) {
    let countriesCount = this.crewsObj.childrenCount()
    let animBlockId = "crews_anim_" + countryData.idx
    for (local i = 0; i < countriesCount; i++) {
      let animObj = this.crewsObj.getChild(i)
      animObj.animation = animObj?.id == animBlockId ? "show" : "hide"

      if (animObj?.id != animBlockId && animObj?["_transp-timer"] == null)
        animObj["_transp-timer"] = "0"
    }

    let animBlockObj = this.crewsObj.findObject(animBlockId)
    if (checkObj(animBlockObj))
      return

    let country = countryData.country
    let blk = handyman.renderCached("%gui/slotbar/slotbarItem.tpl", {
      countryIdx = countryData.idx
      needSkipAnim = countriesCount == 0
      alwaysShowBorder = this.alwaysShowBorder
      countryImage = getCountryIcon(this.customViewCountryData?[country].icon ?? country, false)
      slotbarBehavior = this.slotbarBehavior
    })
    this.guiScene.appendWithBlk(this.crewsObj, blk, this)
  }

  function onHeaderCountry(obj) {
    let countryData = this.getCountryDataByObject(obj)
    if (this.slotbarOninit || this.skipCheckCountrySelect) {
      this.onSlotbarCountryImpl(countryData)
      this.skipCheckCountrySelect = false
      return
    }

    let lockedCountryData = this.getLockedCountryData?()
    if (lockedCountryData != null
      && !isInArray(countryData.country, lockedCountryData.availableCountries)) {
      this.setCountry(profileCountrySq.value)
      showInfoMsgBox(lockedCountryData.reasonText)
    }
    else {
      this.switchSlotbarCountry(this.headerObj, countryData)
    }
  }

  function onCountriesListDblClick() {
    if (this.onCountryDblClick)
      this.onCountryDblClick()
  }

  function switchSlotbarCountry(obj, countryData) {
    if (!this.shouldCheckQueue) {
      if (this.checkSelectCountryByIdx(obj)) {
        this.onSlotbarCountryImpl(countryData)
        ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
      }
    }
    else {
      if (!this.checkSelectCountryByIdx(obj))
        return

      this.checkedCrewAirChange(
        function() {
          if (checkObj(obj)) {
            this.onSlotbarCountryImpl(countryData)
            ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
          }
        },
        function() {
          if (checkObj(obj))
            this.setCountry(profileCountrySq.value)
        }
      )
    }
  }

  function setCountry(country) {
    foreach (idx, c in ::g_crews_list.get())
      if (c.country == country) {
        let hObj = this.scene.findObject("header_countries")
        if (!checkObj(hObj) || hObj.getValue() == idx)
          break

        this.skipCheckCountrySelect = true
        this.skipCheckAirSelect = true
        hObj.setValue(idx)
        break
      }
  }

  function getCountryDataByObject(obj) {
    if (!checkObj(obj))
      return null

    let curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return null

    let countryIdx = to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(curValue), "header_country"), this.curSlotCountryId)
    let country = ::g_crews_list.get()[countryIdx].country

    return {
      idx = countryIdx
      country = country
    }
  }

  function onSlotbarCountryImpl(countryData) {
    if (!countryData)
      return

    this.checkCreateCrewsNest(countryData)
    this.checkUpdateCountryInScene(countryData.idx)

    if (!this.singleCountry) {
      if (!this.checkSelectCountryByIdx(this.headerObj))
        return

      switchProfileCountry(countryData.country)
      if (::g_crews_list.isCrewListOverrided && !this.slotbarOninit && !this.skipCheckCountrySelect)
        selectCountryForCurrentOverrideSlotbar(countryData.country)
      this.onSlotbarSelect(this.crewsObj.findObject("airs_table_" + countryData.idx))
    }
    else
      this.onSlotbarSelect(this.crewsObj.findObject("airs_table_" + countryData.idx))

    this.onSlotbarCountryChanged()
  }

  function onSlotbarCountryChanged() {
    if (this.ownerWeak?.presetsListWeak)
      this.ownerWeak.presetsListWeak.update()
    if (this.onCountryChanged)
      this.onCountryChanged()
  }

  function prevCountry(_obj) { this.switchCountry(-1) }

  function nextCountry(_obj) { this.switchCountry(1) }

  function switchCountry(way) {
    if (this.singleCountry)
      return

    let hObj = this.scene.findObject("header_countries")
    if (hObj.childrenCount() <= 1)
      return

    let curValue = hObj.getValue()
    let value = getNearestSelectableChildIndex(hObj, curValue, way)
    if (value != curValue)
      hObj.setValue(value)
  }

  function onSlotChangeAircraft() {
    let crew = this.getCurCrew()
    if (!crew)
      return

    let slotbar = this
    this.ignoreCheckSlotbar = true
    this.checkedCrewAirChange(function() {
        this.ignoreCheckSlotbar = false
        selectUnitHandler.open(crew, slotbar)
      },
      function() {
        this.ignoreCheckSlotbar = false
        this.checkSlotbar()
      }
    )
  }

  function shade(shouldShade) {
    if (this.isShaded == shouldShade)
      return

    this.isShaded = shouldShade
    let shadeObj = this.scene.findObject("slotbar_shade")
    if (checkObj(shadeObj))
      shadeObj.animation = this.isShaded ? "show" : "hide"
    if (showConsoleButtons.value)
      this.updateConsoleButtonsVisible(!this.isShaded)
  }

  function updateConsoleButtonsVisible(isVisible) {
    this.showSceneBtn("prev_country_btn", isVisible)
    this.showSceneBtn("next_country_btn", isVisible)
  }

  function forceUpdate() {
    this.updateSlotbarImpl()
  }

  function fullUpdate() {
    this.doWhenActiveOnce("updateSlotbarImpl")
  }

  function updateSlotbarImpl() {
    if (this.ignoreCheckSlotbar)
      return

    this.loadedCountries.clear()
    if (this.beforeFullUpdate)
      this.beforeFullUpdate()

    this.curSlotCountryId = -1
    this.curSlotIdInCountry = -1

    this.refreshAll()
    if (this.afterFullUpdate)
      this.afterFullUpdate()
  }

  function checkSlotbar() {
    if (this.ignoreCheckSlotbar || !isInMenu())
      return

    let curCountry = profileCountrySq.value

    if (!(this.curSlotCountryId in ::g_crews_list.get())
        || ::g_crews_list.get()[this.curSlotCountryId].country != curCountry
        || this.curSlotIdInCountry != getSelectedCrews(this.curSlotCountryId)
        || (this.getCurSlotUnit() == null && isCountrySlotbarHasUnits(curCountry)))
      this.updateSlotbarImpl()
    else if (this.selectedCrewData && this.selectedCrewData?.unit != getShowedUnit())
      this.refreshAll()
  }

  function onSceneActivate(show) {
    base.onSceneActivate(show)
    if (this.checkActiveForDelayedAction())
      this.checkSlotbar()
  }

  function onEventModalWndDestroy(p) {
    base.onEventModalWndDestroy(p)
    if (this.checkActiveForDelayedAction())
      this.checkSlotbar()
  }

  function purchaseNewSlot(country) {
    this.ignoreCheckSlotbar = true

    let onTaskSuccess = Callback(function() {
      this.ignoreCheckSlotbar = false
      this.onSlotChangeAircraft()
    }, this)

    let onTaskFail = Callback(function(_result) { this.ignoreCheckSlotbar = false }, this)

    if (!::g_crew.purchaseNewSlot(country, onTaskSuccess, onTaskFail))
      this.ignoreCheckSlotbar = false
  }

  //return GuiBox of visible slotbar units
  function getBoxOfUnits() {
    let obj = this.scene.findObject("airs_table_" + this.curSlotCountryId)
    if (!checkObj(obj))
      return null

    let box = ::GuiBox().setFromDaguiObj(obj)
    let pBox = ::GuiBox().setFromDaguiObj(obj.getParent())
    if (box.c2[0] > pBox.c2[0])
      box.c2[0] = pBox.c2[0] + pBox.c1[0] - box.c1[0]
    return box
  }

  //return GuiBox of visible slotbar countries
  function getBoxOfCountries() {
    let headerCountriesObj = this.scene.findObject("header_countries")
    if (!checkObj(headerCountriesObj))
      return null

    return ::GuiBox().setFromDaguiObj(headerCountriesObj)
  }

  function getSlotsData(unitId = null, slotCrewId = -1, withEmptySlots = false) {
    let unitSlots = []
    foreach (countryId, countryData in ::g_crews_list.get())
      if (!this.singleCountry || countryData.country == this.singleCountry)
        foreach (idInCountry, crew in countryData.crews) {
          if (slotCrewId != -1 && slotCrewId != (crew?.id ?? -1))
            continue
          let unit = this.getCrewUnit(crew)
          if (unitId && unit && unitId != unit.name)
            continue
          let obj = getSlotObj(this.scene, countryId, idInCountry)
          if (obj && (unit || withEmptySlots))
            unitSlots.append({
              unit      = unit
              crew      = crew
              countryId = countryId
              obj       = obj
            })
        }

    return unitSlots
  }

  function getCrewUnit(crew) {
    return ::g_crew.getCrewUnit(crew)
  }

  function updateDifficulty(unitSlots = null) {
    unitSlots = unitSlots || this.getSlotsData()

    let showBR = hasFeature("SlotbarShowBattleRating")
    let curEdiff = this.getCurrentEdiff()

    foreach (slot in unitSlots) {
      let obj = slot.obj.findObject("rank_text")
      if (checkObj(obj)) {
        local unitRankText = getUnitSlotRankText(slot.unit, slot.crew, showBR, curEdiff)
        obj.setValue(unitRankText)
      }
    }
  }

  function updateCrews(unitSlots = null) {
    if (::g_crews_list.isCrewListOverrided)
      return

    unitSlots = unitSlots || this.getSlotsData()

    foreach (slot in unitSlots) {
      slot.obj["crewStatus"] = ::get_crew_status(slot.crew, slot.unit)

      local obj = slot.obj.findObject("crew_level")
      if (checkObj(obj)) {
        let crewLevelText = slot.unit
          ? ::g_crew.getCrewLevel(slot.crew, slot.unit, slot.unit.getCrewUnitType()).tointeger().tostring()
          : ""
        obj.setValue(crewLevelText)
      }

      obj = slot.obj.findObject("crew_spec")
      if (checkObj(obj)) {
        let crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(slot.crew, slot.unit).trainedIcon
        obj["background-image"] = crewSpecIcon
      }
    }
  }

  function onSlotBattle(_obj) {
    if (this.onSlotBattleBtn)
      this.onSlotBattleBtn()
  }

  function onEventCrewsListChanged(_p) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid() || this.lastUpdatedVersion == ::g_crews_list.version)
        return

      this.fullUpdate()
    })
  }

  function onEventCrewSkillsChanged(params) {
    let crew = getTblValue("crew", params)
    if (crew)
      this.updateCrews(this.getSlotsData(null, crew.id))
  }

  function onEventQualificationIncreased(params) {
    let unit = getTblValue("unit", params)
    if (unit)
      this.updateCrews(this.getSlotsData(unit.name))
  }

  function onEventAutorefillChanged(params) {
    if (!("id" in params) || !("value" in params))
      return

    let obj = this.scene.findObject(params.id)
    if (obj && obj.getValue() != params.value)
      obj.setValue(params.value)
  }

  function updateSlotRowView(countryData, tblObj) {
    if (!countryData)
      return

    let slotsData = []
    foreach (crewData in countryData.crews) {
      let id = getSlotObjId(countryData.id, crewData.idInCountry)
      let crew = crewData.crew
      if (!crew) {
        let unitItem = buildUnitSlot(
          id,
          null,
          {
            emptyText = "#shop/recruitCrew",
            crewImage = $"#ui/gameuiskin#slotbar_crew_recruit_{countryData.country.slice(8)}"
            isCrewRecruit = true
            emptyCost = crewData.cost
            isSlotbarItem = true
            fullBlock     = this.needFullSlotBlock
          })

        slotsData.append(this.needFullSlotBlock ? unitItem : SLOT_NEST_TAG.subst(unitItem))
        continue
      }

      let isVisualDisabled = crewData?.isVisualDisabled ?? false
      let isLocalState = !::g_crews_list.isCrewListOverrided && (crewData?.isLocalState ?? true)
      let airParams = {
        emptyText      = isVisualDisabled ? "" : this.emptyText,
        crewImage      = $"#ui/gameuiskin#slotbar_crew_free_{countryData.country.slice(8)}"
        status         = getUnitItemStatusText(crewData.status),
        hasActions     = this.hasActions && !::g_crews_list.isCrewListOverrided
        toBattle       = this.toBattle
        mainActionFunc = ::SessionLobby.canChangeCrewUnits() ? "onSlotChangeAircraft" : ""
        mainActionText = "" // "#multiplayer/changeAircraft"
        mainActionIcon = "#ui/gameuiskin#slot_change_aircraft.svg"
        crewId         = crew?.id
        isSlotbarItem  = true
        showBR         = hasFeature("SlotbarShowBattleRating")
        getEdiffFunc   = this.getCurrentEdiff.bindenv(this)
        hasExtraInfoBlock = this.hasExtraInfoBlock
        haveRespawnCost = this.haveRespawnCost
        haveSpawnDelay = this.haveSpawnDelay
        totalSpawnScore = this.totalSpawnScore
        sessionWpBalance = this.sessionWpBalance
        curSlotIdInCountry = crew.idInCountry
        curSlotCountryId = crew.idCountry
        unlocked = crewData.isUnlocked
        tooltipParams = {
          needCrewInfo = !::g_crews_list.isCrewListOverrided
          showLocalState = isLocalState
          needCrewModificators = true
          needShopInfo = this.needCheckUnitUnlock
          crewId = crew?.id
        }
        missionRules = this.missionRules
        forceCrewInfoUnit = this.unitForSpecType
        isLocalState = isLocalState
        fullBlock        = this.needFullSlotBlock
        bottomLineText = this.needCheckUnitUnlock && isRequireUnlockForUnit(crewData.unit)
          ? getUnitRequireUnlockShortText(crewData.unit)
          : null
      }
      airParams.__update(this.getCrewDataParams(crewData))
      let unitItem = buildUnitSlot(id, crewData.unit, airParams)
      slotsData.append(this.needFullSlotBlock ? unitItem : SLOT_NEST_TAG.subst(unitItem))
    }

    let slotsDataString = "".join(slotsData)
    this.guiScene.replaceContentFromText(tblObj, slotsDataString, slotsDataString.len(), this)
  }

  getCrewDataParams = @(_crewData) {}
  getSlotbar = @() this

  function setCrewUnit(unit) {
    setShowUnit(unit, this.getHangarFallbackUnitParams())
    //need to send event when crew in country not changed, because main unit changed.
    selectCrew(this.curSlotCountryId, this.curSlotIdInCountry, true)
  }

  function getDefaultDblClickFunc() {
    return Callback(function(crew) {
      if (::g_crews_list.isCrewListOverrided)
        return
      let unit = this.getCrewUnit(crew)
      if (unit)
        ::open_weapons_for_unit(unit, { curEdiff = this.getCurrentEdiff() })
    }, this)
  }

  function onSlotbarActivate(_obj) {
    if (!this.isValid())
      return
    let cellObj = this.scene.findObject($"td_slot_{this.curSlotCountryId}_{this.curSlotIdInCountry}")
    if (!cellObj?.isValid() || !cellObj.isHovered())
      return
    this.onSlotActivate(this.getCurCrew())
  }

  function defaultOnSlotActivateFunc(_crew) {
    if (this.hasActions && !::g_crews_list.isCrewListOverrided) {
      if (isCountrySlotbarHasUnits(profileCountrySq.value))
        this.openUnitActionsList(this.getCurrentCrewSlot())
      else
        this.onSlotChangeAircraft()
    }
  }

  function updateWeaponryData(unitSlots = null) {
    if (::g_crews_list.isCrewListOverrided)
      return

    unitSlots = unitSlots ?? this.getSlotsData()
    foreach (slot in unitSlots) {
      let obj = slot.obj.findObject("weapons_icon")
      let unit = slot.unit
      if (!checkObj(obj) || unit == null)
        continue

      let weaponsStatus = getWeaponsStatusName((slot.crew?.isLocalState ?? true) && ::isUnitUsable(unit)
        ? checkUnitWeapons(unit)
        : UNIT_WEAPONS_READY
      )
      obj.weaponsStatus = weaponsStatus
    }
  }

  function onEventUnitBulletsChanged(p) {
    this.updateWeaponryData(this.getSlotsData(p.unit.name))
  }

  function onEventUnitWeaponChanged(p) {
    this.updateWeaponryData(this.getSlotsData(p.unitName))
  }

  function updateSlotbarHint() {
    let obj = this.showSceneBtn("slotbarHint", this.slotbarHintText != "")
    if (obj != null && this.slotbarHintText != "")
     obj.findObject("slotbarHintText").setValue(this.slotbarHintText)
  }

  function onEventLobbyIsInRoomChanged(p) {
    if (p.wasSessionInLobby != ::SessionLobby.hasSessionInLobby())
      this.fullUpdate()
  }

  function onEventVisibleCountriesCacheInvalidate(_p) {
    if (this.loadedCountries.len() != getShopVisibleCountries().len())
      this.fullUpdate()
  }
}