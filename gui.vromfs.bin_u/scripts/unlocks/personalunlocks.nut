//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockExpired, canOpenUnlockManually, isUnlockOpened
} = require("%scripts/unlocks/unlocksModule.nut")
let manualUnlocksSeenList = require("%scripts/seen/seenList.nut").get(SEEN.MANUAL_UNLOCKS)

let markerUnlocks = persist("markerUnlocksCache", @() [])
let manualUnlocks = persist("manualUnlocksCache", @() [])
let isCacheValid = persist("isPersonalUnlocksCacheValid", @() { value = false })

let function cache() {
  if (isCacheValid.value || !::g_login.isLoggedIn())
    return

  foreach (unlockBlk in getAllUnlocksWithBlkOrder()) {
    if (unlockBlk?.shouldMarkUnits
        && !isUnlockOpened(unlockBlk.id)
        && !isUnlockExpired(unlockBlk))
      markerUnlocks.append(unlockBlk)

    if (canOpenUnlockManually(unlockBlk))
      manualUnlocks.append(unlockBlk)
  }

  isCacheValid.value = true
}

let function getMarkerUnlocks() {
  cache()
  return markerUnlocks
}

let function getManualUnlocks() {
  cache()
  return manualUnlocks
}

let function invalidateCache() {
  if (!isCacheValid.value)
    return

  markerUnlocks.clear()
  manualUnlocks.clear()
  isCacheValid.value = false

  manualUnlocksSeenList.onListChanged()
}

manualUnlocksSeenList.setListGetter(@() getManualUnlocks().map(@(u) u.id))

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getMarkerUnlocks
  getManualUnlocks
}