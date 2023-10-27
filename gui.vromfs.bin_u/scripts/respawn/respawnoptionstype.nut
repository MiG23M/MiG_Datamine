//checked for plus_string
from "%scripts/dagui_library.nut" import *
let enums = require("%sqStdLibs/helpers/enums.nut")
let { DECORATION } = require("%scripts/utils/genericTooltipTypes.nut")
let { bombNbr, hasCountermeasures, getCurrentPreset, hasBombDelayExplosion } = require("%scripts/unit/unitStatus.nut")
let { isTripleColorSmokeAvailable } = require("%scripts/options/optionsManager.nut")
let { getSkinsOption } = require("%scripts/customization/skins.nut")
let { USEROPT_USER_SKIN, USEROPT_GUN_TARGET_DISTANCE, USEROPT_AEROBATICS_SMOKE_TAIL_COLOR,
  USEROPT_GUN_VERTICAL_TARGETING, USEROPT_BOMB_ACTIVATION_TIME, USEROPT_BOMB_SERIES,
  USEROPT_DEPTHCHARGE_ACTIVATION_TIME, USEROPT_ROCKET_FUSE_DIST, USEROPT_TORPEDO_DIVE_DEPTH,
  USEROPT_LOAD_FUEL_AMOUNT, USEROPT_COUNTERMEASURES_PERIODS, USEROPT_COUNTERMEASURES_SERIES,
  USEROPT_COUNTERMEASURES_SERIES_PERIODS, USEROPT_AEROBATICS_SMOKE_TYPE, USEROPT_SKIN,
  USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR
} = require("%scripts/options/optionsExtNames.nut")

let options = {
  types = []
  cache = {
    bySortId = {}
  }
}

let _isVisible = @(p) p.unit != null
  && this.isAvailableInMission()
  && (!p.isRandomUnit || this.isShowForRandomUnit)
  && this.isShowForUnit(p)

let _isNeedUpdateByTrigger = @(trigger) this.isAvailableInMission() && (trigger & this.triggerUpdateBitMask) != 0
let _isNeedUpdContentByTrigger = @(trigger, _p) (trigger & this.triggerUpdContentBitMask) != 0

let function _update(p, trigger, isAlreadyFilled) {
  if (!this.isNeedUpdateByTrigger(trigger))
    return false

  let isShow = this.isVisible(p)
  let isEnable = isShow && p.canChangeAircraft
  let isNeedUpdateContent = !isAlreadyFilled || this.isNeedUpdContentByTrigger(trigger, p)
  local isFilled = false

  let obj = p.handler.scene.findObject(this.id)
  if (obj?.isValid()) {
    obj.enable(isEnable)
    if (isShow) {
      let opt = this.getUseropt(p)
      let objOptionValue = obj.getValue()
      if (isNeedUpdateContent) {
        if (this.cType == optionControlType.LIST) {
          let markup = ::create_option_list(null, opt.items, opt.value, null, false)
          p.handler.guiScene.replaceContentFromText(obj, markup, markup.len(), p.handler)
        }
        else if (this.cType == optionControlType.CHECKBOX)
          if (objOptionValue != opt.value)
            obj.setValue(opt.value)
        isFilled = true
        if (this.needCallCbOnContentUpdate)
          p.handler?[this.cb].call(p.handler, obj)
      }
      if (this.needCheckValueWhenOptionUpdate && objOptionValue != opt.value)
        obj.setValue(opt.value)
    }
  }

  let rowObj = p.handler.scene.findObject($"{this.id}_tr")
  if (rowObj?.isValid()) {
    rowObj.show(isShow)
  }
  return isFilled
}

options.template <- {
  id = "" // Generated from type name
  sortId = 0
  getLabelText = @() loc($"options/{this.id}")
  userOption = -1
  triggerUpdateBitMask = 0
  triggerUpdContentBitMask = 0
  cType = optionControlType.LIST
  needSetToReqData = false
  cb = "checkReady"
  needCallCbOnContentUpdate = false
  isShowForRandomUnit = true

  isAvailableInMission = @() true
  isShowForUnit = @(_p) false
  isVisible = _isVisible
  getUseropt = @(_p) ::get_option(this.userOption)
  isNeedUpdateByTrigger = _isNeedUpdateByTrigger
  isNeedUpdContentByTrigger = _isNeedUpdContentByTrigger
  update = _update

  needCheckValueWhenOptionUpdate = false //some options save by unit, and when unit changed need update option value if it changed
}

options.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable, null, "id")
  this.types.sort(@(a, b) a.sortIdx <=> b.sortIdx)
}

local idx = -1
options.addTypes({
  unknown = {
    sortIdx = idx++
    userOption = -1
    isShowForRandomUnit = false
    isAvailableInMission = @() false
  }
  skin = {
    sortIdx = idx++
    userOption = USEROPT_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(_p) true
    getUseropt = function(p) {
      let skinsOpt = getSkinsOption(p.unit?.name ?? "")
      skinsOpt.items = skinsOpt.items.map(@(v, i) v.__merge({
        tooltipObj = { id = DECORATION.getTooltipId(skinsOpt.decorators[i].id, UNLOCKABLE_SKIN) }
      }))
      return skinsOpt
    }
  }
  user_skins = {
    sortIdx = idx++
    userOption = USEROPT_USER_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isAvailableInMission = @() hasFeature("UserSkins")
    isShowForUnit = @(_p) true
  }
  gun_target_dist = {
    sortIdx = idx++
    userOption = USEROPT_GUN_TARGET_DISTANCE
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    needSetToReqData = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  gun_vertical_targeting = {
    sortIdx = idx++
    userOption = USEROPT_GUN_VERTICAL_TARGETING
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    cType = optionControlType.CHECKBOX
    needSetToReqData = true
    isAvailableInMission = @() ::is_gun_vertical_convergence_allowed()
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  bomb_activation_time = {
    sortIdx = idx++
    userOption = USEROPT_BOMB_ACTIVATION_TIME
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isShowForUnit = @(p) hasBombDelayExplosion(p.unit)
  }
  bomb_series = {
    sortIdx = idx++
    userOption = USEROPT_BOMB_SERIES
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && bombNbr(p.unit) > 1
  }
  depthcharge_activation_time = {
    sortIdx = idx++
    userOption = USEROPT_DEPTHCHARGE_ACTIVATION_TIME
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isShowForUnit = @(p) p.unit.isShipOrBoat()
      && p.unit.isDepthChargeAvailable()
      && (getCurrentPreset(p.unit)?.hasDepthCharge ?? false)
  }
  rocket_fuse_dist = {
    sortIdx = idx++
    userOption = USEROPT_ROCKET_FUSE_DIST
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
      && (getCurrentPreset(p.unit)?.hasRocketDistanceFuse ?? false)
  }
  torpedo_dive_depth = {
    sortIdx = idx++
    userOption = USEROPT_TORPEDO_DIVE_DEPTH
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    needCheckValueWhenOptionUpdate = true
    isAvailableInMission = @() !::get_option_torpedo_dive_depth_auto()
    isShowForUnit = @(p) p.unit.isShipOrBoat()
      && (getCurrentPreset(p.unit)?.torpedo ?? false)
  }
  fuel_amount = {
    sortIdx = idx++
    userOption = USEROPT_LOAD_FUEL_AMOUNT
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  countermeasures_periods = {
    sortIdx = idx++
    userOption = USEROPT_COUNTERMEASURES_PERIODS
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  countermeasures_series_periods = {
    sortIdx = idx++
    userOption = USEROPT_COUNTERMEASURES_SERIES_PERIODS
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  countermeasures_series = {
    sortIdx = idx++
    userOption = USEROPT_COUNTERMEASURES_SERIES
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  respawn_base = {
    sortIdx = idx++
    userOption = -1
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    cb = "onRespawnbaseOptionUpdate"
    needCallCbOnContentUpdate = true
    isShowForUnit = @(p) p.haveRespawnBases
    getUseropt = @(p) {
      items = p.respawnBasesList.map(@(spawn) { text = spawn.getTitle() })
      value = p.respawnBasesList.indexof(p.curRespawnBase) ?? -1
    }
    isNeedUpdContentByTrigger = @(trigger, p) _isNeedUpdContentByTrigger(trigger, p) && p.isRespawnBasesChanged
  }
  aerobatics_smoke_type = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_TYPE
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    cb = "onSmokeTypeUpdate"
    isShowForUnit = @(p) p.unit.isAir()
  }
  aerobatics_smoke_left_color = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_LEFT_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  aerobatics_smoke_right_color = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  aerobatics_smoke_tail_color = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
})

options.get <- @(id) this?[id] ?? this.unknown

return options
