from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { eachParam } = require("%sqstd/datablock.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let DataBlock = require("DataBlock")
let { isChineseVersion } = require("%scripts/langUtils/language.nut")

local countryFlagsPreset = {}

let getCountryFlagsPresetName = @() isChineseVersion() ? "chinese" : "default"

let getCountryFlagImg = @(id) countryFlagsPreset?[id] ?? ""

let getCountryIcon = @(countryId, big = false, locked = false)
  getCountryFlagImg($"{countryId}{(big ? "_big" : "")}{(locked ? "_locked" : "")}")

function initCountryFlagsPreset() {
  let blk = GUI.get()
  if (!blk)
    return
  let texBlk = blk?.texture_presets
  if (!texBlk || type(texBlk) != "instance" || !(texBlk instanceof DataBlock)) {
    script_net_assert_once("flags_presets", "Error: not texture_presets block in gui.blk")
    return
  }

  let defPreset = "default"
  let presetsList = [getCountryFlagsPresetName()]
  if (presetsList[0] != defPreset)
    presetsList.append(defPreset)

  countryFlagsPreset = {}

  foreach (blockName in presetsList) {
    let block = texBlk?[blockName]
    if (!block || type(block) != "instance" || !(block instanceof DataBlock))
      continue

    eachParam(block, function(value, name) {
      if (!(name in countryFlagsPreset) && type(value) == "string")
        countryFlagsPreset[name] <- value
    })
  }
}

add_event_listener("GameLocalizationChanged", @(_params) initCountryFlagsPreset(),
  null, g_listener_priority.CONFIG_VALIDATION)

initCountryFlagsPreset()

let getCountryFlagForUnitTooltip = @(id) countryFlagsPreset?[$"{id}_unit_tooltip"]
  ?? $"#ui/images/flags/unit_tooltip/{id}.avif:0:P"

return {
  getCountryFlagForUnitTooltip
  getCountryFlagsPresetName
  getCountryFlagImg
  getCountryIcon
}
