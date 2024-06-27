from "%rGui/globals/ui_library.nut" import *

let { MfdRadarColor, MfdRadarEnabled, radarPosSize } = require("radarState.nut")
let { IsMfdEnabled, RwrScale, RwrBackHide, MfdRadarWithNavVis, MfdRadarNavPosSize,
    MfdVdiVisible, MfdVdiPosSize, DigitalDevicesVisible, DigDevicesPosSize, MfdRwrColor } = require("planeState/planeToolsState.nut")
let {tws, mfdRwrSettings} = require("tws.nut")
let { RwrForMfd, RwrPosSize } = require("airState.nut")
let mfdRadarWithNav = require("planeCockpit/mfdRadarWithNav.nut")
let mfdVdi = require("planeCockpit/mfdVdi.nut")
let digitalDevices = require("planeCockpit/digitalDevices.nut")
let mfdCamera = require("planeMfdCamera.nut")
let { radarMfd } = require("%rGui/radar.nut")
let mfdCustomPages = require("%rGui/planeCockpit/customPageBuilder.nut")

let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let planeMFD = @() {
  watch = [MfdRadarEnabled, RwrForMfd, RwrScale, MfdRadarWithNavVis, MfdVdiVisible, DigitalDevicesVisible, RwrBackHide]
  size = flex()
  children = [
    (MfdRadarEnabled.value ? radarMfd(radarPosSize, MfdRadarColor) : null),
    (RwrForMfd.get() && RwrScale.get() != 0.0 ? {
        rendObj = ROBJ_SOLID
        pos = [RwrPosSize.value[0] - (1.0-RwrScale.get()) * 0.5 * RwrPosSize.value[2] / RwrScale.get(), RwrPosSize.value[1] - (1.0-RwrScale.get()) * 0.5 * RwrPosSize.value[3] / RwrScale.get()]
        size = [RwrPosSize.value[2] / RwrScale.get(), RwrPosSize.value[3] / RwrScale.get()]
        color = mfdRwrSettings.get().backgroundColor
      } : null),
    (RwrForMfd.value
      ? tws({
        colorWatched = MfdRwrColor,
        posWatched = twsPosComputed,
        sizeWatched = twsSizeComputed,
        relativCircleSize = 54,
        scale = RwrScale.value,
        needDrawCentralIcon = !RwrBackHide.value,
        needDrawBackground = !RwrBackHide.value,
        fontSizeMult = 1.8,
        needAdditionalLights = false,
        forMfd = true
        centralCircleSizeMult = 0.7
      })
      : null),
    mfdCamera,
    mfdCustomPages,
    (MfdRadarWithNavVis.value ? mfdRadarWithNav(MfdRadarNavPosSize[2], MfdRadarNavPosSize[3], MfdRadarNavPosSize[0], MfdRadarNavPosSize[1]) : null),
    (MfdVdiVisible.value ? mfdVdi(MfdVdiPosSize[2], MfdVdiPosSize[3], MfdVdiPosSize[0], MfdVdiPosSize[1]) : null),
    (DigitalDevicesVisible.value ? digitalDevices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1]) : null)
  ]
}

let Root = @() {
  watch = IsMfdEnabled
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = IsMfdEnabled.value ? planeMFD : null
}

return Root