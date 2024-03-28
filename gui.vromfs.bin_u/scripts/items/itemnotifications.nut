from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType

let workshop = require("%scripts/items/workshop/workshop.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let DataBlock  = require("DataBlock")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { gui_start_items_list } = require("%scripts/items/startItemsShop.nut")

let ITEMS_FOR_OFFER_BUY_SAVE_ID = "itemsListForOfferBuy"

let addItemsInOfferBuyList = function() {
  let itemsList = ::ItemsManager.getInventoryList(itemType.ALL,
    @(i) i.needOfferBuyAtExpiration() && i.getAmount() > 0)

  if (!itemsList.len())
    return

  local hasChanges = false
  let needOfferBuyItemsList = loadLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID, DataBlock())
  foreach (item in itemsList) {
    let idString = (item.id).tostring()
    if (needOfferBuyItemsList?[idString])
      continue

    needOfferBuyItemsList[idString] = true
    hasChanges = true
  }

  if (hasChanges)
    saveLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
}

let checkOfferToBuyAtExpiration = function() {
  if (!isInMenu())
    return

  if (!::g_login.isProfileReceived())
    return
  local needOfferBuyItemsList = loadLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID)
  if (!needOfferBuyItemsList)
    return

  local hasChanges = false
  foreach (itemId, _value in needOfferBuyItemsList) {
    let id = to_integer_safe(itemId, itemId, false)
    let inventoryItem = ::ItemsManager.getInventoryItemById(id)
    let shopItem = ::ItemsManager.findItemById(id)
    if (inventoryItem && !inventoryItem.isExpired())
      continue

    if (!shopItem || !shopItem.isCanBuy() || !shopItem.needOfferBuyAtExpiration()) {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    let wSet = workshop.getSetByItemId(shopItem.id)
    if (!wSet || !wSet.isVisible()) {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    scene_msg_box("offer_buy_item", null,
      loc("msgBox/offerToBuyAtExpiration", { itemName = shopItem.getName() }),
        [
          ["yes", @() gui_start_items_list(itemsTab.WORKSHOP,
            { curSheet = { id = wSet.getShopTabId() }
              curItem  = shopItem
              initSubsetId = wSet.getSubsetIdByItemId(shopItem.id)
            })],
          ["no", @() null ]
        ], "yes", { cancel_fn = function() {} })

     hasChanges = true
     needOfferBuyItemsList[itemId] = null
     break
  }

  if (hasChanges) {
    if (needOfferBuyItemsList.paramCount() == 0)
      needOfferBuyItemsList = null
    saveLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
  }
}

add_event_listener("InventoryUpdate", function(_p) {
  checkOfferToBuyAtExpiration()
  addItemsInOfferBuyList()
})

return {
  checkOfferToBuyAtExpiration = checkOfferToBuyAtExpiration
}
