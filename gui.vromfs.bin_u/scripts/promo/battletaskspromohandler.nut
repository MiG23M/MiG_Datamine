//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { easyDailyTaskProgressWatchObj, mediumDailyTaskProgressWatchObj,
  leftSpecialTasksBoughtCountWatchObj
} = require("%scripts/battlePass/watchObjInfoConfig.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { copyParamsToTable } = require("%sqstd/datablock.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { getDifficultyTypeByTask, getDefaultDifficultyGroup
} = require("%scripts/unlocks/battleTaskDifficulty.nut")

::dagui_propid.add_name_id("task_id")
::dagui_propid.add_name_id("difficultyGroup")

::gui_handlers.BattleTasksPromoHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM

  sceneBlkName = "%gui/empty.blk"
  savePathBattleTasksDiff = "promo/battleTasksDiff"

  static function open(params) {
    ::handlersManager.loadHandler(::gui_handlers.BattleTasksPromoHandler, params)
  }

  function initScreen() {
    this.scene.setUserData(this)
    this.updateHandler()
  }

  function updateHandler() {
    let id = this.scene.id
    local difficultyGroupArray = []

    // 0) Prepare: Filter tasks array by available difficulties list
    let tasksArray = ::g_battle_tasks.getTasksArrayByIncreasingDifficulty()

    // 1) Search for task with available reward
    local reqTask = ::g_battle_tasks.getTaskWithAvailableAward(tasksArray)

    let currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    // 2) Search for task by selected gameMode
    if (!reqTask && currentGameModeId) {
      local curDifficultyGroup = ::load_local_account_settings(this.savePathBattleTasksDiff,
        getDefaultDifficultyGroup())
      let activeTasks = u.filter(::g_battle_tasks.filterTasksByGameModeId(tasksArray, currentGameModeId),
        @(task) !::g_battle_tasks.isTaskDone(task)
          && ::g_battle_tasks.isTaskActive(task)
          && (::g_battle_tasks.canGetReward(task) || !::g_battle_tasks.isTaskTimeExpired(task)))

              //get difficulty list
      difficultyGroupArray = this.getDifficultyRadioButtonsListByTasks(activeTasks,
        ::g_battle_tasks.getDifficultyTypeGroup(),
        curDifficultyGroup)
      if (difficultyGroupArray.len() == 1)
        curDifficultyGroup = difficultyGroupArray[0].difficultyGroup
      reqTask = u.search(activeTasks,
        @(task) (getDifficultyTypeByTask(task).getDifficultyGroup() == curDifficultyGroup))
    }

    let promoView = copyParamsToTable(::g_promo.getConfig()?[id])
    local view = {}

    if (reqTask) {
      let config = ::build_conditions_config(reqTask)
      ::build_unlock_desc(config)

      let itemView = ::g_battle_tasks.generateItemView(config, { isPromo = true })
      itemView.canReroll = false
      view = u.tablesCombine(itemView, promoView, function(val1, val2) { return val1 != null ? val1 : val2 })
      view.collapsedText <- ::g_promo.getCollapsedText(view, id)
    }
    else {
      promoView.id <- id
      view = ::g_battle_tasks.generateItemView(promoView, { isPromo = true })
      view.collapsedText <- ::g_promo.getCollapsedText(promoView, id)
      view.refreshTimer <- true
    }

    if (!(view.needShowProgressBar ?? false) && view.needShowProgressValue) {
      let progressValueText = loc("ui/parentheses/space",
        { text = "".concat(view.progressValue, "/", view.progressMaxValue) })
      view.collapsedText = $"{view.collapsedText}{progressValueText}"
    }
    let maxTextWidth = to_pixels("".concat("1@arrowButtonWidth-1@mIco-2@blockInterval",
      view.taskStatus != null ? "-1@modStatusHeight" : "",
      view.newIconWidget != null ? "-1@arrowButtonHeight" : ""))
    view.collapsedIcon <- ::g_promo.getCollapsedIcon(view, id)
    let iconSize = getStringWidthPx(view.collapsedIcon, "fontNormal", this.guiScene) + to_pixels("1@blockInterval")
    if (getStringWidthPx(view.collapsedText, "fontNormal", this.guiScene) > maxTextWidth - iconSize)
      view.shortInfoBlockWidth <- to_pixels("1@arrowButtonWidth-1@blockInterval")
    view.hasMarginCollapsedIcon <- view.collapsedText != "" && view.taskDifficultyImage != ""
    view.hasCollapsedText <- view.collapsedText != ""
    let taskHeaderCondition = view?.taskHeaderCondition ?? ""
    if (taskHeaderCondition != "")
      view.title = $"{view.title} {taskHeaderCondition}"
    if (getStringWidthPx(view.title, "fontNormal", this.guiScene) > maxTextWidth)
      view.headerWidth <- maxTextWidth
    view.performActionId <- ::g_promo.getActionParamsKey(id)
    view.taskId <- getTblValue("id", reqTask)
    view.action <- ::g_promo.PERFORM_ACTON_NAME


    view.isShowRadioButtons <- (difficultyGroupArray.len() > 1 && hasFeature("PromoBattleTasksRadioButtons"))
    view.radioButtons <- difficultyGroupArray
    view.otherTasksNumText <- view.otherTasksNum > 0 ? "#mainmenu/battleTasks/OtherTasksCount" : ""
    let isEmptyTask = view.taskId == null
    if (isEmptyTask) {
      view.easyDailyTaskProgressValue <- stashBhvValueConfig(easyDailyTaskProgressWatchObj)
      view.mediumDailyTaskProgressValue <- stashBhvValueConfig(mediumDailyTaskProgressWatchObj)
      if (::g_battle_tasks.canActivateHardTasks())
        view.leftSpecialTasksBoughtCountValue <- stashBhvValueConfig(leftSpecialTasksBoughtCountWatchObj)
    }

    let data = handyman.renderCached("%gui/promo/promoBattleTasks.tpl",
      { items = [view], collapsedAction = ::g_promo.PERFORM_ACTON_NAME })
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)

    ::g_battle_tasks.setUpdateTimer(reqTask, this.scene)
  }

  function onGetRewardForTask(obj) {
    ::g_battle_tasks.requestRewardForTask(obj?.task_id)
  }

  function onWarbondsShop(_obj) {
    ::g_warbonds.openShop()
  }

  function onSelectDifficultyBattleTasks(obj) {
    let index = obj.getValue()
    if (index < 0 || index >= obj.childrenCount())
      return

    let difficultyGroup = obj.getChild(index)?.difficultyGroup

    if (!difficultyGroup)
      return

    ::save_local_account_settings(this.savePathBattleTasksDiff, difficultyGroup)

    this.guiScene.performDelayed(this, function() {
      this.updateHandler()
    })
  }

  function getDifficultyRadioButtonsListByTasks(tasksArray, difficultyTypeArray, curDifficultyGroup) {
    let result = []
    foreach (btDiffType in difficultyTypeArray) {
      let difficultyGroup = btDiffType.getDifficultyGroup()
      let tasksByDiff = u.search(tasksArray,
          @(task) (getDifficultyTypeByTask(task) == btDiffType))

      if (!tasksByDiff)
        continue

      result.append({ radioButtonImage = ::g_battle_tasks.getDifficultyImage(tasksByDiff)
        difficultyGroup = difficultyGroup
        difficultyLocName = btDiffType.getLocName()
        selected = (curDifficultyGroup == difficultyGroup) })
    }
    return result
  }

  function performAction(obj) { ::g_promo.performAction(this, obj) }
  function performActionCollapsed(obj) {
    let buttonObj = obj.getParent()
    this.performAction(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)))
  }
  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  onEventNewBattleTasksChanged                = @(_p) this.updateHandler()
  onEventBattleTasksFinishedUpdate            = @(_p) this.updateHandler()
  onEventBattleTasksTimeExpired               = @(_p) this.updateHandler()
  onEventCurrentGameModeIdChanged             = @(_p) this.updateHandler()
  onEventWarbondShopMarkSeenLevel             = @(_p) this.updateHandler()
  onEventXboxMultiplayerPrivilegeUpdated      = @(_p) this.updateHandler()
}

let promoButtonId = "current_battle_tasks_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "battleTask"
  collapsedIcon = loc("icon/battleTasks")
  collapsedText = "title"
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = ::g_battle_tasks.isAvailableForUser()
      && ::g_promo.getVisibilityById(id)
    let buttonObj = showObjById(id, show, this.scene)
    if (!show || !checkObj(buttonObj))
      return

    ::gui_handlers.BattleTasksPromoHandler.open({ scene = buttonObj })
  }
})
