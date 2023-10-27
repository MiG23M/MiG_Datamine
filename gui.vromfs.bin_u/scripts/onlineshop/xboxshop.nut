//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
require("%scripts/onlineShop/ingameConsoleStore.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
let shopData = require("%scripts/onlineShop/xboxShopData.nut")
let statsd = require("statsd")
let xboxSetPurchCb = require("%scripts/onlineShop/xboxPurchaseCallback.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { isPlayerRecommendedEmailRegistration } = require("%scripts/user/playerCountry.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { showPcStorePromo } = require("%scripts/user/pcStorePromo.nut")
let { show_marketplace, ProductKind } = require("%xboxLib/impl/store.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")

let sheetsArray = []
shopData.xboxProceedItems.subscribe(function(val) {
  sheetsArray.clear()

  if (xboxMediaItemType.GameConsumable in val)
    sheetsArray.append({
      id = "xbox_game_consumation"
      locId = "itemTypes/xboxGameConsumation"
      getSeenId = @() $"##xbox_item_sheet_{xboxMediaItemType.GameConsumable}"
      categoryId = xboxMediaItemType.GameConsumable
      sortParams = [
        { param = "price", asc = false }
        { param = "price", asc = true }
      ]
      sortSubParam = "consumableQuantity"
      contentTypes = ["eagles"]
    })

  if (xboxMediaItemType.GameContent in val)
    sheetsArray.append({
      id = "xbox_game_content"
      locId = "itemTypes/xboxGameContent"
      getSeenId = @() $"##xbox_item_sheet_{xboxMediaItemType.GameContent}"
      categoryId = xboxMediaItemType.GameContent
      sortParams = [
        { param = "releaseDate", asc = false }
        { param = "releaseDate", asc = true }
        { param = "price", asc = false }
        { param = "price", asc = true }
        { param = "isBought", asc = false }
        { param = "isBought", asc = true }
      ]
      sortSubParam = "name"
      contentTypes = [null, ""]
    })

  unitTypes.types.each(function(unitType) {
    if (!(unitType.typeName in val))
      return

    sheetsArray.append({
      id = $"xbox_game_content_{unitType.typeName}"
      locId = unitType.getArmyLocId()
      getSeenId = @() $"##xbox_item_sheet_{unitType.typeName}"
      categoryId = unitType.typeName
      sortParams = [
        { param = "releaseDate", asc = false }
        { param = "releaseDate", asc = true }
        { param = "price", asc = false }
        { param = "price", asc = true }
        { param = "isBought", asc = false }
        { param = "isBought", asc = true }
      ]
      sortSubParam = "name"
      contentTypes = [null, ""]
    })
  })

  foreach (_idx, sh in sheetsArray) {
    let sheet = sh
    seenList.setSubListGetter(sheet.getSeenId(), @()
      (val?[sheet.categoryId] ?? [])
      .filter(@(it) !it.canBeUnseen())
      .map(@(it) it.getSeenId())
    )
  }
})

gui_handlers.XboxShop <- class extends gui_handlers.IngameConsoleStore {
  function loadCurSheetItemsList() {
    this.itemsList = this.itemsCatalog?[this.curSheet?.categoryId] ?? []
  }

  function onEventXboxSystemUIReturn(_p) {
    if (isPlayerRecommendedEmailRegistration())
      showPcStorePromo()

    this.curItem = this.getCurItem()
    if (!this.curItem)
      return

    let wasItemBought = this.curItem.isBought
    this.curItem.updateIsBoughtStatus(Callback(function(success) {

      let wasPurchasePerformed = success && (wasItemBought != this.curItem.isBought)

      if (wasPurchasePerformed) {
        broadcastEvent("EntitlementStoreItemPurchased", { id = this.curItem.id })
        statsd.send_counter("sq.close_product.purchased", 1)
        sendBqEvent("CLIENT_POPUP_1", "close_product", {
          itemId = this.curItem.id,
          action = "purchased"
        })
        ::g_tasker.addTask(::update_entitlements_limited(),
          {
            showProgressBox = true
            progressBoxText = loc("charServer/checking")
          },
          Callback(function() {
            this.updateSorting()
            this.fillItemsList()
            ::g_discount.updateOnlineShopDiscounts()

            if (this.curItem.isMultiConsumable || wasPurchasePerformed)
              ::update_gamercards()
          }, this)
        )
      }

    }, this))
  }

  function goBack() {
    ::g_tasker.addTask(::update_entitlements_limited(),
      {
        showProgressBox = true
        progressBoxText = loc("charServer/checking")
      },
      Callback(function() {
        ::g_discount.updateOnlineShopDiscounts()
        ::update_gamercards()
      })
    )

    base.goBack()
  }
}

let isChapterSuitable = @(chapter) isInArray(chapter, [null, "", "eagles"])
let getEntStoreLocId = @() shopData.canUseIngameShop() ? "#topmenu/xboxIngameShop" : "#msgbox/btn_onlineShop"

let openIngameStoreImpl = kwarg(
  function(chapter = null, curItemId = "", afterCloseFunc = null, statsdMetric = "unknown",
    forceExternalShop = false, unitName = "") {
    if (!isChapterSuitable(chapter))
      return false

    if (shopData.canUseIngameShop() && !forceExternalShop) {
      shopData.requestData(
        false,
        function() {
          let curItem = shopData.getShopItem(curItemId)
          local curSheetId = null
          if (curItem?.categoriesList) {
            let unitTypeName = getAircraftByName(unitName).unitType.typeName
            curSheetId = curItem.categoriesList.contains(unitTypeName) ? unitTypeName
              : curItem.categoriesList?[0]

            log($"XBOX SHOP: Found sheet {curSheetId} for unit {unitName}. Item {curItem?.id}, {curItem?.entitlementId}")
          }

          handlersManager.loadHandler(gui_handlers.XboxShop, {
            itemsCatalog = shopData.xboxProceedItems.value
            chapter = chapter
            curItem
            curSheetId
            afterCloseFunc
            titleLocId = "topmenu/xboxIngameShop"
            storeLocId = "items/openIn/XboxStore"
            seenEnumId = SEEN.EXT_XBOX_SHOP
            seenList
            sheetsArray
          }) },
        true,
        statsdMetric
      )
      return true
    }

    ::queues.checkAndStart(Callback(function() {
      xboxSetPurchCb(afterCloseFunc)
      get_gui_scene().performDelayed(getroottable(),
        function() {
          local curItem = shopData.getShopItem(curItemId)
          if (curItem)
            curItem.showDetails(statsdMetric)
          else {
            let productKind = (chapter == "eagles") ? ProductKind.Consumable : ProductKind.Durable
            show_marketplace(productKind, null)
          }
        }
      )
    }, this), null, "isCanUseOnlineShop")

    return true
  }
)

let function openIngameStore(params = {}) {
  if (isChapterSuitable(params?.chapter)
    && getLanguageName() == "Russian"
    && isPlayerRecommendedEmailRegistration()) {
    sendBqEvent("CLIENT_POPUP_1", "ingame_store_qr", { targetPlatform })
    openQrWindow({
      headerText = params?.chapter == "eagles" ? loc("charServer/chapter/eagles") : ""
      infoText = loc("eagles/rechargeUrlNotification")
      baseUrl = "{0}{1}".subst(loc("url/recharge"), "&partner=QRLogin&partner_val=q37edt1l")
      needUrlWithQrRedirect = true
      needShowUrlLink = false
      buttons = [{
        shortcut = "Y"
        text = loc(getEntStoreLocId())
        onClick = "goBack"
      }]
      onEscapeCb = @() openIngameStoreImpl(params)
    })
    return true
  }

  return openIngameStoreImpl(params)
}

return shopData.__merge({
  openIngameStore = openIngameStore
  getEntStoreLocId = getEntStoreLocId
  getEntStoreIcon = @() shopData.canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !shopData.canUseIngameShop() || !::isInMenu()
  getEntStoreUnseenIcon = @() SEEN.EXT_XBOX_SHOP
  needEntStoreDiscountIcon = true
  openEntStoreTopMenuFunc = @(_obj, _handler) openIngameStore({ statsdMetric = "topmenu" })
})