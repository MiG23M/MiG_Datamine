//checked for plus_string
from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_CALLBACKS] ")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let {
  resetMultiplayerPrivilege,
  updateMultiplayerPrivilege
} = require("%scripts/user/xboxFeatures.nut")
let {logout} = require("%scripts/xbox/auth.nut")


let function onLogout() {
  logX("onLogout")
  logout(function() {
    logX("onLogout -> callback")
    resetMultiplayerPrivilege()
  })
}


let function onLoginComplete() {
  logX("onLoginComplete")
  updateMultiplayerPrivilege()
}


addListenersWithoutEnv({
  SignOut = @(_) onLogout()
  LoginComplete = @(_) onLoginComplete()
} ::g_listener_priority.CONFIG_VALIDATION)
