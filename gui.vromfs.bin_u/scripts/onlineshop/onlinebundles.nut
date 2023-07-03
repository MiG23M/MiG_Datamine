//checked for plus_string
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { ps4RegionName, isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { GUI } = require("%scripts/utils/configs.nut")

let cache = persist("cache", @() {})
let function clearCache() {
  cache.clear()
  foreach (id in ["guid", "xbox", ps4RegionName(), "epic"]) {
    cache[id] <- {}
    cache[$"inv_{id}"] <- {}
  }
}
clearCache()

let function getBundlesList(blockName) {
  if (!cache[blockName].len()) {
    if (!(blockName in cache)) {
      ::script_net_assert_once($"not exist bundles block {blockName} in cache", $"Don't exist requested bundles block {blockName} in cache")
      return ""
    }

    let guiBlk = GUI.get()?.bundles
    if (!guiBlk)
      return ""

    cache[blockName] = ::buildTableFromBlk(guiBlk[blockName])
  }

  return cache[blockName]
}

let function getCachedBundleId(blockName, entName) {
  let list = getBundlesList(blockName)
  let res = list?[entName] ?? ""
  log($"Bundles: get id from block '{blockName}' by bundle '{entName}' = {res}")
  return res
}

let function getCachedEntitlementId(blockName, bundleName) {
  if (!bundleName || bundleName == "")
    return ""

  let invBlockName = $"inv_{blockName}"

  if (!(bundleName in cache[invBlockName])) {
    cache[invBlockName][bundleName] <- ""
    let list = getBundlesList(blockName)
    foreach (entId, bndlId in list)
      if (bndlId == bundleName) {
        cache[invBlockName][bundleName] = entId
        break
      }
  }

  return cache[invBlockName][bundleName]
}

subscriptions.addListenersWithoutEnv({
  ScriptsReloaded = @(_p) clearCache()
  SignOut = @(_p) clearCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

let getBundlesBlockName = @() isPlatformSony ? ps4RegionName()
  : isPlatformXboxOne ? "xbox"
  : ::epic_is_running() ? "epic"
  : "guid"

return {
  getBundlesBlockName
  getBundleId = @(name) getCachedBundleId(getBundlesBlockName(), name)
  getEntitlementId = @(name) getCachedEntitlementId(getBundlesBlockName(), name)
}