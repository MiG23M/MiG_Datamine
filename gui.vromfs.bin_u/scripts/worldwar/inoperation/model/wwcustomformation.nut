//checked for plus_string
from "%scripts/dagui_library.nut" import *


let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let {WwFormation} = require("wwFormation.nut")

let WwCustomFormation = class extends WwFormation {
  constructor(blk, airfield) {
    this.units = []
    this.update(blk, airfield)
  }

  function update(blk, airfield) {
    this.owner = ::WwArmyOwner(blk.getBlockByName("owner"))
    this.morale = airfield.createArmyMorale
  }

  function clear() {
    base.clear()
  }

  function isValid() {
    return false
  }

  function getArmyGroup() {
    return null
  }

  function addUnits(blk) {
    let additionalUnits = wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units"))
    this.units.extend(additionalUnits)
    this.units = this.units.reduce(function (memo, unit) {
      foreach (unitInMemo in memo)
        if (unitInMemo.name == unit.name) {
          unitInMemo.count += unit.count
          return memo
        }
      memo.append(unit)
      return memo
    }, [])
  }
}
return {WwCustomFormation}