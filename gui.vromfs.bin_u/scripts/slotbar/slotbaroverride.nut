from "%scripts/dagui_natives.nut" import is_country_available
from "%scripts/dagui_library.nut" import *
let { isDataBlock, isEmpty, isEqual } = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getUrlOrFileMissionMetaInfo, isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")
let { needShowOverrideSlotbar } = require("%scripts/events/eventInfo.nut")
let { isRequireUnlockForUnit } = require("%scripts/unit/unitInfo.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")

let overrrideSlotbarMissionName = mkWatched(persist, "overrrideSlotbarMissionName", "") //recalc slotbar only on mission change
let overrideSlotbar = mkWatched(persist, "overrideSlotbar", null) //null or []
let userSlotbarCountry = mkWatched(persist, "userSlotbarCountry", "") //for return user country after reset override slotbar
let selectedCountryByMissionName = hardPersistWatched("selectedCountryByMissionName", {})

overrideSlotbar.subscribe(@(_) broadcastEvent("OverrideSlotbarChanged"))

let makeCrewsCountryData = @(country) { country = country, crews = [] }

function addCrewToCountryData(countryData, crewId, countryId, crewUnitName) {
  countryData.crews.append({
    id = crewId
    idCountry = countryId
    idInCountry = countryData.crews.len()
    country = countryData.country

    aircraft = crewUnitName
    isEmpty = isEmpty(crewUnitName) ? 1 : 0

    trainedSpec = {}
    trained = []
    skillPoints = 0
    lockedTillSec = 0
    isLocked = 0
  })
}

function getMissionEditSlotbarBlk(missionName) {
  let misBlk = getUrlOrFileMissionMetaInfo(missionName)
  let editSlotbar = misBlk?.editSlotbar
  //override slotbar does not support keepOwnUnits atm.
  if (!isDataBlock(editSlotbar) || editSlotbar.keepOwnUnits)
    return null
  return editSlotbar
}

function calcSlotbarOverrideByMissionName(missionName, event = null) {
  local res = null
  let gmEditSlotbar = event?.mission_decl.editSlotbar
  let editSlotbar = gmEditSlotbar ? ::build_blk_from_container(gmEditSlotbar) //!!!FIX ME Will be better to turn editSlotbar data block from missions config into table
    : getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  res = []
  local crewId = -1 //negative crews are invalid, so we prevent any actions with such crews.
  foreach (country in shopCountriesList) {
    let countryBlk = editSlotbar?[country]
    if (!isDataBlock(countryBlk) || !countryBlk.blockCount()
      || !is_country_available(country))
      continue

    let countryData = makeCrewsCountryData(country)
    res.append(countryData)
    for (local i = 0; i < countryBlk.blockCount(); i++) {
      let crewBlk = countryBlk.getBlock(i)
      if (crewBlk?.needToShowInEventWnd == false)
        continue

      addCrewToCountryData(countryData, crewId--, res.len() - 1, crewBlk.getBlockName())
    }
  }
  if (!res.len())
    res = null
  return res
}

function getSlotbarOverrideCountriesByMissionName(missionName) {
  let res = []
  let editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  foreach (country in shopCountriesList) {
    let countryBlk = editSlotbar?[country]
    if (isDataBlock(countryBlk) && countryBlk.blockCount()
      && is_country_available(country))
      res.append(country)
  }
  return res
}

function getSlotbarOverrideData(missionName = "", event = null) {
  if (missionName == "" || missionName == overrrideSlotbarMissionName.value)
    return overrideSlotbar.value

  return calcSlotbarOverrideByMissionName(missionName, event)
}

let isSlotbarOverrided = @(missionName = "", event = null) getSlotbarOverrideData(missionName, event) != null

function updateOverrideSlotbar(missionName, event = null) {
  if (missionName == overrrideSlotbarMissionName.value)
    return
  overrrideSlotbarMissionName(missionName)

  let newOverrideSlotbar = calcSlotbarOverrideByMissionName(missionName, event)
  if (isEqual(overrideSlotbar.value, newOverrideSlotbar))
    return

  if (!isSlotbarOverrided())
    userSlotbarCountry(profileCountrySq.value)
  overrideSlotbar(newOverrideSlotbar)
  let missionCountry = selectedCountryByMissionName.get()?[missionName]
  if (missionCountry != null)
    switchProfileCountry(missionCountry)
}

function resetSlotbarOverrided() {
  overrrideSlotbarMissionName("")
  overrideSlotbar(null)
  if (userSlotbarCountry.value != "")
    switchProfileCountry(userSlotbarCountry.value)
  userSlotbarCountry("")
}

function getEventSlotbarHint(event, country) {
  if (!needShowOverrideSlotbar(event))
    return ""

  let overrideSlotbarData = getSlotbarOverrideData(::events.getEventMission(event.name), event)
  if ((overrideSlotbarData?.len() ?? 0) == 0)
    return ""

  let crews = overrideSlotbarData.findvalue(@(v) v.country == country)?.crews
  if (crews == null)
    return ""

  let hasNotUnlockedUnit = crews.findindex(
    @(c) isRequireUnlockForUnit(getAircraftByName(c.aircraft))
  ) != null

  if (!hasNotUnlockedUnit)
    return ""

  return isMissionExtrByName(event.name)
    ? loc("event_extr/unlockUnits")
    : loc("event/unlockAircrafts")
}

function selectCountryForCurrentOverrideSlotbar(country) {
  if (overrrideSlotbarMissionName.get() == "")
    return
  selectedCountryByMissionName.mutate(@(v) v[overrrideSlotbarMissionName.get()] <- country)
}

return {
  getMissionEditSlotbarBlk
  getSlotbarOverrideCountriesByMissionName
  updateOverrideSlotbar
  getSlotbarOverrideData
  isSlotbarOverrided
  resetSlotbarOverrided
  getEventSlotbarHint
  selectCountryForCurrentOverrideSlotbar
}