from "%scripts/dagui_natives.nut" import dgs_get_argv, check_login_pass, set_login_pass
from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let { get_disable_autorelogin_once } = require("loginState.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")

gui_handlers.LoginWndHandlerDMM <- class (BaseGuiHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)

    let isAutologin = !get_disable_autorelogin_once()
    if (isAutologin) {
      this.guiScene.performDelayed(this, function() { this.doLogin() })
      return
    }

    let data = handyman.renderCached("%gui/commonParts/button.tpl", {
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "A"
      funcName = "doLogin"
      delayed = true
      visualStyle = "noBgr"
      mousePointerCenteringBelowText = true
      actionParamsMarkup = "bigBoldFont:t='yes'; shadeStyle:t='shadowed'"
    })
    this.guiScene.prependWithBlk(this.scene.findObject("authorization_button_place"), data, this)
  }

  function doLogin() {
    log("DMM Login: check_login_pass")
    log("DMM Login: dmm_user_id ", dgs_get_argv("dmm_user_id"))
    log("DMM Login: dmm_token ", dgs_get_argv("dmm_token"))
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "dmm" })
    let ret = ::check_login_pass(dgs_get_argv("dmm_user_id"),
      dgs_get_argv("dmm_token"), "749130", "dmm", false, false)
    this.proceedAuthorizationResult(ret)
  }

  function proceedAuthorizationResult(result) {
    if (!checkObj(this.scene)) //check_login_pass is not instant
      return

    if (YU2_OK == result) {
      set_login_pass("", "", 0)
      ::g_login.addState(LOGIN_STATE.AUTHORIZED)
    }
    else if ( result == YU2_NOT_FOUND) {
      this.msgBox("dmm_error_not_found_user", loc("yn1/error/DMM_NOT_FOUND", { link = loc("warthunder_dmm_link") }),
      [
        ["exit", exitGame ],
        ["tryAgain", Callback(this.doLogin, this)]
      ], "tryAgain", { cancel_fn = Callback(this.doLogin, this) })
    }
    else {
      ::error_message_box("yn1/connect_error", result,
      [
        ["exit", exitGame],
        ["tryAgain", Callback(this.doLogin, this)]
      ], "tryAgain", { cancel_fn = Callback(this.doLogin, this) })
    }
  }

  function goBack() {
    this.onExit()
  }

  function onExit() {
    this.msgBox("login_question_quit_game", loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no", @() null]
      ], "no", { cancel_fn = @() null })
  }
}
