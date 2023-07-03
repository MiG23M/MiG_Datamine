//checked for plus_string

from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getDecoratorDataToUse, useDecorator } = require("%scripts/customization/contentPreview.nut")
let { getUnlockTypeText } = require("%scripts/unlocks/unlocksViewModule.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let { register_command } = require("console")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

register_command(
  function () {
    let unlocksRewards = {
      hidden_tank_5_rank_purchased_britain = true
      cardicon_ger_modern_01 = true
      title_faithful_warrior = true
      title_the_old_guard = true
      title_combat_proven = true
      title_brother_in_arms = true
      simple_01 = true
    }
    ::handlersManager.loadHandler(::gui_handlers.UnlockRewardWnd, { unlocksRewards })
    return
  },
  "ui.debug_unlocks_reward")

::gui_handlers.UnlockRewardWnd <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/trophyReward.blk"
  unlocksRewards = null
  unlocks = []
  shrinkedUnlocks = []
  animFinished = false
  opened = false
  decorator = null
  decoratorUnit = null
  decoratorSlot = -1

  function initScreen() {
    this.processConfigsArray()
    this.checkConfigsArray()
    this.setTitle()
    this.updateWnd()
    this.startOpening()
    this.scene.findObject("update_timer").setUserData(this)
  }

  function getTitle() {
    if (this.unlocks.len() == 1)
      return getUnlockTypeText(this.unlocks[0].type, this.unlocks[0].id)

    return loc("unlocks/achievement")
  }

  function processConfigsArray() {
    this.unlocks.clear()
    this.shrinkedUnlocks.clear()
    foreach (unlockId, _ in this.unlocksRewards) {
      let config = getUnlockById(unlockId)
      if (!config)
        continue
      let unlockConditions = ::build_conditions_config(config)
      let unlock = ::build_log_unlock_data(unlockConditions)
      this.unlocks.append(unlock)

      let shrinkedUnlock = {}
      foreach (key, value in unlock) {
        if (key == "id")
          shrinkedUnlock["unlock"] <- value
        else if (key == "amount")
          shrinkedUnlock["count"] <- value
      }
      this.shrinkedUnlocks.append(shrinkedUnlock)
    }
  }

  function checkConfigsArray() {
    let decors = []

    foreach (unlock in this.unlocks) {
      let unlockType = ::g_unlock_view.getUnlockType(unlock)
      if (unlockType == UNLOCKABLE_DECAL
        || unlockType == UNLOCKABLE_SKIN
        || unlockType == UNLOCKABLE_ATTACHABLE)
        decors.append({ unlockId = unlock.id unlockType = unlockType })
    }

    if (decors.len() == 1)
      this.updateResourceData(decors[0].unlockId, decors[0].unlockType)
  }

  function updateResourceData(resource, resourceType) {
    let decorData = getDecoratorDataToUse(resource, resourceType)
    if (decorData.decorator == null)
      return

    this.decorator = decorData.decorator
    this.decoratorUnit = decorData.decoratorUnit
    this.decoratorSlot = decorData.decoratorSlot
    let obj = this.scene.findObject("btn_use_decorator")
    if (obj?.isValid()) {
      obj.setValue(loc($"decorator/use/{this.decorator.decoratorType.resourceType}"))
      this.showSceneBtn("btn_use_decorator", true)
    }
  }

  onTakeNavBar = @() null

  function setTitle() {
    let title = this.getTitle()

    let titleObj = this.scene.findObject("reward_title")
    titleObj.setValue(title)
    if (daguiFonts.getStringWidthPx(title, "fontMedium", this.guiScene) >
      to_pixels("1@trophyWndWidth - 1@buttonCloseHeight"))
      titleObj.caption = "no"
  }

  function startOpening() {
    ::showBtn("reward_roullete", false, this.scene)
    let animObj = this.scene.findObject("open_chest_animation")
    if (checkObj(animObj)) {
      animObj.animation = "show"
      this.guiScene.playSound("chest_open")
      let delay = ::to_integer_safe(animObj?.chestReplaceDelay, 0)
      ::Timer(animObj, 0.001 * delay, this.openChest, this)
      ::Timer(animObj, 1.0, this.onOpenAnimFinish, this)
    }
    else
      this.openChest()
  }

  function openChest() {
    if (this.opened)
      return false

    this.opened = true
    this.updateWnd()
    return true
  }

  function updateWnd() {
    this.updateUnlockImages()
    this.updateRewardText()
    this.updateRewardPostscript()
    this.updateButtons()
  }

  function updateUnlockImages() {
    let imageObjPlace = this.scene.findObject("reward_image_place")
    if (!checkObj(imageObjPlace))
      return

    imageObjPlace.show(true)

    let layersData = this.getRewardImage()
    this.guiScene.replaceContentFromText(imageObjPlace, layersData, layersData.len(), this)
  }

  function updateRewardPostscript() {
    if (!this.opened)
      return

    let countNotVisibleItems = this.shrinkedUnlocks.len() - ::trophyReward.maxRewardsShow

    if (countNotVisibleItems < 1)
      return

    let obj = this.scene.findObject("reward_postscript")
    if (!checkObj(obj))
      return

    obj.setValue(loc("trophy/moreRewards", { num = countNotVisibleItems }))
  }

  function updateRewardText() {
    if (!this.opened)
      return

    let obj = this.scene.findObject("prize_desc_div")
    if (!checkObj(obj))
      return

    let data = ::trophyReward.getRewardsListViewData(this.shrinkedUnlocks,
      { multiAwardHeader = true
        widthByParentParent = true
        header = loc("mainmenu/you_received")
      })
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function getRewardImage() {
    local layersData = ""
    let show_count = min(::trophyReward.maxRewardsShow, this.unlocks.len())
    for (local i = 0; i < show_count; i++)
      layersData += this.getImageLayer(this.unlocks[i], this.shrinkedUnlocks[i])

    if (layersData == "")
      return ""

    let layerCfg = LayersIcon.findLayerCfg("item_place_container")
    let res = LayersIcon.genDataFromLayer(layerCfg, layersData)
    return res
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return
    let isShowRewardListBtn = this.opened && (this.unlocks.len() > 1) && this.animFinished
    local btnObj = this.showSceneBtn("btn_rewards_list", isShowRewardListBtn)
    if (isShowRewardListBtn)
      btnObj.setValue(loc("mainmenu/rewardsList"))
    this.showSceneBtn("open_chest_animation", !this.animFinished)
    this.showSceneBtn("btn_ok", this.animFinished)
    this.showSceneBtn("btn_back", this.animFinished)
  }

  function onViewRewards() {
    if (this.unlocks.len() <= 1)
      return
    ::gui_start_open_trophy_rewards_list({ rewardsArray = this.shrinkedUnlocks,
      titleLocId = "mainmenu/rewardsList" })
  }

  function onOpenAnimFinish() {
    this.animFinished = true
    if (!this.openChest())
      this.updateButtons()
  }

  onTimer = @(_obj, _dt) this.updateButtons()
  onUseDecorator = @() useDecorator(this.decorator, this.decoratorUnit, this.decoratorSlot)
  onPreloaderSettings = @() null
  onReUseItem = @() null
  onRunCustomMission = @() null
  onGoToItem = @() null
  onPreviewDecorator = @() null

  function getImageLayer(unlock, config) {
    let imageLayer = LayersIcon.getIconData(unlock?.iconStyle ?? "", unlock?.descrImage ?? "")
    let tooltipConfig = ::PrizesView.getPrizeTooltipConfig(config)

    return handyman.renderCached(("%gui/items/item.tpl"), { items = [tooltipConfig.__update({
      layered_image = imageLayer,
      hasFocusBorder = true })] })
  }
}

return {
  showUnlocks = function(unlocksRewards) {
    if (unlocksRewards.len() == 0)
      return
    ::handlersManager.loadHandler(::gui_handlers.UnlockRewardWnd, { unlocksRewards })
  }
}