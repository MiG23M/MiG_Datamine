//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { getPollIdByFullUrl, invalidateTokensCache } = require("%scripts/web/webpoll.nut")
let { validateLink, openUrl } = require("%scripts/onlineShop/url.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")

let function openLinkWithSource(params = [], source = "promo_open_link") {
  local link = ""
  local forceBrowser = false
  if (u.isString(params))
    link = params
  else if (u.isArray(params) && params.len() > 0) {
    link = params[0]
    forceBrowser = params?[1] ?? false
  }

  let processedLink = validateLink(link)
  if (processedLink == null)
    return
  openUrl(processedLink, forceBrowser, false, source)
}

addPromoAction("url", function(_handler, params, _obj) {
  let pollId = getPollIdByFullUrl(params?[0] ?? "")
  if (pollId != null)
    invalidateTokensCache(pollId.tointeger())
  return openLinkWithSource(params)
})

addPromoButtonConfig({
  promoButtonId = "web_poll"
  collapsedIcon = loc("icon/web_poll")
})

return {
  openLinkWithSource
}

