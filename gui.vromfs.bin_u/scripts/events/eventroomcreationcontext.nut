//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_gui_option } = require("guiOptions")
let { USEROPT_CLUSTER, USEROPT_RANK, USEROPT_COUNTRIES_SET,
  USEROPT_BIT_COUNTRIES_TEAM_A, USEROPT_BIT_COUNTRIES_TEAM_B
} = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getClustersList } = require("%scripts/onlineInfo/clustersManagement.nut")

enum CREWS_READY_STATUS {
  HAS_ALLOWED              = 0x0001
  HAS_REQUIRED_AND_ALLOWED = 0x0002

  //mask
  READY                    = 0x0003
}

const CHOSEN_EVENT_MISSIONS_SAVE_ID = "events/chosenMissions/"
const CHOSEN_EVENT_MISSIONS_SAVE_KEY = "mission"

::EventRoomCreationContext <- class {
  mGameMode = null
  onUnitAvailabilityChanged = null

  misListType = ::g_mislist_type.BASE
  fullMissionsList = null
  chosenMissionsList = null

  curBrRange = null
  curCountries = null

  isAllowCountriesSetsOnly = false

  constructor(sourceMGameMode, onUnitAvailabilityChangedCb = null) {
    this.mGameMode = sourceMGameMode
    this.isAllowCountriesSetsOnly = this.mGameMode?.allowCountriesSetsOnly ?? false
    this.onUnitAvailabilityChanged = onUnitAvailabilityChangedCb
    this.curCountries = {}
    this.initMissionsOnce()
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getOptionsList() {
    let options = [
      [USEROPT_CLUSTER],
      [USEROPT_RANK],
    ]

    if (this.isAllowCountriesSetsOnly)
      options.append([USEROPT_COUNTRIES_SET])
    else
      options.append([USEROPT_BIT_COUNTRIES_TEAM_A],
        [USEROPT_BIT_COUNTRIES_TEAM_B])

    return options
  }

  _optionsConfig = null
  function getOptionsConfig() {
    if (this._optionsConfig)
      return this._optionsConfig

    this._optionsConfig = {
      isEventRoom = true
      brRanges = this.mGameMode?.matchmaking.mmRanges
      countries = {}
      countriesSetList = []
      onChangeCb = Callback(this.onOptionChange, this)
    }
    if (this.isAllowCountriesSetsOnly)
      this._optionsConfig.countriesSetList = ::events.getAllCountriesSets(this.mGameMode)
    else
      foreach (team in ::g_team.getTeams())
        this._optionsConfig.countries[team.name] <- this.mGameMode?[team.name].countries

    return this._optionsConfig
  }

  function isAllMissionsSelected() {
    return !this.chosenMissionsList.len() || this.chosenMissionsList.len() == this.fullMissionsList.len()
  }

  function createRoom() {
    let reasonData = this.getCantCreateReasonData({ isFullText = true })
    if (!reasonData.checkStatus)
      return reasonData.actionFunc(reasonData)

    ::SessionLobby.createEventRoom(this.mGameMode, this.getRoomCreateParams())
  }

  function isUnitAllowed(unit) {
    if (!::events.isUnitAllowedForEvent(this.mGameMode, unit))
      return false

    let brRange = this.getCurBrRange()
    if (brRange) {
      let ediff = ::events.getEDiffByEvent(this.mGameMode)
      let unitMRank = unit.getEconomicRank(ediff)
      if (unitMRank < getTblValue(0, brRange, 0) || getTblValue(1, brRange, ::max_country_rank) < unitMRank)
        return false
    }

    return this.isCountryAvailable(unit.shopCountry)
  }

  function isCountryAvailable(country) {
    foreach (team in ::g_team.getTeams())
      if (isInArray(country, this.getCurCountries(team)))
        return true
    return false
  }

  function getCurCrewsReadyStatus() {
    local res = 0
    let country = profileCountrySq.value
    let ediff = ::events.getEDiffByEvent(this.mGameMode)
    foreach (team in ::g_team.getTeams()) {
      if (!isInArray(country, this.getCurCountries(team)))
       continue

      let teamData = ::events.getTeamData(this.mGameMode, team.code)
      let requiredCrafts = ::events.getRequiredCrafts(teamData)
      let crews = ::get_crews_list_by_country(country)
      foreach (crew in crews) {
        if (::is_crew_locked_by_prev_battle(crew))
          continue
        let unit = ::g_crew.getCrewUnit(crew)
        if (!unit)
          continue

        if (!this.isUnitAllowed(unit))
          continue
        res = res | CREWS_READY_STATUS.HAS_ALLOWED

        if (requiredCrafts.len() && !::events.isUnitMatchesRule(unit, requiredCrafts, true, ediff))
          continue
        res = res | CREWS_READY_STATUS.HAS_REQUIRED_AND_ALLOWED

        return res
      }
    }
    return res
  }

  //same format result as ::events.getCantJoinReasonData
  function getCantCreateReasonData(params = null) {
    params = params ? clone params : {}
    params.isCreationCheck <- true
    let res = ::events.getCantJoinReasonData(this.mGameMode, null, params)
    if (res.reasonText.len())
      return res

    if (!this.isCountryAvailable(profileCountrySq.value)) {
      res.reasonText = loc("events/no_selected_country")
    }
    else {
      let crewsStatus = this.getCurCrewsReadyStatus()
      if (!(crewsStatus & CREWS_READY_STATUS.HAS_ALLOWED))
        res.reasonText = loc("events/no_allowed_crafts")
      else if (!(crewsStatus & CREWS_READY_STATUS.HAS_REQUIRED_AND_ALLOWED))
        res.reasonText = loc("events/no_required_crafts")
    }

    if (res.reasonText.len()) {
      res.checkStatus = false
      res.activeJoinButton = false
      if (!res.actionFunc)
        res.actionFunc = function (reasonData) {
          showInfoMsgBox(reasonData.reasonText, "cant_create_event_room")
        }
    }
    return res
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function initMissionsOnce() {
    this.chosenMissionsList = []
    this.fullMissionsList = []

    let missionsTbl = this.mGameMode?.mission_decl.missions_list
    if (!missionsTbl)
      return

    let missionsNames = u.keys(missionsTbl)
    this.fullMissionsList = this.misListType.getMissionsListByNames(missionsNames)
    this.fullMissionsList = this.misListType.sortMissionsByName(this.fullMissionsList)
    this.loadChosenMissions()
  }

  getMissionsSaveId = @()
    "".concat(CHOSEN_EVENT_MISSIONS_SAVE_ID, ::events.getEventEconomicName(this.mGameMode))

  function loadChosenMissions() {
    this.chosenMissionsList.clear()
    let blk = loadLocalAccountSettings(this.getMissionsSaveId())
    if (!u.isDataBlock(blk))
      return

    let chosenNames = blk % CHOSEN_EVENT_MISSIONS_SAVE_KEY
    foreach (mission in this.fullMissionsList)
      if (isInArray(mission.id, chosenNames))
        this.chosenMissionsList.append(mission)
  }

  function saveChosenMissions() {
    let names = this.chosenMissionsList.map(@(m) m.id)
    saveLocalAccountSettings(this.getMissionsSaveId(), ::array_to_blk(names, CHOSEN_EVENT_MISSIONS_SAVE_KEY))
  }

  function setChosenMissions(missions) {
    this.chosenMissionsList = missions
    this.saveChosenMissions()
  }

  function getCurBrRange() {
    if (!this.getOptionsConfig().brRanges)
      return null
    if (!this.curBrRange)
      this.setCurBrRange(::get_option(USEROPT_RANK, this.getOptionsConfig()).value)
    return this.curBrRange
  }

  function setCurBrRange(rangeIdx) {
    let brRanges = this.getOptionsConfig().brRanges
    if (rangeIdx in brRanges)
      this.curBrRange = brRanges[rangeIdx]
  }

  function getCurCountries(team) {
    if (team.id in this.curCountries)
      return this.curCountries[team.id]
    if (team.teamCountriesOption < 0)
      return []
    if (this.isAllowCountriesSetsOnly)
      this.setCurCountriesArray(team, get_gui_option(USEROPT_COUNTRIES_SET))
    else {
      local curMask = get_gui_option(team.teamCountriesOption)
      if (curMask == null)
        curMask = -1
      this.setCurCountries(team,  curMask)
    }
    return this.curCountries[team.id]
  }

  function setCurCountries(team, countriesMask) {
    this.curCountries[team.id] <- ::get_array_by_bit_value(countriesMask, shopCountriesList)
  }

  function setCurCountriesArray(team, countriesSetIdx) {
    let countriesSet = this.getOptionsConfig().countriesSetList?[countriesSetIdx].countries
    this.curCountries[team.id] <- countriesSet?[team.code - 1] ?? (clone shopCountriesList)
  }

  function onOptionChange(optionId, optionValue, controlValue) {
    if (optionId == USEROPT_RANK)
      this.setCurBrRange(controlValue)
    else if (optionId == USEROPT_BIT_COUNTRIES_TEAM_A || optionId == USEROPT_BIT_COUNTRIES_TEAM_B)
      this.setCurCountries(::g_team.getTeamByCountriesOption(optionId), optionValue)
    else if (optionId == USEROPT_COUNTRIES_SET)
      foreach (team in [::g_team.A, ::g_team.B])
        this.setCurCountriesArray(team, optionValue)
    else
      return

    if (this.onUnitAvailabilityChanged)
      get_cur_gui_scene().performDelayed(this, function() { this.onUnitAvailabilityChanged() })
  }

  function getRoomCreateParams() {
    let res = {
      ranks = [1, ::max_country_rank] //matching do nt allow to create session before ranks is set
    }

    foreach (team in ::g_team.getTeams())
      res[team.name] <- {
         countries = this.getCurCountries(team)
      }

    if (this.getCurBrRange())
      res.mranks <- this.getCurBrRange()

    let clusterOpt = ::get_option(USEROPT_CLUSTER)
    res.cluster <- getTblValue(clusterOpt.value, clusterOpt.values, "")
    if (res.cluster == "auto")
      res.cluster = getClustersList().filter(@(info) info.isDefault)[0].name

    if (!this.isAllMissionsSelected())
      res.missions <- this.chosenMissionsList.map(@(m) m.id)

    return res
  }
}