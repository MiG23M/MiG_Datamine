//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let enums = require("%sqStdLibs/helpers/enums.nut")
let stdMath = require("%sqstd/math.nut")
let { getConfigValueById } = require("%scripts/hud/hudTankStates.nut")

::g_hud_crew_member <- {
  types = []
}

const MIN_CREW_COUNT_FOR_WARNING = 2

::g_hud_crew_member._setCrewMemberState <- function _setCrewMemberState(crewIconObj, newStateData) {
  if (!("state" in newStateData))
    return

  if (newStateData.state == "ok") {
    crewIconObj.state = "ok"
  }
  else if (newStateData.state == "takingPlace" || newStateData.state == "healing") {
    let timeBarObj = crewIconObj.findObject("transfere_indicatior")
    ::g_time_bar.setPeriod(timeBarObj, newStateData.totalTakePlaceTime)
    ::g_time_bar.setCurrentTime(timeBarObj, newStateData.totalTakePlaceTime - newStateData.timeToTakePlace)
    crewIconObj.state = "transfere"
    crewIconObj.tooltip = loc(this.tooltip)
  }
  else if (newStateData.state == "dead") {
    crewIconObj.state = "dead"
    crewIconObj.tooltip = loc(this.tooltip)
  }
  else {
    crewIconObj.state = "none"
  }
}

::g_hud_crew_member.template <- {
  hudEventName = ""
  sceneId = ""
  tooltip = ""

  setCrewMemberState = ::g_hud_crew_member._setCrewMemberState
}

enums.addTypesByGlobalName("g_hud_crew_member", {
  GUNNER = {
    hudEventName = "CrewState:GunnerState"
    sceneId = "crew_gunner"
    tooltip = "hud_tank_crew_gunner_out_of_action"
  }

  DRIVER = {
    hudEventName = "CrewState:DriverState"
    sceneId = "crew_driver"
    tooltip = "hud_tank_crew_driver_out_of_action"
  }

  DISTANCE = {
    hudEventName = "CrewState:Distance"
    sceneId = "crew_distance"
    tooltip = "hud_tank_crew_distance"

    setCrewMemberState = function (iconObj, newStateData) {
      let val = stdMath.roundToDigits(newStateData.distance, 2)
      let cooldownObj = ::g_hud_crew_state.scene.findObject("cooldown")
      if (val == 1) {
        cooldownObj["sector-angle-2"] = 0
        iconObj.state = "ok"
        iconObj.tooltip = ""
      }
      else {
        cooldownObj["sector-angle-2"] = (val * 360).tointeger()
        iconObj.state = "bad"
        iconObj.tooltip = loc(this.tooltip, { distance = val * 100 })
      }
    }
  }

  CREW_COUNT = {
    hudEventName = "CrewState:CrewState"
    sceneId = "crew_count"
    setCrewMemberState = function (iconObj, newStateData) {
      if (newStateData.total <= 0) {
        iconObj.show(false)
        return
      }
      else
        iconObj.show(true)

      let text = newStateData.current.tostring()
      local textObj = iconObj.findObject("crew_count_text")
      textObj.setValue(text)
      textObj.overlayTextColor = newStateData.current <= MIN_CREW_COUNT_FOR_WARNING
        && newStateData.total > MIN_CREW_COUNT_FOR_WARNING ? "bad" : ""
    }
  }
})

::g_hud_crew_state <- {
  scene = null
  guiScene = null

  function init(nest) {
    if (!hasFeature("TankDetailedDamageIndicator"))
      return

    this.scene = nest.findObject("crew_state")

    if (!checkObj(this.scene))
      return

    this.guiScene = this.scene.getScene()
    let blk = handyman.renderCached("%gui/hud/hudCrewState.tpl",
      { drivingDirectionModeValue = getConfigValueById("driving_direction_mode") })
    this.guiScene.replaceContentFromText(this.scene, blk, blk.len(), this)

    foreach (crewMemberType in ::g_hud_crew_member.types) {
      let memberType = crewMemberType
      ::g_hud_event_manager.subscribe(memberType.hudEventName,
        function (eventData) {
          let crewObj = this.scene.findObject(memberType.sceneId)
          if (checkObj(crewObj))
            memberType.setCrewMemberState(crewObj, eventData)
        }, this)
    }

    ::hud_request_hud_crew_state()
  }

  function reinit() {
    ::hud_request_hud_crew_state()
  }

  function isValid() {
    return checkObj(this.scene)
  }
}
