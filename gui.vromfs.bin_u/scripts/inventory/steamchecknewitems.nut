//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { requestAllItems } = require("%scripts/inventory/steamInventory.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let logS = log_with_prefix("[Steam Items] ")

let steamNewItems = persist("steamNewItems", @() Watched([]))
wlog(steamNewItems, "[Steam Items]: newitems ")
let unknownSteamNewItems = persist("unknownSteamNewItems", @() Watched({}))
wlog(unknownSteamNewItems, "[Steam Items]: unknownSteamNewItems ")
let inqueueSteamItems = persist("inqueueSteamItems", @() Watched({}))
wlog(inqueueSteamItems, "[Steam Items]: inqueueSteamItems ")


let showSteamItemNotification = function(itemInfo) {
  let { item, steamItemId } = itemInfo
  ::showUnlockWnd({
    name = item.getName(false)
    desc = item.getLongDescription()
    popupImage = item.getIconName()
    ratioHeight = 1.0
    onDestroyFunc = function() {
      inqueueSteamItems.mutate(@(v) delete v[steamItemId])
      ExchangeRecipes.tryUse(item.getRelatedRecipes(), item, { shouldSkipMsgBox = true })
    }
    okBtnText = loc("items/getReward")
    okBtnStyle = "secondary"
  })
}

let function tryShowSteamItemsNotification(items = []) {
  if (!::isInMenu() || ::checkIsInQueue())
    return

  items.each(function(itemInfo) {
    inqueueSteamItems.mutate(@(v) v[itemInfo.steamItemId] <- true)
    showSteamItemNotification(itemInfo)
  })
  steamNewItems.update([])
}

let function tryShowSteamItemsNotificationOnUpdate(items = []) {
  let newItems = items
  let handler = ::handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (handler?.isValid() && handlerClass == ::gui_handlers.MainMenu)
    handler.doWhenActive(@() tryShowSteamItemsNotification(newItems))
}

let function steamCheckNewItems() {
  let newItems = []
  foreach (sItem in steamNewItems.value) {
    let steamItem = sItem
    let item = ::ItemsManager.getInventoryItemById(steamItem.itemDef)
    if (!item) {
      if (steamItem.itemDef not in unknownSteamNewItems.value)
        unknownSteamNewItems.mutate(@(v) v[steamItem.itemDef] <- steamItem)
      logS($"Not found inventory item by steam itemDef {steamItem.itemDef}", steamItem)
      continue
    }

    if (steamItem.itemId in inqueueSteamItems.value) {
      logS($"Try to show duplicate {steamItem.itemDef}. Ignore")
      continue
    }

    newItems.append({
      steamItemId = steamItem.itemId
      item
    })
  }

  tryShowSteamItemsNotificationOnUpdate(newItems)
}

let function requestRewardsAndCheckSteamInventory() {
  requestAllItems(function(res) {
    steamNewItems.update(res?.items ?? [])
    steamCheckNewItems()
  })
}

let function checkUnknownItems() {
  if (unknownSteamNewItems.value.len() == 0)
    return

  logS("Check unknown items", unknownSteamNewItems.value)
  let knownItems = []
  foreach (itemDef, sItem in unknownSteamNewItems.value) {
    if (::ItemsManager.findItemById(itemDef)) {
      knownItems.append(sItem)
      let itemDefId = itemDef
      unknownSteamNewItems.mutate(@(v) delete v[itemDefId])
    }
  }

  logS("Left unknown items", unknownSteamNewItems.value)
  if (!knownItems.len())
    return

  steamNewItems.update(knownItems)
  steamCheckNewItems()
}

addListenersWithoutEnv({
  LoginComplete = @(_) requestRewardsAndCheckSteamInventory()
  ItemsShopUpdate = @(_) checkUnknownItems()
  SignOut = @(_) inqueueSteamItems({})
})

return {
  steamCheckNewItems
}