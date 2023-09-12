//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformPC
} = require("%scripts/clientState/platform.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { register_command } = require("console")
let { getPlayerSsoShortTokenAsync } = require("auth_wt")
let { TIME_DAY_IN_SECONDS } = require("%scripts/time.nut")
let { validateEmail } = require("%sqstd/string.nut")
let { subscribe } = require("eventbus")
let { get_charserver_time_sec } = require("chard")
let { saveLocalAccountSettings, loadLocalAccountSettings,
  loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfile.nut")

let needShowGuestEmailRegistration = @() isPlatformPC && havePlayerTag("guestlogin")

let function launchGuestEmailRegistration(stoken) {
  let language = ::g_language.getShortName()
  let url = loc("url/pc_bind_url", { language, stoken })
  openUrl(url, false, false, "profile_page")
}

subscribe("onGetStokenForGuestEmail", function(msg) {
  let { status, stoken = null } = msg
  if (status != YU2_OK)
    ::error_message_box("yn1/connect_error", status, [["ok"]], "ok")
  else
    launchGuestEmailRegistration(stoken)
})

let function showGuestEmailRegistration() {
  ::showUnlockWnd({
    name = loc("mainmenu/SteamEmailRegistration")
    desc = loc("mainmenu/guestEmailRegistration/desc")
    popupImage = "ui/images/invite_big?P1"
    onOkFunc = @() getPlayerSsoShortTokenAsync("onGetStokenForGuestEmail")
    okBtnText = "msgbox/btn_bind"
  })
}

let function checkShowGuestEmailRegistrationAfterLogin() {
  if (!needShowGuestEmailRegistration())
    return

  let firstCheckTime = loadLocalAccountSettings("GuestEmailRegistrationCheckTime")
  if (firstCheckTime == null) {
    saveLocalAccountSettings("GuestEmailRegistrationCheckTime", get_charserver_time_sec())
    return
  }

  let timeSinceFirstCheck = get_charserver_time_sec() - firstCheckTime
  if (timeSinceFirstCheck < TIME_DAY_IN_SECONDS)
    return

  showGuestEmailRegistration()
}

let canEmailRegistration = isPlatformSony ? @() havePlayerTag("psnlogin")
  : isPlatformXboxOne ? @() havePlayerTag("livelogin") && hasFeature("AllowXboxAccountLinking")
  : ::steam_is_running() ? @() havePlayerTag("steamlogin") && hasFeature("AllowSteamAccountLinking")
  : @() false

let function launchSteamEmailRegistration() {
  let token = ::get_steam_link_token()
  if (token == "")
    return log("Steam Email Registration: empty token")

  openUrl(loc("url/steam_bind_url",
    {
      token = token,
      langAbbreviation = ::g_language.getShortName()
    }),
    false, false, "profile_page")
}

let function checkShowSteamEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (::g_language.getLanguageName() != "Japanese") {
    if (loadLocalByAccount("SteamEmailRegistrationShowed", false))
      return

    saveLocalByAccount("SteamEmailRegistrationShowed", true)
  }

  ::showUnlockWnd({
    name = loc("mainmenu/SteamEmailRegistration")
    desc = loc("mainmenu/SteamEmailRegistration/desc")
    popupImage = "ui/images/invite_big?P1"
    onOkFunc = launchSteamEmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

let launchPS4EmailRegistration = @()
  ::ps4_open_url_logged_in(loc("url/ps4_bind_url"), loc("url/ps4_bind_redirect"))

let function checkShowPS4EmailRegistration() {
  if (!canEmailRegistration())
    return

  if (loadLocalByAccount("PS4EmailRegistrationShowed", false))
    return

  saveLocalByAccount("PS4EmailRegistrationShowed", true)

  ::showUnlockWnd({
    name = loc("mainmenu/PS4EmailRegistration")
    desc = loc("mainmenu/PS4EmailRegistration/desc")
    popupImage = "ui/images/invite_big?P1"
    onOkFunc = launchPS4EmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

let function sendXboxEmailBind(val) {
  ::show_wait_screen("msgbox/please_wait")
  ::xbox_link_email(val, function(status) {
    ::close_wait_screen()
    ::g_popups.add("", colorize(
      status == YU2_OK ? "activeTextColor" : "warningTextColor",
      loc($"mainmenu/XboxOneEmailRegistration/result/{status}")
    ))
  })
}

let function launchXboxEmailRegistration(override = {}) {
  ::gui_modal_editbox_wnd({
    leftAlignedLabel = true
    title = loc("mainmenu/XboxOneEmailRegistration")
    label = loc("mainmenu/XboxOneEmailRegistration/desc")
    checkWarningFunc = validateEmail
    allowEmpty = false
    needOpenIMEonInit = false
    editBoxEnableFunc = canEmailRegistration
    editBoxTextOnDisable = loc("mainmenu/alreadyBinded")
    editboxWarningTooltip = loc("tooltip/invalidEmail/possibly")
    okFunc = @(val) sendXboxEmailBind(val)
  }.__update(override))
}

let forceLauncheXboxSuggestionEmailRegistration = @()
  launchXboxEmailRegistration({
    leftAlignedLabel = false
    label = loc("mainmenu/recommendEmailRegistration")
    okBtnText = loc("msgbox/bind_and_receive")
    okFunc = sendXboxEmailBind
  })

let function checkShowXboxEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (loadLocalByAccount("XboxEmailRegistrationShowed", false))
    return

  saveLocalByAccount("XboxEmailRegistrationShowed", true)

  forceLauncheXboxSuggestionEmailRegistration()
}

let checkShowEmailRegistration = isPlatformSony ? checkShowPS4EmailRegistration
  : ::steam_is_running() ? checkShowSteamEmailRegistration
  : isPlatformXboxOne ? checkShowXboxEmailRegistration
  : @() null

let emailRegistrationTooltip = isPlatformSony ? loc("mainmenu/PS4EmailRegistration/desc")
  : isPlatformXboxOne ? loc("mainmenu/XboxOneEmailRegistration/desc")
  : loc("mainmenu/SteamEmailRegistration/desc")

let launchEmailRegistration = isPlatformSony ? launchPS4EmailRegistration
  : isPlatformXboxOne ? launchXboxEmailRegistration
  : ::steam_is_running() ? launchSteamEmailRegistration
  : @() null

register_command(function(platform) {
  let fn = platform == "xbox" ? forceLauncheXboxSuggestionEmailRegistration
    : @() console_print($"is missing suggestion for platform {platform}, available 'xbox', 'sony'")
  fn()
  return console_print($"show suggestion for platform {platform}")
}, "emailRegistration.showForceSuggestion")

return {
  launchEmailRegistration
  canEmailRegistration
  emailRegistrationTooltip
  checkShowEmailRegistration
  needShowGuestEmailRegistration
  showGuestEmailRegistration
  checkShowGuestEmailRegistrationAfterLogin
}
