//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { hangar_get_current_unit_name } = require("hangar")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadModel } = require("%scripts/hangarModelLoadManager.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")

local isFallbackUnitInHangar = null
let hangarDefaultUnits = {}

let function getCountryHangarDefaultUnit(countryId, esUnitType) {
  if (hangarDefaultUnits?[countryId] == null) {
    hangarDefaultUnits[countryId] <- {}
    foreach (needReserveUnit in [ true, false ]) {
      foreach (u in getAllUnits())
        if (u.isVisibleInShop() && u.shopCountry == countryId
            && (!needReserveUnit || ::isUnitDefault(u))
            && hangarDefaultUnits[countryId]?[u.esUnitType] == null)
          hangarDefaultUnits[countryId][u.esUnitType] <- u
      if (hangarDefaultUnits[countryId].len() == unitTypes.types.len() - 1)
        break
    }
  }
  return hangarDefaultUnits[countryId]?[esUnitType]
    ?? hangarDefaultUnits[countryId].findvalue(@(_u) true)
}

let function getFallbackUnitForHangar(params) {
  // Trying a currently loaded hangar unit
  let countryId = params?.country ?? profileCountrySq.value
  let curHangarUnit = getAircraftByName(hangar_get_current_unit_name())
  if (curHangarUnit?.shopCountry == countryId
      && (params?.slotbarUnits ?? []).indexof(curHangarUnit) != null)
    return curHangarUnit

  // Trying any other unit from country slotbar
  let esUnitType = curHangarUnit?.esUnitType ?? ES_UNIT_TYPE_AIRCRAFT
  foreach (needCheckUnitType in [ true, false ])
    foreach (unit in (params?.slotbarUnits ?? []))
      if (!needCheckUnitType || unit.esUnitType == esUnitType)
        return unit

  // Country default unit (for countries with empty slotbar)
  return getCountryHangarDefaultUnit(countryId, esUnitType)
}

let showedUnit = persist("showedUnit", @() Watched(null))

let getShowedUnitName = @() showedUnit.value?.name ??
  (isFallbackUnitInHangar ? "" : hangar_get_current_unit_name())

let getShowedUnit = @() showedUnit.value ??
  (isFallbackUnitInHangar ? null : getAircraftByName(hangar_get_current_unit_name()))

let function setShowUnit(unit, params = null) {
  showedUnit(unit)
  isFallbackUnitInHangar = unit == null
  loadModel(unit?.name ?? getFallbackUnitForHangar(params)?.name ?? "")
}

showedUnit.subscribe(function(_v) {
  broadcastEvent("ShowedUnitChanged")
})

let function getPlayerCurUnit() {
  local unit = null
  if (::is_in_flight())
    unit = getAircraftByName(::get_player_unit_name())
  if (!unit || unit.name == "dummy_plane")
    unit = showedUnit.value ?? getAircraftByName(hangar_get_current_unit_name())
  return unit
}


return {
  showedUnit
  getShowedUnitName
  getShowedUnit
  setShowUnit
  getPlayerCurUnit
}


