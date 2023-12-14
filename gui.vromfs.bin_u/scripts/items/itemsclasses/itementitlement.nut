from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { getEntitlementConfig, getEntitlementName,
  getEntitlementDescription } = require("%scripts/onlineShop/entitlements.nut")

let Entitlement = class (ItemCouponBase) {
  static name = "Entitlement"
  static iType = itemType.ENTITLEMENT
  static typeIcon = "#ui/gameuiskin#item_type_premium.svg"

  getEntitlement = @() this.metaBlk?.entitlement
  canConsume = @() this.isInventoryItem && this.getEntitlement() != null
  showAsContentItem = @() this.itemDef?.tags?.showAsContentItem ?? false
  getConfig = @() getEntitlementConfig(this.getEntitlement())

  getName = @(colored = true) this.showAsContentItem() ? getEntitlementName(this.getConfig())
    : base.getName(colored)

  getDescription = @() this.showAsContentItem() ? getEntitlementDescription(this.getConfig(), this.getEntitlement())
    : base.getDescription()

  getBigIcon = @() this.getIcon()

  function getIcon(addItemName = true) {
    return this.showAsContentItem()
      ? LayersIcon.getIconData(null, this.typeIcon)
      : base.getIcon(addItemName)
  }
}

return {Entitlement}