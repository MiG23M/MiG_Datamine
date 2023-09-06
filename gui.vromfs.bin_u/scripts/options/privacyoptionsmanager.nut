//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { havePremium } = require("%scripts/user/premium.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_DISPLAY_MY_REAL_NICK, USEROPT_SHOW_SOCIAL_NOTIFICATIONS,
  USEROPT_ALLOW_ADDED_TO_CONTACTS, USEROPT_ALLOW_ADDED_TO_LEADERBOARDS
} = require("%scripts/options/optionsExtNames.nut")

local privacyOptionsList = [
  USEROPT_DISPLAY_MY_REAL_NICK,
  USEROPT_SHOW_SOCIAL_NOTIFICATIONS,
  USEROPT_ALLOW_ADDED_TO_CONTACTS,
  USEROPT_ALLOW_ADDED_TO_LEADERBOARDS
]

let function resetPrivacyOptionsToDefault() {
  foreach (optName in privacyOptionsList) {
    let opt = ::get_option(optName)
    set_option(opt.type, opt.defVal, opt)
  }
}

havePremium.subscribe(function(val) {
  if (val == false)
    resetPrivacyOptionsToDefault()
})