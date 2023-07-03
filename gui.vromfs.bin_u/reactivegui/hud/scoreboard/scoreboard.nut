from "%rGui/globals/ui_library.nut" import *

let { gameType, useDeathmatchHUD, timeLeft, timeLimitWarn, customHUD } = require("%rGui/missionState.nut")
let { HasCompass } = require("%rGui/compassState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let football = require("football.ui.nut")
let deathmatch = require("deathmatch.ui.nut")
let po2OpMission = require("po2OpMission.ui.nut")

let timerComponent = @() {
  watch = [ timeLeft, HasCompass ]
  rendObj = ROBJ_TEXT
  font = Fonts.medium_text_hud
  color = Color(255, 255, 255)
  pos = [0, hdpx(40) + (HasCompass.value ? hdpx(50) : 0)]
  text = secondsToTimeSimpleString(timeLeft.value)
}

let hasTimerComponent = Computed(@() timeLimitWarn.value > 0 && timeLeft.value < timeLimitWarn.value)

let function getScoreBoardChildren() {
  if ((gameType.value & GT_FOOTBALL) != 0)
    return football

  if (useDeathmatchHUD.value)
    return deathmatch

  if (customHUD.value == "po2OpMission")
    return po2OpMission

  if (hasTimerComponent.value)
    return timerComponent

  return null
}

return @() {
  size = flex()
  margin = safeAreaSizeHud.value.borders
  halign = ALIGN_CENTER
  watch = [gameType, useDeathmatchHUD, safeAreaSizeHud, hasTimerComponent, customHUD]
  children = getScoreBoardChildren()
}
