//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let colorCorrector = require("colorCorrector")
let fonts = require("fonts")
let { send } = require("eventbus")
let { is_stereo_mode } = require("vr")
let screenInfo = require("%scripts/options/screenInfo.nut")
let safeAreaMenu = require("%scripts/options/safeAreaMenu.nut")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let focusFrame = require("%scripts/viewUtils/focusFrameWT.nut")
let { setSceneActive, reloadDargUiScript } = require("reactiveGuiCommand")
let rootScreenBlkPathWatch = require("%scripts/baseGuiHandler/rootScreenBlkPathWatch.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isPlatformSony, isPlatformXboxOne, targetPlatform } = require("%scripts/clientState/platform.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { get_team_colors } = require("guiMission")
let { getFromSettingsBlk } = require("%scripts/clientState/clientStates.nut")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { is_active_msg_box_in_scene } = require("%sqDagui/framework/msgBox.nut")
let { getContactsHandler } = require("%scripts/contacts/contactsHandlerState.nut")

require("%scripts/options/fonts.nut") //!!!FIX ME: Need move g_font to module. This require is used to create the global table g_font

dagui_propid_add_name_id("has_ime")
dagui_propid_add_name_id("platformId")

local lastScreenHeightForFont = 0
local lastInFlight = false  //to reload scenes on change inFlight
local currentFont = ::g_font.LARGE
local hasInitializedFont = false


let controlsAllowMaskDefaults = {
  [handlerType.ROOT] = CtrlsInGui.CTRL_ALLOW_FULL,
  [handlerType.BASE] = CtrlsInGui.CTRL_ALLOW_ANSEL,
  [handlerType.MODAL] = CtrlsInGui.CTRL_ALLOW_NONE,
  [handlerType.CUSTOM] = CtrlsInGui.CTRL_ALLOW_FULL
}

let sceneBgBlurDefaults = {
  [handlerType.ROOT]   = @() false,
  [handlerType.BASE]   = @() false,
  [handlerType.MODAL]  = needUseHangarDof,
  [handlerType.CUSTOM] = @() false,
}

let function generateCssString(config) {
  local res = ""
  foreach (cfg in config)
    res += format("@const %s:%s;", cfg.name, cfg.value)
  return res
}


let function generatePreLoadCssString() {
  let countriesCount = shopCountriesList.len()
  let hudSafearea = safeAreaHud.getSafearea()
  let menuSafearea = safeAreaMenu.getSafearea()

  let config = [
    { name = "target_pc",         value = (isPlatformSony || isPlatformXboxOne) ? "no" : "yes" }
    { name = "swMain",            value = screenInfo.getMainScreenSizePx()[0].tostring() }
    { name = "_safearea_menu_w",  value = format("%.2f", menuSafearea[0]) }
    { name = "_safearea_menu_h",  value = format("%.2f", menuSafearea[1]) }
    { name = "_safearea_hud_w",   value = format("%.2f", hudSafearea[0]) }
    { name = "_safearea_hud_h",   value = format("%.2f", hudSafearea[1]) }
    { name = "slotbarCountries",  value = countriesCount.tostring() }
    { name = "isInVr",            value = (is_stereo_mode() ? 1 : 0).tostring() }
  ]

  return generateCssString(config)
}


let function generateColorConstantsConfig() {
  if (!::g_login.isAuthorized())
    return []

  let cssConfig = []
  let standardColors = !::g_login.isLoggedIn() || !::isPlayerDedicatedSpectator()
  let forcedColors = get_team_colors()
  let hasForcedColors = ("colorTeamA" in forcedColors) && ("colorTeamB" in forcedColors)
  local allyTeam, allyTeamColor, enemyTeamColor
  if (hasForcedColors) {
    allyTeam = ::get_mp_local_team()
    allyTeamColor = allyTeam == 2 ? forcedColors.colorTeamB : forcedColors.colorTeamA
    enemyTeamColor = allyTeam == 2 ? forcedColors.colorTeamA : forcedColors.colorTeamB
    cssConfig.append(
      {
        name = "mainPlayerColor"
        value = "#" + allyTeamColor
      },
      {
        name = "chatSenderMeColor"
        value = "#" + allyTeamColor
      },
      {
        name = "hudColorHero"
        value = "#" + allyTeamColor
      }
    )
  }

  let theme = {
    squad = standardColors ? colorCorrector.TARGET_HUE_SQUAD : colorCorrector.TARGET_HUE_SPECTATOR_ALLY
    ally  = standardColors ? colorCorrector.TARGET_HUE_ALLY  : colorCorrector.TARGET_HUE_SPECTATOR_ALLY
    enemy = standardColors ? colorCorrector.TARGET_HUE_ENEMY : colorCorrector.TARGET_HUE_SPECTATOR_ENEMY
  }

  let config = [
    { style = "squad", baseColor = "3E9E2F", names = [ "mySquadColor", "hudColorSquad", "chatSenderMySquadColor", "chatTextSquadVoiceColor" ] }
    { style = "squad", baseColor = "65FF4D", names = [ "chatTextSquadColor" ] }
    { style = "squad", baseColor = "A5FF97", names = [ "mySquadLightColor" ] }
    { style = "ally",  baseColor = "527AFF", names = [ "teamBlueColor", "hudColorBlue", "chatSenderFriendColor", "chatTextTeamVoiceColor" ] }
    { style = "ally",  baseColor = "99B1FF", names = [ "teamBlueLightColor", "hudColorDeathEnemy" ] }
    { style = "ally",  baseColor = "5C637A", names = [ "teamBlueInactiveColor", "hudColorDarkBlue" ] }
    { style = "ally",  baseColor = "0F1834", names = [ "teamBlueDarkColor" ] }
    { style = "ally",  baseColor = "82C2FF", names = [ "chatTextTeamColor" ] }
    { style = "enemy", baseColor = "FF5A52", names = [ "teamRedColor", "hudColorRed", "chatSenderEnemyColor", "chatTextEnemyVoiceColor" ] }
    { style = "enemy", baseColor = "FFA29D", names = [ "teamRedLightColor", "hudColorDeathAlly" ] }
    { style = "enemy", baseColor = "7C5F5D", names = [ "teamRedInactiveColor", "hudColorDarkRed" ] }
    { style = "enemy", baseColor = "34110F", names = [ "teamRedDarkColor" ] }
  ]

  foreach (cfg in config) {
    let color = hasForcedColors ? (cfg.style == "enemy" ? enemyTeamColor : allyTeamColor)
      : colorCorrector.correctHueTarget(cfg.baseColor, theme[cfg.style])

    foreach (name in cfg.names)
      cssConfig.append({
        name = name,
        value = "#" + color
      })
  }

  return cssConfig
}


let function generatePostLoadCssString() {
  let controlCursorWithStick = ::g_gamepad_cursor_controls.getValue()
  let config = [
    {
      name = "shortcutUpGamepad"
      value = controlCursorWithStick ? "@shortcutUpDp" : "@shortcutUpDpAndStick"
    }
    {
      name = "shortcutDownGamepad"
      value = controlCursorWithStick ? "@shortcutDownDp" : "@shortcutDownDpAndStick"
    }
    {
      name = "shortcutLeftGamepad"
      value = controlCursorWithStick ? "@shortcutLeftDp" : "@shortcutLeftDpAndStick"
    }
    {
      name = "shortcutRightGamepad"
      value = controlCursorWithStick ? "@shortcutRightDp" : "@shortcutRightDpAndStick"
    }
  ]

  config.extend(generateColorConstantsConfig())

  return generateCssString(config)
}


let function getHandlerControlsAllowMask(handler) {
  local res = null
  if ("getControlsAllowMask" in handler)
    res = handler.getControlsAllowMask()
  if (res != null)
    return res
  return getTblValue(handler.wndType, controlsAllowMaskDefaults, CtrlsInGui.CTRL_ALLOW_FULL)
}


handlersManager[PERSISTENT_DATA_PARAMS].append("curControlsAllowMask", "isCurSceneBgBlurred")
handlersManager.__update({
  shouldResetFontsCache = false
  curControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL
  isCurSceneBgBlurred = false

  function beforeClearScene(_guiScene) {
    let sh = screenInfo.getScreenHeightForFonts(screen_width(), screen_height())
    if (lastScreenHeightForFont && lastScreenHeightForFont != sh)
      this.shouldResetFontsCache = true
    lastScreenHeightForFont = sh

    if (this.shouldResetFontsCache) {
      fonts.discardLoadedData()
      this.shouldResetFontsCache = false
    }
  }

  function onClearScene(guiScene) {
    if (this.isMainGuiSceneActive()) //is_in_flight function not available before first loading screen
      lastInFlight = ::is_in_flight()

    focusFrame.enable(::get_is_console_mode_enabled())

    guiScene.setCursorSizeMul(guiScene.calcString("@cursorSizeMul", null))
    guiScene.setPatternSizeMul(guiScene.calcString("@dp", null))
    ::enable_dirpad_control_mouse(true)
  }

  function isNeedFullReloadAfterClearScene() {
    return !this.isMainGuiSceneActive()
  }

  function isNeedReloadSceneSpecific() {
    return this.isMainGuiSceneActive() && lastInFlight != ::is_in_flight()
  }

  function beforeLoadHandler(hType) {
    //clear main gui scene when load to battle or from battle
    if ((hType == handlerType.BASE || hType == handlerType.ROOT)
        && ::g_login.isLoggedIn()
        && this.lastGuiScene
        && this.lastGuiScene.isEqual(get_main_gui_scene())
        && !this.isMainGuiSceneActive())
      this.clearScene(this.lastGuiScene)
  }

  function onBaseHandlerLoadFailed(handler) {
    if (!::g_login.isLoggedIn()
        || handler.getclass() == gui_handlers.MainMenu
        || handler.getclass() == gui_handlers.FlightMenu
       )
      startLogout()
    else if (::is_in_flight())
      ::gui_start_flight_menu()
    else
      ::gui_start_mainmenu()
  }

  function onSwitchBaseHandler() {
    if (!::g_login.isLoggedIn())
      return
    let curHandler = this.getActiveBaseHandler()
    if (curHandler)
      ::set_last_gc_scene_if_exist(curHandler.scene)
  }

  function animatedSwitchScene(startFunc) {
    ::switch_gui_scene(startFunc)
  }

  function updatePostLoadCss() {
    local haveChanges = false

    let font = ::g_font.getCurrent()
    if (currentFont != font) {
      this.shouldResetFontsCache = true
      haveChanges = true
    }
    if (!hasInitializedFont || currentFont != font) { //need update font for darg
      let hasValueChangedInDb = updateExtWatched({
        fontGenId = font.fontGenId
        fontSizePx = font.getFontSizePx(screen_width(), screen_height())
      })
      if (hasValueChangedInDb)
        reloadDargUiScript(false)
      hasInitializedFont = true
    }
    currentFont = font

    let cssStringPre = font.genCssString() + "\n" + generatePreLoadCssString() + "\n" + gamepadIcons.getCssString()
    if (::get_dagui_pre_include_css_str() != cssStringPre) {
      let safearea = safeAreaHud.getSafearea()
      ::set_dagui_pre_include_css_str(cssStringPre)
      ::set_hud_width_limit(safearea[0])
      updateExtWatched({
        safeAreaHud = safearea
        safeAreaMenu = safeAreaMenu.getSafearea()
      })
      haveChanges = true
    }

    set_dagui_pre_include_css("")

    let cssStringPost = generatePostLoadCssString()
    if (get_dagui_post_include_css_str() != cssStringPost) {
      set_dagui_post_include_css_str(cssStringPost)
      let forcedColors = ::g_login.isLoggedIn() ? get_team_colors() : {}
      send("recalculateTeamColors", { forcedColors })
      haveChanges = true
    }

    if (::switch_show_console_buttons(::get_is_console_mode_enabled()))
      haveChanges = true

    return haveChanges
  }

  function updateCssParams(guiScene) {
    let rootObj = guiScene.getRoot()

    //Check for special hints, because IME is called with special action, and need to show text about it
    let hasIME = isPlatformSony || isPlatformXboxOne || is_platform_android || ::is_steam_big_picture()
    rootObj["has_ime"] = hasIME ? "yes" : "no"
    rootObj["platformId"] = targetPlatform
  }


  function calcCurrentControlsAllowMask() {
    if (checkObj(::current_wait_screen))
      return CtrlsInGui.CTRL_ALLOW_NONE
    if (is_active_msg_box_in_scene(get_cur_gui_scene()))
      return CtrlsInGui.CTRL_ALLOW_NONE

    local res = CtrlsInGui.CTRL_ALLOW_FULL
    foreach (group in this.handlers)
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive()) {
          let mask = getHandlerControlsAllowMask(h)
          res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
        }

    foreach (name in ["menu_chat_handler", "contacts_handler", "game_chat_handler"])
      if (name in getroottable() && getroottable()[name]) {
        let mask = getroottable()[name].getControlsAllowMask()
        res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
      }
    let contactsHandler = getContactsHandler()
    if (contactsHandler != null) {
      let mask = contactsHandler.getControlsAllowMask()
      res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
    }

    return res
  }

  function updateControlsAllowMask() {
    if (!this._loadHandlerRecursionLevel)
      this._updateControlsAllowMask()
  }

  function _updateControlsAllowMask() {
    let newMask = this.calcCurrentControlsAllowMask()
    if (newMask == this.curControlsAllowMask)
      return

    this.curControlsAllowMask = newMask
    ::set_allowed_controls_mask(this.curControlsAllowMask)
    //dlog(format("GP: controls changed to 0x%X", this.curControlsAllowMask))
  }

  function updateWidgets() {
    let widgetsList = []
    local hasActiveDargScene = false
    foreach (group in this.handlers)
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive() && h?.getWidgetsList) {
          let wList = h.getWidgetsList()
          widgetsList.extend(wList)
          if (wList.len() > 0 && h.isSceneActiveNoModals())
            hasActiveDargScene = true
        }

    setSceneActive(hasActiveDargScene)
    send("updateWidgets", { widgetsList })
  }

  function calcCurrentSceneBgBlur() {
    foreach (wndType, group in this.handlers) {
      let defValue = sceneBgBlurDefaults?[wndType]() ?? false
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive())
          if (h?.shouldBlurSceneBgFn() ?? h?.shouldBlurSceneBg ?? defValue)
            return true
    }
    return false
  }

  function updateSceneBgBlur(forced = false) {
    if (!this._loadHandlerRecursionLevel)
      this._updateSceneBgBlur(forced)
  }


  function _updateSceneBgBlur(forced = false) {
    let isBlur = this.calcCurrentSceneBgBlur()
    if (!forced && isBlur == this.isCurSceneBgBlurred)
      return

    this.isCurSceneBgBlurred = isBlur
    ::hangar_blur(this.isCurSceneBgBlurred)
  }

  function updateSceneVrParams() {
    if (!this._loadHandlerRecursionLevel)
      this._updateSceneVrParams()
  }

  function _updateSceneVrParams() {
    if (!is_stereo_mode())
      return

    local shouldFade = false
    local shouldCenterToCam = false
    foreach (_wndType, group in this.handlers) {
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive()) {
          shouldFade = shouldFade || (h?.shouldFadeSceneInVr ?? false)
          shouldCenterToCam = shouldCenterToCam || (h?.shouldOpenCenteredToCameraInVr ?? false)
        }
    }
    ::set_gui_vr_params(shouldCenterToCam, shouldFade)
  }

  function onActiveHandlersChanged() {
    this._updateControlsAllowMask()
    this.updateWidgets()
    this._updateSceneBgBlur()
    this._updateSceneVrParams()
    broadcastEvent("ActiveHandlersChanged")
  }

  function onEventWaitBoxCreated(_p) {
    this._updateControlsAllowMask()
    this.updateWidgets()
    this._updateSceneBgBlur()
    this._updateSceneVrParams()
  }

  function beforeInitHandler(handler) {
    if (handler.rootHandlerClass || this.getHandlerType(handler) == handlerType.CUSTOM)
      return

    if (focusFrame.isEnabled)
      handler.guiScene.createElementByObject(handler.scene, "%gui/focusFrameAnim.blk", "tdiv", null)

    if (!::g_login.isLoggedIn() || handler instanceof gui_handlers.BaseGuiHandlerWT)
      return

    this.initVoiceChatWidget(handler)
  }

  function initVoiceChatWidget(handler) {
    if (handler.rootHandlerClass || this.getHandlerType(handler) == handlerType.CUSTOM)
      return

    if (::g_login.isLoggedIn() && (handler?.needVoiceChat ?? true))
      handler.guiScene.createElementByObject(handler.scene, "%gui/chat/voiceChatWidget.blk", "widgets", null)
  }

  function validateHandlersAfterLoading() {
    this.clearInvalidHandlers()
    this.updateLoadingFlag()
    broadcastEvent("FinishLoading")
  }

  function getRootScreenBlkPath() {
    return rootScreenBlkPathWatch.value
  }

  function setGuiRootOptions(guiScene, forceUpdate = true) {
    let rootObj = guiScene.getRoot()
    rootObj["show_console_buttons"] = showConsoleButtons.value ? "yes" : "no" //should to force box buttons in WoP?
    if ("ps4_is_circle_selected_as_enter_button" in getroottable() && ::ps4_is_circle_selected_as_enter_button())
      rootObj["swap_ab"] = "yes";

    if (!forceUpdate)
      return

    rootObj["css-hier-invalidate"] = "all"  //need to update scene after set this parameters
    guiScene.performDelayed(this, function() {
      if (check_obj(rootObj))
        rootObj["css-hier-invalidate"] = "no"
    })
  }
})

::get_cur_base_gui_handler <- function get_cur_base_gui_handler() { //!!FIX ME: better to not use it at all. really no need to create instance of base handler without scene.
  let handler = handlersManager.getActiveBaseHandler()
  if (handler)
    return handler
  return gui_handlers.BaseGuiHandlerWT(get_cur_gui_scene())
}

::gui_start_empty_screen <- function gui_start_empty_screen() {
  handlersManager.emptyScreen()
  let guiScene = get_cur_gui_scene()
  if (guiScene)
    guiScene.clearDelayed() //delayed actions doesn't work in empty screen.
}

::is_low_width_screen <- function is_low_width_screen() { //change this function simultaneously with isWide constant in css
  return currentFont.isLowWidthScreen()
}

::isInMenu <- function isInMenu() {
  return !::is_in_loading_screen() && !::is_in_flight()
}

::gui_finish_loading <- function gui_finish_loading() {
  handlersManager.validateHandlersAfterLoading()
}

::move_mouse_on_obj <- function move_mouse_on_obj(obj) { //it used in a lot of places, so leave it global
  if (obj?.isValid())
    obj.setMouseCursorOnObject()
}

::move_mouse_on_child <- function move_mouse_on_child(obj, idx = 0) { //it used in a lot of places, so leave it global
  if (::is_mouse_last_time_used() || !obj?.isValid() || obj.childrenCount() <= idx || idx < 0)
    return
  let child = obj.getChild(idx)
  if (!child.isValid())
    return
  child.scrollToView()
  get_cur_gui_scene().performDelayed({}, function() {
    if (!child?.isValid())
      return
    child.setMouseCursorOnObject()
  })
}

::move_mouse_on_child_by_value <- function move_mouse_on_child_by_value(obj) { //it used in a lot of places, so leave it global
  if (obj?.isValid())
    ::move_mouse_on_child(obj, obj.getValue())
}

::select_editbox <- function select_editbox(obj) {
  if (!obj?.isValid())
    return
  if (::is_mouse_last_time_used())
    obj.select()
  else
    obj.setMouseCursorOnObject()
}

let needDebug = getFromSettingsBlk("debug/debugGamepadCursor", false)
get_cur_gui_scene()?.setGamepadCursorDebug(needDebug)

handlersManager.init()

return {
  handlersManager
}
