//-file:plus-string
from "%scripts/dagui_natives.nut" import shop_upgrade_crew, purchase_crew_slot, get_training_cost, get_aircraft_crew_by_id
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let stdMath = require("%sqstd/math.nut")
let { ceil } = require("math")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let DataBlock = require("DataBlock")
let { get_warpoints_blk, get_skills_blk, get_price_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { addTask } = require("%scripts/tasker.nut")

const UPGR_CREW_TUTORIAL_SKILL_NUMBER = 2

local crewLevelBySkill = 5 //crew level from any maxed out skill
local totalSkillsSteps = 5 //steps available for leveling.

let crewSkillPages = []
let availableCrewSkills = {}
let unitCrewTrainReq = {} //[crewUnitType] = array

let minCrewLevel = {
  [CUT_AIRCRAFT] = 1.5,
  [CUT_TANK] = 1,
  [CUT_SHIP] = 1
}

let maxCrewLevel = {
  [CUT_AIRCRAFT] = 75,
  [CUT_TANK] = 150,
  [CUT_SHIP] = 100
}

function isCountryHasAnyEsUnitType(country, esUnitTypeMask) {
  let typesList = getTblValue(country, ::get_unit_types_in_countries(), {})
  foreach (esUnitType, isInCountry in typesList)
    if (isInCountry && (esUnitTypeMask & (1 << esUnitType)))
      return true
  return false
}

let getCrew = @(countryId, idInCountry) ::g_crews_list.get()?[countryId].crews[idInCountry]

function isAllCrewsHasBasicSpec() {
  let basicCrewSpecType = ::g_crew_spec_type.BASIC
  foreach (checkedCountrys in ::g_crews_list.get())
    foreach (crew in checkedCountrys.crews)
      foreach (unitName, _value in crew.trainedSpec) {
        let crewUnitSpecType = ::g_crew_spec_type.getTypeByCrewAndUnitName(crew, unitName)
        if (crewUnitSpecType != basicCrewSpecType)
          return false
      }

  return true
}

function getCrewDiscountInfo(countryId = -1, idInCountry = -1) {
  if (countryId < 0 || idInCountry < 0)
    return {}

  let countrySlot = getTblValue(countryId, ::g_crews_list.get(), {})
  let crewSlot = "crews" in countrySlot && idInCountry in countrySlot.crews ? countrySlot.crews[idInCountry] : {}

  let country = countrySlot.country
  let unitNames = getTblValue("trained", crewSlot, [])

  let packNames = []
  eachBlock(get_warpoints_blk()?.crewSkillPointsCost, @(_, n) packNames.append(n))

  let result = {}
  result.buyPoints <- ::getDiscountByPath(["skills", country, packNames], get_price_blk())
  foreach (t in ::g_crew_spec_type.types)
    if (t.hasPrevType())
      result[t.specName] <- t.getDiscountValueByUnitNames(unitNames)
  return result
}

function getCrewMaxDiscountByInfo(discountInfo, includeBuyPoints = true) {
  local maxDiscount = 0
  foreach (name, discount in discountInfo)
    if (name != "buyPoints" || includeBuyPoints)
      maxDiscount = max(maxDiscount, discount)

  return maxDiscount
}

function createCrewBuyPointsHandler(crew) {
  return handlersManager.loadHandler(gui_handlers.CrewBuyPointsHandler, { crew })
}

/**
 * This function is used both in CrewModalHandler,
 * CrewBuyPointsHandler and CrewUnitSpecHandler.
 */
function getCrewButtonRow(obj, scene, tblObj = null) {
  if (tblObj == null)
    tblObj = scene.findObject("skills_table")
  local curRow = tblObj.getValue()
  if (obj) {
    if (obj?.holderId)
      curRow = obj.holderId.tointeger()
    else {
      let pObj = obj.getParent()
      if (pObj?.id) {
        let row = pObj.id.tointeger()
        if (row >= 0)
          curRow = row
      }
    }
  }
  if (curRow < 0 || curRow >= tblObj.childrenCount())
    curRow = 0
  return curRow
}

function createCrewUnitSpecHandler(containerObj) {
  let scene = containerObj.findObject("specs_table")
  if (!checkObj(scene))
    return null
  return handlersManager.loadHandler(gui_handlers.CrewUnitSpecHandler, { scene })
}

function getCrewSkillItem(memberName, skillName) {
  foreach (page in crewSkillPages)
    if (page.id == memberName) {
      foreach (skillItem in page.items)
        if (skillItem.name == skillName)
          return skillItem
      break
    }
  return null
}

function getCrewSkillValue(crewId, unit, memberName, skillName) {
  let unitCrewData = ::g_unit_crew_cache.getUnitCrewDataById(crewId, unit)
  return unitCrewData?[memberName][skillName] ?? 0
}

function getCrewSkillNewValue(skillItem, crew, unit) {
  let res = getTblValue("newValue", skillItem, null)
  if (res != null)
    return res
  return getCrewSkillValue(crew.id, unit, skillItem.memberName, skillItem.name)
}

function getCrewMaxSkillValue(skillItem) {
  return skillItem.costTbl.len()
}

function getCrewSkillCost(skillItem, value, prevValue = -1) {
  let cost = getTblValue(value - 1, skillItem.costTbl, 0)
  if (prevValue < 0)
    prevValue = value - 1
  let prevCost = getTblValue(prevValue - 1, skillItem.costTbl, 0)
  return cost - prevCost
}

function getCrewName(crew) {
  let number =  getTblValue("idInCountry", crew, -1) + 1
  return loc("options/crewName") + number
}

function getCrewUnit(crew) {
  return getAircraftByName(crew?.aircraft ?? "")
}

function getCrewCountry(crew) {
  let countryData = getTblValue(crew.idCountry, ::g_crews_list.get())
  return countryData ? countryData.country : ""
}

function getCrewTrainCost(crew, unit) {
  let res = Cost()
  if (!unit)
    return res
  if (crew)
    res.wp = get_training_cost(crew.id, unit.name).cost
  else
    res.wp = unit.trainCost
  return res
}

function getCrewSkillPoints(crew) {
  return getTblValue("skillPoints", crew, 0)
}

function purchaseNewCrewSlot(country, onTaskSuccess, onTaskFail = null) {
  let taskId = purchase_crew_slot(country)
  return addTask(taskId, { showProgressBox = true }, onTaskSuccess, onTaskFail)
}

function getSkillMaxCrewLevel(_skillItem) { // todo remove unused param
  return crewLevelBySkill
}

function getMinCrewLevel(crewUnitType) {
  return minCrewLevel?[crewUnitType] ?? 0
}

function getMaxCrewLevel(crewUnitType) {
  return maxCrewLevel?[crewUnitType] ?? 0
}

function getSkillCrewLevel(skillItem, newValue, prevValue = 0) {
  let maxValue = getCrewMaxSkillValue(skillItem)
  local level = (newValue.tofloat() - prevValue) / maxValue  * getSkillMaxCrewLevel(skillItem)
  return stdMath.round_by_value(level, 0.01)
}

function getCrewLevel(crew, unit, crewUnitType, countByNewValues = false) {
  ::load_crew_skills_once()

  local res = 0.0
  foreach (page in crewSkillPages)
    if (page.isVisible(crewUnitType))
      foreach (item in page.items) {
        if (!item.isVisible(crewUnitType))
          continue

        local skill = getCrewSkillValue(crew?.id, unit, page.id, item.name)
        if (countByNewValues)
          skill = getTblValue("newValue", item, skill)
        res += getSkillCrewLevel(item, skill)
      }
  return res
}

function isAllCrewsMinLevel() {
  foreach (checkedCountrys in ::g_crews_list.get())
    foreach (crew in checkedCountrys.crews)
      foreach (unitType in unitTypes.types)
        if (unitType.isAvailable()
            && getCrewLevel(crew, getCrewUnit(crew), unitType.crewUnitType) > getMinCrewLevel(unitType.crewUnitType))
          return false

  return true
}

function getCrewDiscountsTooltipByInfo(discountInfo, showBuyPoints = true) {
  let maxDiscount = getCrewMaxDiscountByInfo(discountInfo, showBuyPoints).tostring()

  local numPositiveDiscounts = 0
  local positiveDiscountCrewSpecType = null
  foreach (t in ::g_crew_spec_type.types)
    if (t.hasPrevType() && discountInfo[t.specName] > 0) {
      ++numPositiveDiscounts
      positiveDiscountCrewSpecType = t
    }

  if (numPositiveDiscounts == 0) {
    if (showBuyPoints && discountInfo.buyPoints > 0)
      return format(loc("discount/buyPoints/tooltip"), maxDiscount)
    else
      return ""
  }

  if (numPositiveDiscounts == 1)
    return positiveDiscountCrewSpecType.getDiscountTooltipByValue(maxDiscount)

  let table = {}
  foreach (t in ::g_crew_spec_type.types)
    if (t.hasPrevType())
      table[t.getNameLocId()] <- discountInfo[t.specName]

  if (showBuyPoints)
    table["mainmenu/btnBuySkillPoints"] <- discountInfo.buyPoints

  return ::g_discount.generateDiscountInfo(table, format(loc("discount/specialization/tooltip"), maxDiscount)).discountTooltip
}

//crewUnitType == -1 - all unitTypes
function isCrewMaxLevel(crew, unit, country, crewUnitType = -1) {
  foreach (page in crewSkillPages) {
    if (crewUnitType >= 0 && !page.isVisible(crewUnitType))
      continue

    foreach (skillItem in page.items)
      if ((crewUnitType < 0 || skillItem.isVisible(crewUnitType))
          && isCountryHasAnyEsUnitType(country,
            unitTypes.getEsUnitTypeMaskByCrewUnitTypeMask(skillItem.crewUnitTypeMask))
          && getCrewMaxSkillValue(skillItem) > getCrewSkillValue(crew.id, unit, page.id, skillItem.name))
        return false
  }
  return true
}

function getCrewTotalSteps(skillItem) {
  return min(totalSkillsSteps, getCrewMaxSkillValue(skillItem) || 1)
}

function getSkillStepSize(skillItem) {
  let maxSkill = getCrewMaxSkillValue(skillItem)
  return ceil(maxSkill.tofloat() / getCrewTotalSteps(skillItem)).tointeger() || 1
}

function crewSkillValueToStep(skillItem, value) {
  let step = getSkillStepSize(skillItem)
  return value.tointeger() / step
}

function crewSkillStepToValue(skillItem, curStep) {
  return curStep * getSkillStepSize(skillItem)
}

function getNextCrewSkillStepValue(skillItem, curValue, increment = true, stepsAmount = 1) {
  let step = getSkillStepSize(skillItem)
  if (!increment)
    return max(curValue - step * stepsAmount - (curValue % step), 0)

  let maxSkill = getCrewMaxSkillValue(skillItem)
  return min(curValue + step * stepsAmount - (curValue % step), maxSkill)
}

function getNextCrewSkillStepCost(skillItem, curValue, stepsAmount = 1) {
  let nextValue = getNextCrewSkillStepValue(skillItem, curValue, true, stepsAmount)
  if (nextValue == curValue)
    return 0
  return getCrewSkillCost(skillItem, nextValue, curValue)
}

function getMaxAvailbleCrewStepValue(skillItem, curValue, skillPoints) {
  let maxValue = getCrewMaxSkillValue(skillItem)
  let maxCost = skillPoints + getCrewSkillCost(skillItem, curValue, 0)
  if (getCrewSkillCost(skillItem, maxValue, 0) <= maxCost) //to correct work if maxValue % step != 0
    return maxValue

  local resValue = curValue
  let step = getSkillStepSize(skillItem)
  for (local i = getNextCrewSkillStepValue(skillItem, curValue); i < maxValue; i += step)
    if (getCrewSkillCost(skillItem, i, 0) <= maxCost)
      resValue = i
  return resValue
}

//crewUnitType == -1 - all unitTypes
//action = function(page, skillItem)
function doWithAllSkills(crew, crewUnitType, action) {
  let country = getCrewCountry(crew)
  foreach (page in crewSkillPages) {
    if (crewUnitType >= 0 && !page.isVisible(crewUnitType))
      continue

    foreach (skillItem in page.items)
      if ((crewUnitType < 0 || skillItem.isVisible(crewUnitType))
          && isCountryHasAnyEsUnitType(country,
            unitTypes.getEsUnitTypeMaskByCrewUnitTypeMask(skillItem.crewUnitTypeMask)))
        action(page, skillItem)
  }
}

//crewUnitType == -1 - all unitTypes
function getCrewSkillPointsToMaxAllSkills(crew, unit, crewUnitType = -1) {
  local res = 0
  doWithAllSkills(crew, crewUnitType,
    function(page, skillItem) {
      let maxValue = getCrewMaxSkillValue(skillItem)
      let curValue = getCrewSkillValue(crew.id, unit, page.id, skillItem.name)
      if (curValue < maxValue)
        res += getCrewSkillCost(skillItem, maxValue, curValue)
    }
  )
  return res
}

function maximazeAllSkillsImpl(crew, unit, crewUnitType) {
  let blk = DataBlock()
  doWithAllSkills(crew, crewUnitType,
    function(page, skillItem) {
      let maxValue = getCrewMaxSkillValue(skillItem)
      let curValue = getCrewSkillValue(crew.id, unit, page.id, skillItem.name)
      if (maxValue > curValue)
        blk.addBlock(page.id)[skillItem.name] = maxValue - curValue
    }
  )

  let isTaskCreated = addTask(
    shop_upgrade_crew(crew.id, blk),
    { showProgressBox = true },
    function() {
      broadcastEvent("CrewSkillsChanged", { crew, unit })
      ::g_crews_list.flushSlotbarUpdate()
    },
    @(_err) ::g_crews_list.flushSlotbarUpdate()
  )

  if (isTaskCreated)
    ::g_crews_list.suspendSlotbarUpdates()
}

function buyAllCrewSkills(crew, unit, crewUnitType) {
  let totalPointsToMax = getCrewSkillPointsToMaxAllSkills(crew, unit, crewUnitType)
  if (totalPointsToMax <= 0)
    return

  let curPoints = getTblValue("skillPoints", crew, 0)
  if (curPoints >= totalPointsToMax)
    return maximazeAllSkillsImpl(crew, unit, crewUnitType)

  let packs = ::g_crew_points.getPacksToBuyAmount(getCrewCountry(crew), totalPointsToMax)
  if (!packs.len())
    return

  ::g_crew_points.buyPack(crew, packs, @() maximazeAllSkillsImpl(crew, unit, crewUnitType))
}

function hasSkillPointsToRunTutorial(crew, unit, crewUnitType, skillPage) {
  local skillCount = 0
  local skillPointsNeeded = 0
  foreach (_idx, item in skillPage.items)
    if (item.isVisible(crewUnitType)) {
      let itemSkillValue = getCrewSkillValue(crew.id, unit, skillPage.id, item.name)
      skillPointsNeeded += getNextCrewSkillStepCost(item, itemSkillValue)
      ++skillCount
      if (skillCount >= UPGR_CREW_TUTORIAL_SKILL_NUMBER)
        break
    }

  if (skillCount < UPGR_CREW_TUTORIAL_SKILL_NUMBER)
    return false

  return getCrewSkillPoints(crew) >= skillPointsNeeded
}

function getCrewSkillPageIdToRunTutorial(crew) {
  let unit = getCrewUnit(crew)
  if (!unit)
    return null

  let crewUnitType = unit.getCrewUnitType()
  foreach (skillPage in crewSkillPages)
    if (skillPage.isVisible(crewUnitType))
      if (hasSkillPointsToRunTutorial(crew, unit, crewUnitType, skillPage))
        return skillPage.id

  return null
}

function onEventCrewSkillsChanged(params) {
  if (!params?.isOnlyPointsChanged) {
    let unit = params?.unit ?? getCrewUnit(params.crew)
    if (unit)
      unit.invalidateModificators()
  }
  ::update_crew_skills_available(true)
}

let min_steps_for_crew_status = [1, 2, 3]

local is_crew_skills_available_inited = false
/*
  crewSkillPages : [
    { id = "pilot"
      items = [{ name = eyesight, costTbl = [1, 5, 10]}, ...]
    }
  ]
*/

::load_crew_skills <- function load_crew_skills() {
  crewSkillPages.clear()
  unitCrewTrainReq.clear()

  let blk = get_skills_blk()
  crewLevelBySkill = blk?.skill_to_level_ratio ?? crewLevelBySkill
  totalSkillsSteps = blk?.max_skill_level_steps ?? totalSkillsSteps

  eachBlock(blk?.crew_skills, function(pageBlk, pName) {
    let unitTypeTag = pageBlk?.type ?? ""
    let defaultCrewUnitTypeMask = unitTypes.getTypeMaskByTagsString(unitTypeTag, "; ", "bitCrewType")
    let page = {
      id = pName,
      image = blk?.crew_skills_calc[pName].image ?? ""
      crewUnitTypeMask = defaultCrewUnitTypeMask
      items = []
      isVisible = function(crewUnitType) { return (this.crewUnitTypeMask & (1 << crewUnitType)) != 0 }
    }
    eachBlock(pageBlk, function(itemBlk, sName) {
      let item = {
        name = sName,
        memberName = page.id
        crewUnitTypeMask = unitTypes.getTypeMaskByTagsString(itemBlk?.type ?? "", "; ", "bitCrewType")
                        || defaultCrewUnitTypeMask
        costTbl = []
        isVisible = function(crewUnitType) { return (this.crewUnitTypeMask & (1 << crewUnitType)) != 0 }
      }
      page.crewUnitTypeMask = page.crewUnitTypeMask | item.crewUnitTypeMask

      let costBlk = itemBlk?.skill_level_exp
      local idx = 1
      local totalCost = 0
      while (costBlk?["level" + idx] != null) {
        totalCost += costBlk["level" + idx]
        item.costTbl.append(totalCost)
        idx++
      }
      item.useSpecializations <- itemBlk?.use_specializations ?? false
      item.useLeadership <- itemBlk?.use_leadership ?? false
      page.items.append(item)
    })
    crewSkillPages.append(page)
  })

  broadcastEvent("CrewSkillsReloaded")

  let reqBlk = blk?.train_req
  if (reqBlk == null)
    return

  foreach (t in unitTypes.types) {
    if (!t.isAvailable() || unitCrewTrainReq?[t.crewUnitType] != null)
      continue

    let typeBlk = reqBlk?[t.getCrewTag()]
    if (typeBlk == null)
      continue

    let trainReq = []
    local costBlk = null
    local tIdx = 0
    do {
      tIdx++
      costBlk = typeBlk?["train" + tIdx]
      if (costBlk) {
        trainReq.append([])
        for (local idx = 0; idx <= ::max_country_rank; idx++)
          trainReq[tIdx - 1].append(costBlk?["rank" + idx] ?? 0)
      }
    }
    while (costBlk != null)

    unitCrewTrainReq[t.crewUnitType] <- trainReq
  }
}

::load_crew_skills_once <- function load_crew_skills_once() {
  if (crewSkillPages.len() == 0)
    ::load_crew_skills()
}

function get_crew_skill_value(crewSkills, crewType, skillName) {
  return crewSkills?[crewType]?[skillName] ?? 0
}

function count_available_skills(crew, crewUnitType) { //return part of availbleskills 0..1
  let curPoints = ("skillPoints" in crew) ? crew.skillPoints : 0
  if (!curPoints)
    return 0.0

  let crewSkills = get_aircraft_crew_by_id(crew.id)
  local notMaxTotal = 0
  let available = [0, 0, 0]

  foreach (page in crewSkillPages)
    foreach (item in page.items) {
      if (!item.isVisible(crewUnitType))
        continue

      let totalSteps = getCrewTotalSteps(item)
      let value = get_crew_skill_value(crewSkills, page.id, item.name)
      let curStep = crewSkillValueToStep(item, value)
      if (curStep == totalSteps)
        continue

      notMaxTotal++
      foreach (idx, amount in min_steps_for_crew_status) {
        if (curStep + amount > totalSteps)
          continue

        if (getNextCrewSkillStepCost(item, value, amount) <= curPoints)
          available[idx]++
      }
    }

  if (notMaxTotal == 0)
    return 0

  for (local i = 2; i >= 0; i--)
    if (available[i] >= 0.5 * notMaxTotal)
      return i + 1
  return 0
}

::update_crew_skills_available <- function update_crew_skills_available(forceUpdate = false) {
  if (is_crew_skills_available_inited && !forceUpdate)
    return
  is_crew_skills_available_inited = true

  ::load_crew_skills_once()
  availableCrewSkills.clear()
  foreach (cList in ::g_crews_list.get())
    foreach (_idx, crew in cList?.crews || []) {
      let data = {}
      foreach (unitType in unitTypes.types) {
        let crewUnitType = unitType.crewUnitType
        if (!data?[crewUnitType])
          data[crewUnitType] <- count_available_skills(crew, crewUnitType)
      }
      availableCrewSkills[crew.id] <- data
    }
}

::get_crew_status <- function get_crew_status(crew, unit) {
  local status = ""
  if (isInFlight())
    return status
  foreach (id, data in availableCrewSkills) {
    if (id != crew.id)
      continue
    unit = unit ?? getAircraftByName(crew?.aircraft ?? "")
    if (unit == null)
      break
    let crewUnitType = unit.getCrewUnitType()
    if (!(crewUnitType in data))
      break

    let res = data[crewUnitType]
    if (res == 3)
      status = "full"
    else if (res == 2)
      status = "ready"
    else if (res == 1)
      status = "show"
    else
      status = ""
    break
  }
  return status
}

addListenersWithoutEnv({
  CrewSkillsChanged = onEventCrewSkillsChanged
}, g_listener_priority.UNIT_CREW_CACHE_UPDATE)

return {
  getCrew
  crewSkillPages
  unitCrewTrainReq
  maxCrewLevel
  isAllCrewsHasBasicSpec
  getCrewDiscountInfo
  getCrewMaxDiscountByInfo
  createCrewBuyPointsHandler
  getCrewButtonRow
  createCrewUnitSpecHandler
  getCrewSkillValue
  getCrewSkillItem
  getCrewSkillNewValue
  getCrewMaxSkillValue
  getCrewSkillCost
  getCrewName
  getCrewUnit
  getCrewCountry
  getCrewTrainCost
  getCrewSkillPoints
  purchaseNewCrewSlot
  getSkillMaxCrewLevel
  getMinCrewLevel
  getMaxCrewLevel
  isAllCrewsMinLevel
  getCrewDiscountsTooltipByInfo
  isCrewMaxLevel
  getCrewLevel
  getCrewTotalSteps
  crewSkillValueToStep
  crewSkillStepToValue
  getNextCrewSkillStepValue
  getNextCrewSkillStepCost
  getMaxAvailbleCrewStepValue
  getCrewSkillPointsToMaxAllSkills
  buyAllCrewSkills
  getCrewSkillPageIdToRunTutorial
  getSkillCrewLevel
}
