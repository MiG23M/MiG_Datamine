from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")

let AT_RUNWAY_TYPE = {
  name = "AT_RUNWAY"
  objName = "airfield"
  locId = "air"
  spriteType = "Airfield"
  configurableValue = "airArmiesLimitPerArmyGroup"
  wwUnitClass = WW_UNIT_CLASS.FIGHTER
  unitType = g_ww_unit_type.AIR
  overrideUnitType = null
  flyoutSound = "ww_unit_move_airplanes"
}

let AT_HELIPAD_TYPE = {
  name = "AT_HELIPAD"
  objName = "helipad"
  locId = "helicopter"
  spriteType = "Helipad"
  configurableValue = "helicopterArmiesLimitPerArmyGroup"
  wwUnitClass = WW_UNIT_CLASS.HELICOPTER
  unitType = g_ww_unit_type.HELICOPTER
  overrideUnitType = g_ww_unit_type.HELICOPTER.code
  flyoutSound = "ww_unit_move_helicopters"
}

//The type names that this module returns are used for to compare values with type from blk of airfields
return {
  AT_RUNWAY = AT_RUNWAY_TYPE
  AT_HELIPAD = AT_HELIPAD_TYPE
}