//checked for plus_string
from "%scripts/dagui_library.nut" import *

let unitStatus = require("%scripts/unit/unitStatus.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let openCrossPromoWnd = require("%scripts/openCrossPromoWnd.nut")

let ACTION_FUNCTION_PARAMS = {
  availableFlushExp = 0
  isSquadronResearchMode = false
  setResearchManually = false
  needChosenResearchOfSquadron = false
}

let MAIN_FUNC_PARAMS = {
  onSpendExcessExp = null
  onTakeParams = {}
  availableFlushExp = 0
  isSquadronResearchMode = false
  setResearchManually = true
  needChosenResearchOfSquadron = false
  curEdiff = 0
}

local function getSlotActionFunctionName(unit, params) {
  params = ACTION_FUNCTION_PARAMS.__merge(params)

  if (::isUnitBroken(unit))
    return "mainmenu/btnRepair"
  if (::isUnitInSlotbar(unit))
    return ""
  if (unit.isUsable() && !::isUnitInSlotbar(unit))
    return "mainmenu/btnTakeAircraft"
  if (!unit.isCrossPromo && (::canBuyUnit(unit) || ::canBuyUnitOnline(unit)))
    return "mainmenu/btnOrder"

  let isSquadronVehicle = unit.isSquadronVehicle()
  let isInResearch = ::isUnitInResearch(unit)
  let canFlushSquadronExp = hasFeature("ClanVehicles") && isSquadronVehicle
    && min(::clan_get_exp(), unit.reqExp - ::getUnitExp(unit)) > 0
  if ((params.availableFlushExp > 0 || !params.setResearchManually
      || (params.isSquadronResearchMode && params.needChosenResearchOfSquadron)
      || (isSquadronVehicle && !::is_in_clan() && !canFlushSquadronExp))
    && (::canResearchUnit(unit) || isInResearch))
    return "mainmenu/btnResearch"
  if(unit.isCrossPromo && !unit.isUsable())
    return "mainmenu/btnResearch"
  if (isInResearch && hasFeature("SpendGold") && !isSquadronVehicle)
    return "mainmenu/btnConvert"

  if (canFlushSquadronExp && (isInResearch || params.isSquadronResearchMode))
    return "mainmenu/btnInvestSquadronExp"
  if (isInResearch && unitStatus.canBuyNotResearched(unit))
    return "mainmenu/btnOrder"
  if (!::isUnitUsable(unit) && !::isUnitGift(unit) && (!isSquadronVehicle || !isInResearch))
    return (::isUnitResearched(unit) || ::isUnitMaxExp(unit)) ? "mainmenu/btnOrder" : "mainmenu/btnResearch"
  return ""
}

local function slotMainAction(unit, params = MAIN_FUNC_PARAMS) {
  if (!unit || ::isUnitGroup(unit) || unit?.isFakeUnit)
    return

  params = MAIN_FUNC_PARAMS.__merge(params)

  if (::isUnitBroken(unit))
    return unitActions.repairWithMsgBox(unit)
  if (::isUnitInSlotbar(unit))
    return ::open_weapons_for_unit(unit, { curEdiff = params.curEdiff })
  if (unit.isUsable() && !::isUnitInSlotbar(unit))
    return unitActions.take(unit, params.onTakeParams)
  if (::canBuyUnitOnline(unit))
    return ::OnlineShopModel.showUnitGoods(unit.name, "slot_action")
  if (::canBuyUnit(unit))
    return unitActions.buy(unit, "slotAction")

  let isSquadronVehicle = unit.isSquadronVehicle()
  let isInResearch = ::isUnitInResearch(unit)
  let canFlushSquadronExp = hasFeature("ClanVehicles") && isSquadronVehicle
    && min(::clan_get_exp(), unit.reqExp - ::getUnitExp(unit)) > 0
  if ((params.availableFlushExp > 0
      || !params.setResearchManually
      || (params.isSquadronResearchMode && (canFlushSquadronExp || params.needChosenResearchOfSquadron)))
    && (::canResearchUnit(unit) || isInResearch))
    return params.onSpendExcessExp()
  if (isInResearch && hasFeature("SpendGold")
      && !isSquadronVehicle && ::can_spend_gold_on_unit_with_popup(unit))
    return ::gui_modal_convertExp(unit)

  if (canFlushSquadronExp && isInResearch)
    return unitActions.flushSquadronExp(unit)
  if (isInResearch && unitStatus.canBuyNotResearched(unit)
    && isSquadronVehicle && ::is_in_clan())
    return unitActions.buy(unit, "slot_action_squad")
  if (unit.isCrossPromo)
    return openCrossPromoWnd(unit.crossPromoBanner)
  if (::checkForResearch(unit)) // Also shows msgbox about requirements for Research or Purchase
    return unitActions.research(unit)
}

return {
  getSlotActionFunctionName = getSlotActionFunctionName
  slotMainAction = slotMainAction
}