//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { toUpper } = require("%sqstd/string.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { get_current_mission_info_cached } = require("blkGetters")

::mission_rules <- {}
foreach (fn in [
                 "unitLimit.nut"
                 "ruleBase.nut"
                 "ruleSharedPool.nut"
                 "ruleEnduringConfrontation.nut"
                 "ruleNumSpawnsByUnitType.nut"
                 "ruleUnitsDeck.nut"
               ])
  loadOnce($"%scripts/misCustomRules/{fn}") // no need to includeOnce to correct reload this scripts pack runtime

::on_custom_mission_state_changed <- function on_custom_mission_state_changed() {
  ::g_mis_custom_state.onMissionStateChanged()
}

::on_custom_user_state_changed <- function on_custom_user_state_changed(userId64) {
  ::g_mis_custom_state.onUserStateChanged(userId64)
}

::g_mis_custom_state <- {
  curRules = null
  isCurRulesValid = false
}

::g_mis_custom_state.getCurMissionRules <- function getCurMissionRules() {
  if (this.isCurRulesValid)
    return this.curRules

  local rulesClass = ::mission_rules.Empty

  let rulesName = this.getCurMissionRulesName()
  if (u.isString(rulesName))
    rulesClass = this.findRulesClassByName(rulesName)

  let chosenRulesName = (rulesClass == ::mission_rules.Empty) ? "empty" : rulesName
  log("Set mission custom rules to " + chosenRulesName + ". In mission info was " + rulesName)

  this.curRules = rulesClass()

  this.isCurRulesValid = true
  return this.curRules
}

::g_mis_custom_state.getCurMissionRulesName <- function getCurMissionRulesName() {
  let mis = ::is_in_flight() ? get_current_mission_info_cached() : null
  return mis?.customRules.guiName ?? mis?.customRules.name
}

::g_mis_custom_state.findRulesClassByName <- function findRulesClassByName(rulesName) {
  return getTblValue(toUpper(rulesName, 1), ::mission_rules, ::mission_rules.Empty)
}

::g_mis_custom_state.onMissionStateChanged <- function onMissionStateChanged() {
  if (this.curRules)
    this.curRules.onMissionStateChanged()
  broadcastEvent("MissionCustomStateChanged")
}

::g_mis_custom_state.onUserStateChanged <- function onUserStateChanged(userId64) {
  if (userId64 != ::my_user_id_int64)
    return

  this.getCurMissionRules().clearUnitsLimitData()
  broadcastEvent("MyCustomStateChanged")
  //broadcastEvent("UserCustomStateChanged", { userId64 = userId64 }) //not used ATM but maybe needed in future
}

::g_mis_custom_state.onEventLoadingStateChange <- function onEventLoadingStateChange(_p) {
  this.isCurRulesValid = false
}

subscribe_handler(::g_mis_custom_state, ::g_listener_priority.CONFIG_VALIDATION)
