from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

let Warpoints = class (ItemCouponBase) {
  static iType = itemType.WARPOINTS
  static name = "Warpoints"
  static typeIcon = "#ui/gameuiskin#item_type_warpoints.svg"

  getWarpoints         = @() this.metaBlk?.warpoints ?? 0
  canConsume           = @() this.isInventoryItem && this.getWarpoints() > 0

  function getPrizeDescription(count, _colored = true) {
    if (!this.shouldAutoConsume)
      return null
    let wp = this.getWarpoints()
    if (wp == 0)
      return null
    return count * wp //prize already has type icon, so we no need 2 warpoints icons near amount number
  }
}
return {Warpoints}