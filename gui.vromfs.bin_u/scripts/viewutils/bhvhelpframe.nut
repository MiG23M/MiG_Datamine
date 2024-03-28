from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { ceil } = require("math")

let BhvHelpFrame = class {
  isUpdateInProgressPID  = dagui_propid_add_name_id("_isUpdateInProgress")

  function onAttach(obj) {
    if (!obj.getIntProp(this.isUpdateInProgressPID, 0))
      obj.getScene().performDelayed(this, function() {
        if (obj.isValid())
          this.updateView(obj)
      })
    return RETCODE_NOTHING
  }

  function setValue(obj, newValue) {
    if (!u.isString(newValue) || obj?.value == newValue)
      return
    obj.value = newValue
    this.updateView(obj)
  }

  function updateView(obj) {
    obj.setIntProp(this.isUpdateInProgressPID, 1)

    if (obj?.value) {
      let markup = ::g_hints.buildHintMarkup(loc(obj.value), {})
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), null)
    }

    local needToFlow = obj.getParent().getSize()[0] * 0.40 < obj.getSize()[0] && obj?.blockFlow == null
    if (obj?.alwaysFlow == "yes")
      needToFlow = true;

    if (obj.getParent().getSize()[0] < obj.getSize()[0])
      obj.getParent().width = "".concat("0.02@sf+", ceil(obj.getSize()[0]))

    obj.getParent()["verticalFlow"] = needToFlow ? "yes" : "no"

    obj.setIntProp(this.isUpdateInProgressPID, 0)
  }
}
replace_script_gui_behaviour("bhvHelpFrame", BhvHelpFrame)