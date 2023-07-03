//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Attachable <- class extends ItemCouponBase {
  static iType = itemType.ATTACHABLE
  static typeIcon = "#ui/gameuiskin#item_type_attachable.svg"
  static descHeaderLocId = "coupon/for/attachable"

  getDecorator = @() getDecoratorByResource(this.metaBlk?.resource, this.metaBlk?.resourceType)

  canConsume = @() this.isInventoryItem ? (this.getDecorator() && !this.getDecorator().isUnlocked()) : false
  canPreview = @() this.getDecorator() ? this.getDecorator().canPreview() : false
  doPreview  = @() this.getDecorator() && this.getDecorator().doPreview()
}