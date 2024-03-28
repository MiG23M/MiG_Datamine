from "%scripts/dagui_natives.nut" import clan_get_exp, shop_set_researchable_unit, shop_get_researchable_unit_name, clan_get_researching_unit, char_send_blk, char_send_action_and_load_profile
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")

let DataBlock  = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let {
  getEsUnitType, getUnitName, getUnitCountry, canResearchUnit
} = require("%scripts/unit/unitInfo.nut")
let { showUnitGoods } = require("%scripts/onlineShop/onlineShopModel.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { addTask, addBgTaskCb } = require("%scripts/tasker.nut")

function repairRequest(unit, price, onSuccessCb = null, onErrorCb = null) {
  let blk = DataBlock()
  blk["name"] = unit.name
  blk["cost"] = price.wp
  blk["costGold"] = price.gold

  let taskId = char_send_blk("cln_prepare_aircraft", blk)

  let progBox = { showProgressBox = true }
  let onTaskSuccess = function() {
    broadcastEvent("UnitRepaired", { unit = unit })
    if (onSuccessCb)
      onSuccessCb()
  }

  addTask(taskId, progBox, onTaskSuccess, onErrorCb)
}

function repair(unit, onSuccessCb = null, onErrorCb = null) {
  if (!unit) {
    onErrorCb?()
    return
  }
  let price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  if (checkBalanceMsgBox(price))
    repairRequest(unit, price, onSuccessCb, onErrorCb)
  else
    onErrorCb?()
}

function repairWithMsgBox(unit, onSuccessCb = null) {
  if (!unit)
    return
  let price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  let msgText = loc("msgbox/question_repair", { unitName = loc(getUnitName(unit)), cost = price.tostring() })
  scene_msg_box("question_repair", null, msgText,
  [
    ["yes", function() { repair(unit, onSuccessCb) }],
    ["no", function() {} ]
  ], "no", { cancel_fn = function() {} })
}

function showFlushSquadronExpMsgBox(unit, onDoneCb, onCancelCb) {
  scene_msg_box("ask_flush_squadron_exp",
    null,
    loc("squadronExp/invest/needMoneyQuestion",
      { exp = Cost().setSap(min(clan_get_exp(), unit.reqExp - ::getUnitExp(unit))).tostring() }),
    [
      ["yes", onDoneCb],
      ["no", onCancelCb]
    ],
    "yes")
}

function flushSquadronExp(unit, params = {}) {
  if (!unit)
    return

  let { afterDoneFunc = @() null } = params
  let onDoneCb = @() addTask(char_send_action_and_load_profile("cln_flush_clan_exp_to_unit"),
    null,
    function() {
      afterDoneFunc()
      broadcastEvent("FlushSquadronExp", { unit = unit })
    })
  showFlushSquadronExpMsgBox(unit, onDoneCb, afterDoneFunc)
}

function buy(unit, metric) {
  if (!unit)
    return

  if (::canBuyUnitOnline(unit))
    showUnitGoods(unit.name, metric)
  else
    ::buyUnit(unit)
}

function research(unit, checkCurrentUnit = true, afterDoneFunc = null) {
  let unitName = unit.name
  sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unitName })
  if (!canResearchUnit(unit) || (checkCurrentUnit && ::isUnitInResearch(unit)))
    return

  local prevUnitName = shop_get_researchable_unit_name(getUnitCountry(unit), getEsUnitType(unit))
  local taskId = -1
  if (unit.isSquadronVehicle()) {
     prevUnitName = clan_get_researching_unit()

     let blk = DataBlock()
     blk.addStr("unit", unitName);
     taskId = char_send_blk("cln_set_research_clan_unit", blk)
  }
  else
    taskId = shop_set_researchable_unit(unitName, getEsUnitType(unit))
  let progressBox = scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
  addBgTaskCb(taskId, function() {
    destroyMsgBox(progressBox)
    if (afterDoneFunc)
      afterDoneFunc()
    broadcastEvent("UnitResearch", { unitName = unitName, prevUnitName = prevUnitName })
  })
}

function setResearchClanVehicleWithAutoFlushImpl(unit, afterDoneFunc = @() null) {
  let unitName = unit.name
  sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unitName })
  let prevUnitName = clan_get_researching_unit()
  let blk = DataBlock()
  blk.addStr("unit", unitName)
  blk.addBool("auto", true)
  let taskId = char_send_blk("cln_set_research_clan_unit", blk)
  let taskCallback = function() {
    afterDoneFunc()
    broadcastEvent("UnitResearch", { unitName, prevUnitName, unit })
  }
  addTask(taskId, { showProgressBox = true }, taskCallback, taskCallback)
}

function setResearchClanVehicleWithAutoFlush(unit, afterDoneFunc = @() null) {
  if (!canResearchUnit(unit) || ::isUnitInResearch(unit))
    return

  showFlushSquadronExpMsgBox(unit, @() setResearchClanVehicleWithAutoFlushImpl(unit, afterDoneFunc), afterDoneFunc)
}

return {
  repair
  repairWithMsgBox
  flushSquadronExp
  buy
  research
  setResearchClanVehicleWithAutoFlush
}
