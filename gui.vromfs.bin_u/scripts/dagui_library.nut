//checked for plus_string
require("%sqstd/globalState.nut").setUniqueNestKey("dagui")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { kwarg, memoize } = require("%sqstd/functools.nut")
let { Computed, Watched } = require("frp")
let log = require("%globalScripts/logs.nut")
let mkWatched = require("%globalScripts/mkWatched.nut")
let { loc } = require("dagor.localize")
let { debugTableData, toString } = require("%sqStdLibs/helpers/toString.nut")
let utf8 = require("utf8")
let isInArray = @(v, arr) arr.contains(v)
let { Callback } = require("%sqStdLibs/helpers/callback.nut")
let { hasFeature } = require("%scripts/user/features.nut")
let { platformId }  = require("%sqstd/platform.nut")
let { toPixels, showObjById, showObjectsByTable } = require("%sqDagui/daguiUtil.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let nativeApi = require("%sqDagui/daguiNativeApi.nut")
let checkObj = @(obj) obj != null && obj?.isValid()
let { scene_msg_box, destroyMsgBox, showInfoMsgBox } = require("%sqDagui/framework/msgBox.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isStringFloat } = require("%sqstd/string.nut")

let getTblValue = @(key, tbl, defValue = null) key in tbl ? tbl[key] : defValue

let function colorize(color, text) {
  if (color == "" || text == "")
    return text

  let firstSymbol = color.slice(0, 1)
  let prefix = (firstSymbol == "@" || firstSymbol == "#") ? "" : "@"
  return "".concat("<color=", prefix, color, ">", text, "</color>")
}
let get_cur_gui_scene = nativeApi.get_cur_gui_scene
let function to_pixels(value) {
  return toPixels(get_cur_gui_scene(), value)
}

let is_platform_pc = ["win32", "win64", "macosx", "linux64"].contains(platformId)
let is_platform_windows = ["win32", "win64"].contains(platformId)
let is_platform_android = platformId == "android"
let is_platform_xbox = platformId == "xboxOne" || platformId == "xboxScarlett"

let getAircraftByName = @(name) getAllUnits()?[name]

let function is_numeric(value) {
  let t = type(value)
  return t == "integer" || t == "float" || t == "int64"
}

let function to_integer_safe(value, defValue = 0, needAssert = true) {
  if (!is_numeric(value) && (!u.isString(value) || !isStringFloat(value))) {
    if (needAssert)
      script_net_assert_once("to_int_safe", $"can't convert '{value}' to integer")
    return defValue
  }
  return value.tointeger()
}

let function to_float_safe(value, defValue = 0, needAssert = true) {
  if (!is_numeric(value)
    && (!u.isString(value) || !isStringFloat(value))) {
    if (needAssert)
      script_net_assert_once("to_float_safe", $"can't convert '{value}' to float")
    return defValue
  }
  return value.tofloat()
}

let get_roman_numeral_lookup = [
  "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
  "", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC",
  "", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM",
]
const MAX_ROMAN_DIGIT = 3


//Function from http://blog.stevenlevithan.com/archives/javascript-roman-numeral-converter
let function get_roman_numeral(num) { // -return-different-types
  if (!is_numeric(num) || num < 0) {
    script_net_assert_once("get_roman_numeral", $"get_roman_numeral({num})")
    return ""
  }

  num = num.tointeger()
  if (num >= 4000)
    return num.tostring()

  let thousands = []
  for (local n = 0; n < num / 1000; n++)
    thousands.append("M")

  local roman = []
  local i = -1
  while (num > 0 && i++ < MAX_ROMAN_DIGIT) {
    let digit = num % 10
    num = num / 10
    roman = [getTblValue(digit + (i * 10), get_roman_numeral_lookup, "")].extend(roman)
  }
  return "".join(thousands.extend(roman))
}


return log.__merge(nativeApi, {
  is_numeric
  to_integer_safe
  to_float_safe
  get_roman_numeral

  nbsp = " " // Non-breaking space character
  destroyMsgBox
  showInfoMsgBox
  scene_msg_box

  platformId
  is_platform_pc
  is_platform_windows
  is_platform_android
  is_platform_xbox
  isInArray
  getTblValue
  checkObj
  showObjById
  showObjectsByTable
  Callback
  colorize
  to_pixels
  hasFeature

  debugTableData
  toString
  utf8
  loc
  //frp
  Watched
  Computed
  mkWatched

  //function tools
  kwarg
  memoize

  //some ugly stuff
  getAircraftByName
})


