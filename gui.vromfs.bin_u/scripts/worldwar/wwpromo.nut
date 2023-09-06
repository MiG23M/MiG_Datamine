//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { setPromoButtonText, isPromoCollapsed, togglePromoItem, getShowAllPromoBlocks
} = require("%scripts/promo/promo.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { getTextWithCrossplayIcon, needShowCrossPlayInfo } = require("%scripts/social/crossplay.nut")

let function getWorldWarPromoText(isWwEnabled = null) {
  local text = loc("mainmenu/btnWorldwar")
  if (!::is_worldwar_enabled())
    return text

  if ((isWwEnabled ?? ::g_world_war.canJoinWorldwarBattle())) {
    let operationText = ::g_world_war.getPlayedOperationText(false)
    if (operationText != "")
      text = operationText
  }

  text = getTextWithCrossplayIcon(needShowCrossPlayInfo(), text)
  return "{0} {1}".subst(loc("icon/worldWar"), text)
}

addPromoAction("world_war", @(_handler, params, _obj) ::g_world_war.openMainWnd(params?[0] == "openMainMenu"))

let promoButtonId = "world_war_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = getWorldWarPromoText
  collapsedIcon = loc("icon/worldWar")
  needUpdateByTimer = true
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let isWwEnabled = ::g_world_war.canJoinWorldwarBattle()
    let isVisible = getShowAllPromoBlocks()
      || (isWwEnabled && ::g_world_war.isWWSeasonActive())

    let buttonObj = showObjById(id, isVisible, this.scene)
    if (!isVisible || !checkObj(buttonObj))
      return

    setPromoButtonText(buttonObj, id, getWorldWarPromoText(isWwEnabled))

    if ((!::should_disable_menu() && !::g_login.isProfileReceived()) || !isPromoCollapsed(id))
      return

    if (::g_world_war.hasNewNearestAvailableMapToBattle())
      togglePromoItem(buttonObj.findObject(id + "_toggle"))
  }
  updateByEvents = ["WWLoadOperation", "WWStopWorldWar",
    "WWGlobalStatusChanged", "CrossPlayOptionChanged"]
})
