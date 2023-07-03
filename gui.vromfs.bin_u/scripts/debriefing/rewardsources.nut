//checked for plus_string
from "%scripts/dagui_library.nut" import *

let sourcesConfig = {
  noBonus = {
    textColor = "@commonTextColor"
  }
  premAcc = {
    textColor = "@chapterUnlockedColor"
    hasPlus = true
    icon = "#ui/gameuiskin#item_type_premium.svg"
  }
  premMod = {
    textColor = "@chapterUnlockedColor"
    hasPlus = true
    icon = "#ui/gameuiskin#item_type_talisman.svg"
    iconWidth = "0.95@sIco"
  }
  booster = {
    textColor = "@linkTextColor"
    hasPlus = true
    icon = "#ui/gameuiskin#item_type_boosters.svg"
  }
  prevUnitEfficiency = {
    textColor = "@userlogColoredText"
    hasPlus = true
  }
}

return {
  sourcesConfig
  NO_BONUS             = sourcesConfig.noBonus
  PREM_ACC             = sourcesConfig.premAcc
  PREM_MOD             = sourcesConfig.premMod
  BOOSTER              = sourcesConfig.booster
  PREV_UNIT_EFFICIENCY = sourcesConfig.prevUnitEfficiency
}
