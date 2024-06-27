let { showInfoMsgBox } = require("%sqDagui/framework/msgBox.nut")
let { loc } = require("dagor.localize")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { getPlayerSsoShortTokenAsync, getNickOrig } = require("auth_wt")
let { eventbus_subscribe } = require("eventbus")
let { log } = require("%sqstd/log.nut")()
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let regexp2 = require("regexp2")

const BASE_URL = "https://warthundercompanion.page.link/?link=https%3A%2F%2Fassistant%2Fauth%2F%3Fstoken%3D{stokenParam}%26stat%3D{deeplinkPlaceParam}%26nick%3D{nickParam}%26login%3D{userIdParam}&apn=com.gaijinent.WarThunderCompanion&isi=899236988&ibi=com.saniaxxx.wtr-assistant" // warning disable: -forgot-subst

const EXTERNAL_DEEPLINK_URL_PARAM_NAME = "parameterizedDeeplinkURL"

local deeplinkPlace = ""

function hasExternalAssistantDeepLink() {
  return getCurCircuitOverride(EXTERNAL_DEEPLINK_URL_PARAM_NAME) != null
}

function isExternalOperator() {
  return getCurCircuitOverride("operatorName") != null
}

function openModalWTAssistantlDeeplink(place) {
  deeplinkPlace = place
  getPlayerSsoShortTokenAsync("onGetStokenForWTAssistantlDeeplink")
}

function intToHexChar(value) {
  let hexDigits = "0123456789ABCDEF"
  return hexDigits[value & 0x0F].tochar()
}

function urlEncodeChar(ch) {
  if (regexp2(@"[a-zA-Z0-9_.~-]").match(ch.tochar())) {
    return ch.tochar()
  }

  let highNibble = (ch >> 4) & 0x0F
  let lowNibble = ch & 0x0F
  return $"%{intToHexChar(highNibble) + intToHexChar(lowNibble)}"
}

function urlEncodeString(input) {
  local encoded = ""
  foreach(ch in input) {
    encoded += urlEncodeChar(ch)
  }

  return encoded
}

eventbus_subscribe("onGetStokenForWTAssistantlDeeplink", function(msg) {
  let { status, stoken = null } = msg

  if (status != YU2_OK) {
    log("ERROR: on get short token for wt assistant deeplink = ", status)
    showInfoMsgBox(loc("msgbox/notAvailbleShortToken"))
    return
  }

  log("SUCCESS: on get short token for wt assistant deeplink from = ", deeplinkPlace)

  let link = getCurCircuitOverride(EXTERNAL_DEEPLINK_URL_PARAM_NAME, BASE_URL).subst({
    stokenParam = urlEncodeString(stoken),
    deeplinkPlaceParam = urlEncodeString(deeplinkPlace),
    nickParam = urlEncodeString(getNickOrig()),
    userIdParam = userIdStr.value
  })

  openQrWindow({
    headerText = loc("wtassistant_deeplink/title")
    infoText = loc("wtassistant_deeplink/descr")
    qrCodesData = [
      { url = link }
    ]
    needShowUrlLink = false
  })
})

return {
  openModalWTAssistantlDeeplink
  hasExternalAssistantDeepLink
  isExternalOperator
}