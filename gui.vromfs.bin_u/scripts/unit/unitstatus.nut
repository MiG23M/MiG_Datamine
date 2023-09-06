//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { blkFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { isWeaponAux, getLastPrimaryWeapon, getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponInfoText } = require("%scripts/weaponry/weaponryDescription.nut")

let canBuyNotResearched = @(unit) unit.isVisibleInShop()
  && ::canResearchUnit(unit)
  && unit.isSquadronVehicle()
  && !unit.getOpenCost().isZero()


let function isUnitHaveSecondaryWeapons(unit) {
  local foundWeapon = false
  foreach (weapon in unit.getWeapons())
    if (!isWeaponAux(weapon))
      if (foundWeapon)
        return true
      else
        foundWeapon = true
  return "" != getWeaponInfoText(unit, { isPrimary = false, weaponPreset = 0, needTextWhenNoWeapons = false })
}

let function isShipWithoutPurshasedTorpedoes(unit) {
  if (!unit?.isShipOrBoat())
    return false

  local torpedoes = null
  if (isUnitHaveSecondaryWeapons(unit))
    torpedoes = unit.getWeapons().findvalue(@(weapon) weapon.name == "torpedoes")    //!!! FIX ME: Need determine weapons by weapon mask. WeaponMask now available only for air

  if (!torpedoes)
    return false

  if (::g_weaponry_types.getUpgradeTypeByItem(torpedoes).getAmount(unit, torpedoes) > 0)
    return false

  return true
}

let function getBitStatus(unit, params = {}) {
  let isLocalState = params?.isLocalState ?? true
  let forceNotInResearch  = params?.forceNotInResearch ?? false
  let shopResearchMode    = params?.shopResearchMode ?? false
  let isSquadronResearchMode  = params?.isSquadronResearchMode ?? false

  let isMounted      = ::isUnitInSlotbar(unit)
  let isOwn          = unit.isBought()
  let isSquadVehicle = unit.isSquadronVehicle()
  let researched     = unit.isResearched()

  let isVehicleInResearch = unit.isInResearch() && !forceNotInResearch
  let canResearch         = ::canResearchUnit(unit)

  let unitExpGranted      = unit.getExp()
  let diffExp = isSquadVehicle
    ? min(::clan_get_exp(), ::getUnitReqExp(unit) - unitExpGranted)
    : (params?.diffExp ?? 0)
  let isLockedSquadronVehicle = isSquadVehicle && !::is_in_clan() && diffExp <= 0

  local bitStatus = 0
  if (!isLocalState || ::is_in_flight())
    bitStatus = bit_unit_status.owned
  else if (unit.isBroken())
    bitStatus = bit_unit_status.broken
  else if (isMounted)
    bitStatus = bit_unit_status.mounted
  else if (isOwn)
    bitStatus = bit_unit_status.owned
  else if (::canBuyUnit(unit) || ::canBuyUnitOnline(unit) || ::canBuyUnitOnMarketplace(unit))
    bitStatus = bit_unit_status.canBuy
  else if (isLockedSquadronVehicle && (!unit.unitType.canSpendGold() || !canBuyNotResearched(unit)))
    bitStatus = bit_unit_status.locked
  else if (researched)
    bitStatus = bit_unit_status.researched
  else if (isVehicleInResearch)
    bitStatus = bit_unit_status.inResearch
  else if (canResearch)
    bitStatus = bit_unit_status.canResearch
  else if (unit.isRented())
    bitStatus = bit_unit_status.inRent
  else if (unit.isCrossPromo)
    return bitStatus
  else
    bitStatus = bit_unit_status.locked

  if ((shopResearchMode
      && (isSquadVehicle || !(bitStatus &
        (bit_unit_status.locked
          | bit_unit_status.canBuy
          | bit_unit_status.inResearch
          | bit_unit_status.canResearch))))
    || (isSquadronResearchMode && !isSquadVehicle)) {
    bitStatus = bit_unit_status.disabled
  }

  return bitStatus
}

let availablePrimaryWeaponsMod = {}
let defaultPrimaryWeaponsMod = {
  flares = null,
  chaffs = null
}

let function isAvailablePrimaryWeapon(unit, weaponName) {
  local availableWeapons = availablePrimaryWeaponsMod?[unit.name]
  if (availableWeapons != null)
    return getLastPrimaryWeapon(unit) == availableWeapons[weaponName]

  let unitBlk = ::get_full_unit_blk(unit.name)
  if (!unitBlk)
    return false

  availableWeapons = clone defaultPrimaryWeaponsMod
  if (unitBlk?.modifications != null) {
    let modificationsCount = unitBlk.modifications.blockCount()
    for (local i = 0; i < modificationsCount; i++) {
      let modification = unitBlk.modifications.getBlock(i)
      let modName = modification.getBlockName()
      let commonWeapons = modification?.effects?.commonWeapons
      if (commonWeapons == null)
        continue
      foreach (weap in (commonWeapons % "Weapon")) {

        let weapons = []
        if (unitBlk?.WeaponSlots != null) {
          foreach (weaponSlot in (unitBlk.WeaponSlots % "WeaponSlot")) {
            if (weap?.slot == weaponSlot?.index) {
              foreach (weaponPreset in (weaponSlot % "WeaponPreset")) {
                if (weap?.preset == weaponPreset?.name) {
                  foreach (weapon in (weaponPreset % "Weapon"))
                    weapons.append(weapon)
                  break
                }
              }
              break
            }
          }
        }
        else
          weapons.append(weap)

        foreach (weapon in weapons) {
           if (!weapon?.blk || weapon?.dummy)
            continue
          let weapBlk = blkFromPath(weapon.blk)
          if (availableWeapons != null && (weapBlk?.rocket.isFlare ?? false))
            availableWeapons.flares = modName
          if (availableWeapons != null && (weapBlk?.rocket.isChaff ?? false))
            availableWeapons.chaffs = modName
          if (availableWeapons != null && (weapBlk?.bullet.rocket.isChaff ?? false))
            availableWeapons.chaffs = modName
          if (availableWeapons != null && (weapBlk?.bullet.rocket.isFlare ?? false))
            availableWeapons.flares = modName
        }
      }
    }
  }
  availablePrimaryWeaponsMod[unit.name] <- availableWeapons
  return getLastPrimaryWeapon(unit) == availableWeapons[weaponName]
}

let function getCurrentPreset(unit) {
  let secondaryWep = getLastWeapon(unit?.name ?? "")
  return secondaryWep != "" ? unit.getWeapons().findvalue(@(w) w.name == secondaryWep) : null
}

let function hasCountermeasures(unit) {
  if (unit == null)
    return false

  return (getCurrentPreset(unit)?.hasCountermeasures ?? false)
    || isAvailablePrimaryWeapon(unit, "flares") || isAvailablePrimaryWeapon(unit, "chaffs")
}

let function bombNbr(unit) {
  if (unit == null)
    return -1

  return getCurrentPreset(unit)?.bombsNbr ?? -1
}

let isRequireUnlockForUnit = @(unit) unit?.reqUnlock != null && !isUnlockOpened(unit.reqUnlock)

return {
  canBuyNotResearched
  isShipWithoutPurshasedTorpedoes
  getBitStatus
  hasCountermeasures
  bombNbr
  isUnitHaveSecondaryWeapons
  isRequireUnlockForUnit
  getCurrentPreset
}