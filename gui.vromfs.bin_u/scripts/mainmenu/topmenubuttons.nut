//checked for plus_string
from "%scripts/dagui_library.nut" import *

let cache = { byId = {} }

let buttonsListWatch = Watched({})

let getButtonConfigById = function(id) {
  if (!(id in cache.byId)) {
    let buttonCfg = buttonsListWatch.value.findvalue(@(t) t.id == id)
    cache.byId[id] <- buttonCfg ?? buttonsListWatch.value.UNKNOWN
  }
  return cache.byId[id]
}

return {
  buttonsListWatch = buttonsListWatch
  getButtonConfigById = getButtonConfigById
}
