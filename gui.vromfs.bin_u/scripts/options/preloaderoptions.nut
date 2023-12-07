//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCurLoadingBgData } = require("%scripts/loading/loadingBgData.nut")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

const BANNED_SCREENS_SAVE_ID = "preloaderOptions/bannedScreens"

local bannedScreens = {}
local isInited = false

let function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
    return

  isInited = true

  let blk = loadLocalAccountSettings(BANNED_SCREENS_SAVE_ID, null)
  if (!isDataBlock(blk))
    return

  bannedScreens = convertBlk(blk)

  // validation
  foreach (screenId, _w in getCurLoadingBgData().list)
    if (screenId not in bannedScreens)
      return

  bannedScreens.$rawdelete(getCurLoadingBgData().reserveBg)
  saveLocalAccountSettings(BANNED_SCREENS_SAVE_ID, bannedScreens)
}

let function invalidateCache() {
  bannedScreens.clear()
  isInited = false
}

let function toggleLoadingScreenBan(screenId) {
  initOnce()
  if (!isInited)
    return

  if (screenId in bannedScreens)
    bannedScreens.$rawdelete(screenId)
  else
    bannedScreens[screenId] <- true

  saveLocalAccountSettings(BANNED_SCREENS_SAVE_ID, bannedScreens)
}

let function isLoadingScreenBanned(screenId) {
  initOnce()
  return screenId in bannedScreens
}

addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
  GameLocalizationChanged = @(_p) invalidateCache()
})

return {
  isLoadingScreenBanned
  toggleLoadingScreenBan
}