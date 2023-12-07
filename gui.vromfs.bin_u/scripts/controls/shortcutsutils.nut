//checked for plus_string
from "%scripts/dagui_library.nut" import *

let shortcutsListModule = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setShortcutsAndSaveControls } = require("%scripts/controls/controlsCompatibility.nut")
let { AXIS_MODIFIERS, GAMEPAD_AXIS, MOUSE_AXIS } = require("%scripts/controls/controlsConsts.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

let getShortcutById = @(shortcutId) shortcutsListModule?[shortcutId]

let function isAxisBoundToMouse(shortcutId) {
  return ::is_axis_mapped_on_mouse(shortcutId)
}

let function getBitArrayAxisIdByShortcutId(joyParams, shortcutId) {
  let shortcutData = getShortcutById(shortcutId)
  let axis = joyParams.getAxis(shortcutData?.axisIndex ?? -1)
  if (axis.axisId < 0)
    if (isAxisBoundToMouse(shortcutId))
      return ::get_mouse_axis(shortcutId, null, joyParams)
    else
      return GAMEPAD_AXIS.NOT_AXIS

  return 1 << axis.axisId
}

let function getComplexAxesId(shortcutComponents) {
  let joyParams = ::joystick_get_cur_settings()
  local axesId = 0
  foreach (shortcutId in shortcutComponents)
    axesId = axesId | getBitArrayAxisIdByShortcutId(joyParams, shortcutId)

  return axesId
}

/**
 * Checks wether all components assigned to one stick or mouse move.
 * @shortcutComponents - array of components, contains shortcutIds
 * @return - bool
*/
let isComponentsAssignedToSingleInputItem = @(axesId)
  axesId == GAMEPAD_AXIS.RIGHT_STICK
  || axesId == GAMEPAD_AXIS.LEFT_STICK
  || axesId == MOUSE_AXIS.MOUSE_MOVE

let getTextMarkup = @(symbol) symbol == "" ? ""
  : "".concat("textareaNoTab {text:t='<color=@axisSymbolColor>", symbol,
    "</color>'; position:t='relative'; top:t='0.45@kbh-0.5h'}")

let function getInputsMarkup(inputs) {
  local res = ""
  foreach (input in inputs) {
    let curMk = input.getMarkup() ?? ""
    if (curMk != "")
      res = $"{res}{res != "" ? getTextMarkup(loc("ui/comma")) : ""}{curMk}"
  }

  return res
}

let function getAxisActivationShortcutData(shortcuts, item, preset) {
  preset = preset ?? ::g_controls_manager.getCurPreset()
  let inputs = []
  let axisDescr = ::g_shortcut_type._getDeviceAxisDescription(item.id)
  let axisInput = (axisDescr.axisId > -1 || axisDescr.mouseAxis != null)
    ? ::Input.Axis(axisDescr, AXIS_MODIFIERS.NONE, preset)
    : null
  let buttons = axisInput ? [axisInput] : []
  let scArr = shortcuts[item.modifiersId[""]]
  for (local i = 0; i < scArr.len(); i++) {
    let sc = scArr[i]
    for (local j = 0; j < sc.dev.len(); j++)
      buttons.append(::Input.Button(sc.dev[j], sc.btn[j], preset))

    if (buttons.len() > 1)
      inputs.append(::Input.Combination(buttons))
    else
      inputs.extend(buttons)
  }
  // Use only axis input if has no shortcuts for combination
  if (scArr.len() == 0 && axisInput)
    inputs.append(axisInput)

  return getInputsMarkup(inputs)
}

let function getShortcutData(shortcuts, shortcutId, cantBeEmpty = true, preset = null) {
  if (shortcuts?[shortcutId] == null)
    return cantBeEmpty ? getTextMarkup(loc("ui/not_applicable")) : ""

  preset = preset ?? ::g_controls_manager.getCurPreset()
  let inputs = []
  for (local i = 0; i < shortcuts[shortcutId].len(); i++) {
    let buttons = []
    let sc = shortcuts[shortcutId][i]

    for (local j = 0; j < sc.dev.len(); j++)
      buttons.append(::Input.Button(sc.dev[j], sc.btn[j], preset))

    if (buttons.len() > 1)
      inputs.append(::Input.Combination(buttons))
    else
      inputs.extend(buttons)
  }

  let markup = getInputsMarkup(inputs)
  return cantBeEmpty && markup == "" ? getTextMarkup(loc("ui/not_applicable")) : markup
}

let function isShortcutEqual(sc1, sc2) {
  if (sc1.len() != sc2.len())
    return false

  foreach (_i, sb in sc2)
    if (!::is_bind_in_shortcut(sb, sc1))
      return false
  return true
}

let function isShortcutMapped(shortcut) {
  foreach (button in shortcut)
    if (button && button.dev.len() >= 0)
      foreach (d in button.dev)
        if (d > 0 && d <= STD_GESTURE_DEVICE_ID)
            return true
  return false
}

let function restoreShortcuts(scList, scNames) {
  let changeList = []
  let changeNames = []
  let curScList = ::get_shortcuts(scNames)
  foreach (idx, sc in curScList) {
    let prevSc = scList[idx]
    if (!isShortcutMapped(prevSc))
      continue

    if (isShortcutEqual(sc, prevSc))
      continue

    changeList.append(prevSc)
    changeNames.append(scNames[idx])
  }
  if (!changeList.len())
    return

  setShortcutsAndSaveControls(changeList, changeNames)
  broadcastEvent("ControlsPresetChanged")
}

let function hasMappedSecondaryWeaponSelector(unitType) {
  local shortcuts = []

  if (unitType == unitTypes.AIRCRAFT)
    shortcuts = ::get_shortcuts([ "ID_FIRE_SECONDARY", "ID_SWITCH_SHOOTING_CYCLE_SECONDARY" ])
  else if (unitType == unitTypes.HELICOPTER)
    shortcuts = ::get_shortcuts([ "ID_FIRE_SECONDARY_HELICOPTER", "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER" ])

  return (shortcuts.len() > 0)
    ? (isShortcutMapped(shortcuts[0]) && isShortcutMapped(shortcuts[1]))
    : false
}

return {
  getShortcutById
  isAxisBoundToMouse
  getComplexAxesId
  isComponentsAssignedToSingleInputItem
  getTextMarkup
  getShortcutData
  getAxisActivationShortcutData
  isShortcutMapped
  restoreShortcuts
  hasMappedSecondaryWeaponSelector
}
