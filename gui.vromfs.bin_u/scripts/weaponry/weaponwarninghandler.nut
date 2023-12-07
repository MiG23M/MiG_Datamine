//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { set_gui_option } = require("guiOptions")
let { USEROPT_SKIP_WEAPON_WARNING } = require("%scripts/options/optionsExtNames.nut")

gui_handlers.WeaponWarningHandler <- class (gui_handlers.SkipableMsgBox) {
  skipOption = USEROPT_SKIP_WEAPON_WARNING
  showCheckBoxBullets = true

  function initScreen() {
    base.initScreen()

    let bltCheckBoxObj = this.scene.findObject("slots-autoweapon")
    if (!checkObj(bltCheckBoxObj))
      return

    bltCheckBoxObj.show(this.showCheckBoxBullets)
    if (this.showCheckBoxBullets)
      bltCheckBoxObj.setValue(::get_auto_refill(1))
  }

  function skipFunc(value) {
    set_gui_option(this.skipOption, value)
    saveProfile()
  }
}
