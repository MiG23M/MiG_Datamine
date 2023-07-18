//checked for plus_string
from "%scripts/dagui_library.nut" import *

let canRestartClient = @() !(::is_in_loading_screen() || ::SessionLobby.isInRoom())

let function applyRestartClient() {

  if (!canRestartClient()) {
    ::showInfoMsgBox(loc("msgbox/client_restart_rejected"), "sysopt_restart_rejected")
    return
  }

  log("[sysopt] Restarting client.")
  ::save_profile(false)
  ::save_short_token()
  ::restart_game(false)
}

return {
  applyRestartClient
  canRestartClient
}
