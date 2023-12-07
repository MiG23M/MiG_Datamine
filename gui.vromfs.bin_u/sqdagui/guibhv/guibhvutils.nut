from "%sqDagui/daguiNativeApi.nut" import *

let { memoize } = require("%sqstd/functools.nut")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { fabs } = require("math")

let function getNearestSelectableChildIndex(listObj, curIndex, way) {
  if (!check_obj(listObj))
    return curIndex

  let step = (way >= 0) ? 1 : -1
  let breakAt = (way >= 0) ? listObj.childrenCount() : -1
  for (local i = curIndex + step; i != breakAt; i += step) {
    let iObj = listObj.getChild(i)
    if (!check_obj(iObj))
      continue
    if (!iObj.isVisible() || !iObj.isEnabled() || iObj?.inactive == "yes")
      continue
    return i
  }
  return curIndex
}

let function isObjHaveActiveChilds(obj) {
  for (local i = 0; i < obj.childrenCount(); i++) {
    let iObj = obj.getChild(i)
    if (iObj.isVisible() && iObj.isEnabled() && iObj?.inactive != "yes")
      return true
  }
  return false
}

let markInteractive = @(obj, isInteractive) obj.interactive = isInteractive ? "yes" : "no"

let function markChildrenInteractive(obj, isInteractive) {
  for (local i = 0; i < obj.childrenCount(); i++) {
    let child = obj.getChild(i)
    if (child.isValid())
      child.interactive = isInteractive ? "yes" : "no"
  }
}

let function markObjShortcutOnHover(obj, isByHover) {
  if (!obj.getScene().getIsShortcutOnHover())
    return;
  obj["shortcut-on-hover"] = isByHover ? "yes" : "no"
}

let centeringStrToArray = memoize(function(str) {
  let list = str.split(",")
  if (list.len() != 2)
    return [0.5, 0.5]
  return list.map(@(v) v.tofloat() * 0.01)
})

let getObjCentering = @(obj) centeringStrToArray(obj.getFinalProp("mouse-pointer-centering") ?? "")

let function getObjCenteringPosRC(obj) {
  let pos = obj.getPosRC()
  let size = obj.getSize()
  return getObjCentering(obj).map(@(pointerMul, a) (pos[a] + pointerMul * size[a]).tointeger())
}

function blendProp(curX, newX, blendTime, dt) {
  if ((blendTime <= 0) || (fabs(newX - curX) < 1))
    return newX

  let blendK = 4.0 * dt / blendTime
  local dX = (newX - curX) * blendK
  if (fabs(dX) < 1)
    dX = (dX < 0) ? -1 : 1
  return (blendK > 1) ? newX : curX + dX
}

function setTranspRecursive(obj, value) {
  obj.set_prop_latent("color-factor", value)
  obj.updateRendElem()

  let totalObjs = obj.childrenCount()
  for (local i = 0; i < totalObjs; i++)
    setTranspRecursive(obj.getChild(i), value)
}

function updateTransparencyRecursive(obj, transpNew) {
  let last_transp_PID = dagui_propid_add_name_id("_last_transp")

  obj.setIntProp(last_transp_PID, transpNew.tointeger())
  obj.set_prop_latent("color-factor", transpNew)
  obj.updateRendElem()

  let totalObjs = obj.childrenCount()
  for (local i = 0; i < totalObjs; i++)
    updateTransparencyRecursive(obj.getChild(i), transpNew.tostring())
}

return {
  isObjHaveActiveChilds
  getNearestSelectableChildIndex
  markChildrenInteractive
  markInteractive
  markObjShortcutOnHover
  centeringStrToArray
  getObjCentering
  getObjCenteringPosRC
  blendProp
  setTranspRecursive
  updateTransparencyRecursive
}