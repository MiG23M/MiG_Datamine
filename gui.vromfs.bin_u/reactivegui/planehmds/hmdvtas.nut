from "%rGui/globals/ui_library.nut" import *

let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { IlsColor, IlsLineScale } = require("%rGui/planeState/planeToolsState.nut")
let { HmdVisibleAAM, GuidanceLockState, HmdDesignation, HmdFovMult } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible, HmdSensorDesignation } = require("%rGui/radarState.nut")

let { baseLineWidth } = require("hmdConstants.nut")

let function crosshair(width, _height) {
  return @() {
    watch = [HmdFovMult, HmdVisibleAAM, HmdDesignation, HmdSensorVisible, HmdSensorDesignation, GuidanceLockState, IlsColor]
    size = [width * 0.05 * HmdFovMult.value, width * 0.05 * HmdFovMult.value]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    fillColor = Color(0, 0, 0, 0)
    commands =
      [
        [VECTOR_ELLIPSE, 0, 0, 25, 25],
        [VECTOR_ELLIPSE, 0, 0, 5, 5]
      ].append(HmdVisibleAAM.value ? [VECTOR_ELLIPSE, -25, -25, 2, 2] : []).
        append(HmdDesignation.value && GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? [VECTOR_ELLIPSE, -25, 25, 2, 2] : []).
        append(HmdSensorVisible.value ? [VECTOR_ELLIPSE, 25, -25, 2, 2] : []).
        append(HmdSensorDesignation.value ? [VECTOR_ELLIPSE, 25, 25, 2, 2] : [])
  }
}

let function vtas(width, height) {
  return {
    size = [width, height]
    pos = [0.5 * width, 0.5 * height]
    children = crosshair(width, height)
  }
}

return vtas