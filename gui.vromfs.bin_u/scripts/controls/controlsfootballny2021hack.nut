
/**
 * Temporary hack, for NEW Year 2021 Football event.
 * PLEASE KEEP AT LEAST tryControlsRestore() FUNCTION ON PRODUCTION
 * FOR AT LEAST 3 MONTHS, UNTIL APRIL 2021.
 * It overrides the control preset for gamepad in Football mission,
 * and restores the original controls after the mission or on login.
 */

from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { get_charserver_time_sec } = require("chard")
let { convertBlk } = require("%sqstd/datablock.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { forceSaveProfile } = require("%scripts/clientState/saveProfile.nut")
let { get_game_mode } = require("mission")
let { parse_json } = require("json")
let { hasXInputDevice, isXInputDevice } = require("controls")


const FOOTBALL_NY2021_BACKUP_SAVE_ID = "footballNy2021Backup"

function shouldManageControls() {
  return (isXInputDevice() || hasXInputDevice()) && ::g_login.isProfileReceived()
}

function removeSingleGamepadBtnId(hc, btnId) {
  return hc.filter(@(sc) sc.len() != 1 || sc[0]?.deviceId != JOYSTICK_DEVICE_0_ID || sc[0]?.buttonId != btnId)
}

function addSingleGamepadBtnId(hc, btnId) {
  return removeSingleGamepadBtnId(hc, btnId).append([ { deviceId = JOYSTICK_DEVICE_0_ID, buttonId = btnId } ])
}

function isHotkeyEmpty(hc) {
  return hc.len() == 0 || (hc.len() == 1 && hc[0].len() == 0)
}

//==============================================================================

function tryControlsOverride() {
  if (!shouldManageControls())
    return false
  if (get_game_mode() != GM_DOMINATION || !::SessionLobby.getMissionName().contains("football"))
    return false
  if (loadLocalAccountSettings(FOOTBALL_NY2021_BACKUP_SAVE_ID) != null)
    return false

  let preset = ::g_controls_manager.getCurPreset()
  let hcPrimaryGun = preset.getHotkey("ID_FIRE_GM")
  let hcMachineGun = preset.getHotkey("ID_FIRE_GM_MACHINE_GUN")

  // Searching for a PrimaryGun/MachineGun shared shortcut (like RT by default).

  local sourceBtnId = null
  foreach (sm in hcMachineGun) {
    foreach (sp in hcPrimaryGun)
      if (sm.len() == 1 && sp.len() == 1
          && sm[0]?.deviceId == JOYSTICK_DEVICE_0_ID && sp[0]?.deviceId == JOYSTICK_DEVICE_0_ID
          && sm[0]?.buttonId == sp[0]?.buttonId) {
        sourceBtnId = sm[0]?.buttonId
        break
      }
    if (sourceBtnId != null)
      break
  }
  if (sourceBtnId == null)
    return false // No changes required.

  // Searching for a btn where ID_FIRE_GM_MACHINE_GUN can be moved.

  let preserveHotkeys = [
    "ID_FLIGHTMENU_SETUP" // Absolutely must have
    "ID_FIRE_GM" // Used to hit the ball
    "ID_FIRE_GM_MACHINE_GUN" // Used to jump
    "ID_TARGETING_HOLD_GM" // Used to watch the ball
    "ID_MPSTATSCREEN"
    "ID_CAMERA_NEUTRAL"
    "ID_TOGGLE_CHAT_TEAM"
    "ID_TOGGLE_CHAT"
    "ID_TOGGLE_CHAT_PARTY"
    "ID_TOGGLE_CHAT_SQUAD"
    "ID_TOGGLE_CHAT_MODE"
  ]

  let tryBtnIdOrder = [
    ::SHORTCUT.GAMEPAD_L2 // LT
    ::SHORTCUT.GAMEPAD_L1 // LB // This one will be chosen for our uncustomized presets.
    ::SHORTCUT.GAMEPAD_R1 // RB
    ::SHORTCUT.GAMEPAD_R2 // RT
    ::SHORTCUT.GAMEPAD_LSTICK_PRESS
    ::SHORTCUT.GAMEPAD_RSTICK_PRESS
    ::SHORTCUT.GAMEPAD_Y
    ::SHORTCUT.GAMEPAD_X
    ::SHORTCUT.GAMEPAD_UP
    ::SHORTCUT.GAMEPAD_DOWN
    ::SHORTCUT.GAMEPAD_LEFT
    ::SHORTCUT.GAMEPAD_RIGHT
  ].map(@(b) b.btn[0]) // Mapped to integer buttonIds

  foreach (hotkeyId in preserveHotkeys) {
    let hc = preset.getHotkey(hotkeyId)
    foreach (sc in hc)
      if (sc.len() == 1 && sc[0]?.deviceId == JOYSTICK_DEVICE_0_ID) {
        let delIdx = tryBtnIdOrder.indexof(sc[0]?.buttonId)
        if (delIdx != null)
          tryBtnIdOrder.remove(delIdx)
      }
  }
  if (tryBtnIdOrder.len() == 0)
    return false // Nothing to choose (extremely bad configured preset).

  let destinationBtnId = tryBtnIdOrder[0]

  log($"FoolballNy2021Hack: ID_FIRE_GM_MACHINE_GUN will be moved from buttonId {sourceBtnId} to {destinationBtnId}")

  // Collecting the conflicting shortcuts to wipe.

  let original = {}
  let modified = {}

  foreach (hotkeyId, hc in preset.hotkeys) {
    local needWipe = false
    foreach (sc in hc)
      if (sc.len() == 1 && sc[0]?.deviceId == JOYSTICK_DEVICE_0_ID && sc[0]?.buttonId == destinationBtnId)
        needWipe = true

    if (needWipe) { // For our uncustomized presets wipes 2 shortcuts: ID_ROCKETS, submarine_depth.
      original[hotkeyId] <- clone hc
      modified[hotkeyId] <- removeSingleGamepadBtnId(hc, destinationBtnId)
    }

    if (hotkeyId == "ID_FIRE_GM_MACHINE_GUN") {
      original[hotkeyId] <- clone hc
      modified[hotkeyId] <- addSingleGamepadBtnId(removeSingleGamepadBtnId(hc, sourceBtnId), destinationBtnId)
    }
  }

  // Saving backup to profile.

  saveLocalAccountSettings(FOOTBALL_NY2021_BACKUP_SAVE_ID, {
    datetime = get_charserver_time_sec()
    original = original.map(@(v) ::save_to_json(v))
    modified = modified.map(@(v) ::save_to_json(v))
  })
  if (loadLocalAccountSettings(FOOTBALL_NY2021_BACKUP_SAVE_ID) == null)
    return false // This case shouldn't happen. But we won't modify anything without a backup.

  // Logging.

  log($"FoolballNy2021Hack: Modifying hotkeys:")
  foreach (hotkeyId, hc in original) {
    log($"  {hotkeyId}")
    log($"    from: {::save_to_json(hc)}")
    log($"    to:   {::save_to_json(modified[hotkeyId])}")
  }

  // Modifying the preset.

  foreach (hotkeyId, hc in modified)
    preset.setHotkey(hotkeyId, hc)
  ::g_controls_manager.commitControls()
  forceSaveProfile()

  log($"FoolballNy2021Hack: Done")
  return true
}

//==============================================================================

function tryControlsRestore() {
  if (!shouldManageControls())
    return false

  let blk = loadLocalAccountSettings(FOOTBALL_NY2021_BACKUP_SAVE_ID)
  if (!u.isDataBlock(blk))
    return false // Nothing to restore.

  let preset = ::g_controls_manager.getCurPreset()
  let data = convertBlk(blk)

  log($"FoolballNy2021Hack: Restoring hotkeys from backup:")
  debugTableData(data, 10)

  let original = data?.original.map(@(s) parse_json(s)) ?? {}
  let modified = data?.modified.map(@(s) parse_json(s)) ?? {}

  if (original.len() == modified.len()) {
    foreach (hotkeyId, hc in original) {
      let curHc = preset.getHotkey(hotkeyId)
      let expectedHc = modified?[hotkeyId] ?? []
      if (u.isEqual(curHc, expectedHc) || (isHotkeyEmpty(curHc) && isHotkeyEmpty(expectedHc))) {
        preset.setHotkey(hotkeyId, hc)
        log($"  OK   {hotkeyId}")
      }
      else
        log($"  SKIP {hotkeyId}, current state is different: {::save_to_json(curHc)}")
    }
    ::g_controls_manager.commitControls()
  }

  saveLocalAccountSettings(FOOTBALL_NY2021_BACKUP_SAVE_ID, null) // Deleting backup.
  forceSaveProfile()

  log($"FoolballNy2021Hack: Done")
  return true
}

//==============================================================================

addListenersWithoutEnv({
  MissionStarted = @(_p) tryControlsOverride()
  SessionDestroyed = @(_p) tryControlsRestore()
  ProfileReceived = @(_p) tryControlsRestore()
})
