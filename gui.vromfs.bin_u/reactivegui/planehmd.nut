from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")

let { HmdVisibleAAM } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible } = require("%rGui/radarState.nut")
let { BlkFileName, HmdVisible, HmdBlockIls } = require("planeState/planeToolsState.nut")
let { PNL_ID_HMD } = require("%rGui/globals/panelIds.nut")

let hmdShelZoom = require("planeHmds/hmdShelZoom.nut")
let hmdVtas = require("planeHmds/hmdVtas.nut")
let hmdF16c = require("planeHmds/hmdF16c.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { IPoint2, Point2, Point3 } = require("dagor.math")

let hmdSetting = Computed(function() {
  let res = {
    isShelZoom = false,
    isVtas = false,
    isF16c = false
  }
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    isShelZoom = blk.getBool("hmdShelZoom", false),
    isVtas = blk.getBool("hmdVtas", false),
    isF16c = blk.getBool("hmdF16c", false)
  }
})

let isVisible = Computed(@() (HmdVisibleAAM.value || HmdSensorVisible.value || HmdVisible.value) && !HmdBlockIls.value)
let planeHmd = @(width, height) function() {
  let { isShelZoom, isVtas, isF16c } = hmdSetting.value
  return {
    watch = [hmdSetting, isVisible]
    children = isVisible.value ? [
      (isShelZoom ? hmdShelZoom(width, height) : null),
      (isVtas ? hmdVtas(width, height) : null),
      (isF16c ? hmdF16c(width, height) : null)
    ] : null
  }
}

let pnlDistanceMeters = 100.0
let pnlWidthPx = hdpx(1920)
let pnlHeightPx = hdpx(1024)
let pnlAspectRatio = pnlWidthPx / pnlHeightPx
let pnlHeightMeters = 140.0
let pnlWidthMeters = pnlHeightMeters * pnlAspectRatio
let planeHmdPanelLayout = {
  worldAnchor   = PANEL_ANCHOR_HEAD
  worldGeometry = PANEL_GEOMETRY_RECTANGLE
  worldOffset   = Point3(0.0, 0.0, pnlDistanceMeters)
  worldSize     = Point2(pnlWidthMeters, pnlHeightMeters)
  canvasSize    = IPoint2(pnlWidthPx, pnlHeightPx)

  worldCanBePointedAt = false
  worldBrightness = 1
  worldRenderFeatures = PANEL_RENDER_ALWAYS_ON_TOP

  size    = SIZE_TO_CONTENT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = planeHmd(pnlWidthPx, pnlHeightPx)
}

let spatialPlaneHmd = {
  size = flex()
  onAttach = @() gui_scene.addPanel(PNL_ID_HMD, planeHmdPanelLayout)
  onDetach = @() gui_scene.removePanel(PNL_ID_HMD)
}

let function planeHmdSwitcher(width, height) {
  return @() {
    watch = [isVisible]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = SIZE_TO_CONTENT
    children = !isVisible.value ? null
      : isInVr ? spatialPlaneHmd
      : planeHmd(width, height)
  }
}

return planeHmdSwitcher