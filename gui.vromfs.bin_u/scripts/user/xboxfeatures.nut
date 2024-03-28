from "%scripts/dagui_library.nut" import *

let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { crossNetworkPlayStatus } = require("%scripts/social/crossplay.nut")
let { check_crossnetwork_play_privilege, check_multiplayer_sessions_privilege } = require("%scripts/xbox/permissions.nut")
let { crossnetworkPrivilege } = require("%scripts/xbox/crossnetwork.nut")

let isMultiplayerPrivilegeAvailable = mkWatched(persist, "isMultiplayerPrivilegeAvailable", true)

local multiplayerPrivelegeCallback = null
local crossplayPrivelegeCallback = null


function multiplayer_sessions_privilege_callback(is_allowed) {
  isMultiplayerPrivilegeAvailable(is_allowed)

  if (is_allowed)
    multiplayerPrivelegeCallback?()

  multiplayerPrivelegeCallback = null

  if (!::g_login.isLoggedIn())
    return

  broadcastEvent("XboxMultiplayerPrivilegeUpdated")
}


function checkMultiplayerPrivilege(showWarning = false, cb = null) {
  if (!isPlatformXboxOne) {
    cb?()
    return
  }

  multiplayerPrivelegeCallback = cb
  check_multiplayer_sessions_privilege(showWarning, multiplayer_sessions_privilege_callback)
}


function crossnetwork_play_privilege_callback(is_allowed) {
  if (isPlatformXboxOne) //callback returns actual updated state
    crossNetworkPlayStatus(is_allowed)

  if (!is_allowed && !isPlatformXboxOne) //Xbox code will show warning message if isAllowed = false
    crossplayPrivelegeCallback?()

  crossplayPrivelegeCallback = null
}


function checkAndShowCrossplayWarning(cb = null, showWarning = true) {
  crossplayPrivelegeCallback = cb

  if (isPlatformXboxOne)
    check_crossnetwork_play_privilege(showWarning, crossnetwork_play_privilege_callback)
  else
    crossnetwork_play_privilege_callback(false) //Default value in code
}


crossnetworkPrivilege.subscribe(function(v) {
  crossNetworkPlayStatus(v)
})


return {
  isMultiplayerPrivilegeAvailable
  checkAndShowMultiplayerPrivilegeWarning = @(cb = null) checkMultiplayerPrivilege(true, cb)
  resetMultiplayerPrivilege = @() isMultiplayerPrivilegeAvailable(true)
  updateMultiplayerPrivilege = function() {
    if (!::g_login.isLoggedIn())
      return

    checkMultiplayerPrivilege()
  }

  checkAndShowCrossplayWarning
}