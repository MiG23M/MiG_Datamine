from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { blkFromPath } = require("%sqstd/datablock.nut")
let DataBlock = require("DataBlock")
let string = require("%sqstd/string.nut")
let guidParser = require("%scripts/guidParser.nut")
let stdMath = require("%sqstd/math.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

const MAX_LOCATION_TYPES = 64

let locationTypeNameToId = {} //forest = 1, bitId to easy use in mask
let skinsMask = {} //<skinName> = <locationTypeMask>
let levelsMask = {} //<levelName> = <locationTypeMask>
local camoTypesVisibleList = []
local camoTypesIconPriority = []

function getLocationTypeId(typeName) {
  if (typeName in locationTypeNameToId)
    return locationTypeNameToId[typeName]

  local idx = locationTypeNameToId.len()
  if (idx > MAX_LOCATION_TYPES) {
    script_net_assert_once("too much locTypes", "Error: too much location type names in skins")
    idx = MAX_LOCATION_TYPES
  }

  let res = 1 << idx
  locationTypeNameToId[typeName] <- res
  return res
}

function getLocationsLoc(mask) {
  let list = []
  if (!mask)
    return list
  foreach (name in camoTypesVisibleList)
    if (mask & getLocationTypeId(name))
      list.append(loc($"camoType/{name}"))
  return list
}

function debugLocationMask(mask) {
  let list = []
  foreach (name, bit in locationTypeNameToId)
    if (bit & mask)
      list.append(name)
  return "".concat(mask, ": ", ", ".join(list, true))
}

function getLocationMaskByNamesArray(namesList) {
  local res = 0
  foreach (typeName in namesList)
    res = res | getLocationTypeId(typeName)
  return res
}

local isMasksLoaded = false
function loadSkinMasksOnce() {
  if (isMasksLoaded)
    return false
  isMasksLoaded = true

  let skinsBlk = DataBlock()
  skinsBlk.load("config/skinsLocations.blk")

  for (local i = 0; i < skinsBlk.blockCount(); i++) {
    let blk = skinsBlk.getBlock(i)
    skinsMask[blk.getBlockName()] <- getLocationMaskByNamesArray(blk % "camoType")
  }
  camoTypesVisibleList = []
  if (skinsBlk?.camo_type_visible)
    foreach (b in skinsBlk.camo_type_visible % "camoType")
      camoTypesVisibleList.append(b.name)
  camoTypesIconPriority = []
  if (skinsBlk?.camo_type_icons)
    foreach (b in skinsBlk.camo_type_icons % "camoType")
      camoTypesIconPriority.append(b.name)
}

function getSkinLocationsMaskByDecoratorTags(id, skinType) {
  local res = 0
  let decorator = getDecorator(id, skinType)
  if (!decorator || !decorator.tags)
    return res
  foreach (t in camoTypesVisibleList)
    if (decorator.tags?[t])
      res = res | getLocationTypeId(t)
  return res
}

function getSkinLocationsMaskByFullIdAndSkinId(id, skinId, canBeEmpty, skinType) {
  if (!(id in skinsMask) && !(skinId in skinsMask) && guidParser.isGuid(skinId))
    skinsMask[id] <- getSkinLocationsMaskByDecoratorTags(id, skinType)
  return skinsMask?[id] || skinsMask?[skinId] || (canBeEmpty ? 0  : getLocationTypeId("forest"))
}

function getSkinLocationsMask(skinId, unitId, skinType, canBeEmpty = true) {
  loadSkinMasksOnce()
  return getSkinLocationsMaskByFullIdAndSkinId($"{unitId}/{skinId}", skinId, canBeEmpty, skinType)
}

function getSkinLocationsMaskBySkinId(id, skinType, canBeEmpty = true) {
  loadSkinMasksOnce()
  return getSkinLocationsMaskByFullIdAndSkinId(id, getSkinNameBySkinId(id), canBeEmpty, skinType)
}

function getMaskByLevel(level) {
  if (level in  levelsMask)
    return levelsMask[level]

  local res = 0
  let levelBlk = blkFromPath($"{string.slice(level, 0, -3)}blk")
  let vehiclesSkinsBlk = levelBlk?.technicsSkins
  if (u.isDataBlock(vehiclesSkinsBlk))
    res = getLocationMaskByNamesArray(vehiclesSkinsBlk % "groundSkin")

  levelsMask[level] <- res
  return res
}

function getBestSkinsList(skinsList, unitName, level, skinType) {
  let res = []
  local bestMatch = 0
  let locationMask = getMaskByLevel(level)
  foreach (skin in skinsList) {
    let match = stdMath.number_of_set_bits(locationMask & getSkinLocationsMask(skin, unitName, skinType))
    if (!match)
      continue
    if (match > bestMatch) {
      bestMatch = match
      res.clear()
    }
    if (match == bestMatch)
      res.append(skin)
  }
  return res
}

function getIconTypeByMask(mask) {
  if (mask)
    foreach (name in camoTypesIconPriority)
      if (mask & getLocationTypeId(name))
        return name
  return "forest"
}

return {
  getSkinLocationsMask = getSkinLocationsMask
  getSkinLocationsMaskBySkinId = getSkinLocationsMaskBySkinId
  getMaskByLevel = getMaskByLevel
  getLocationMaskByNamesArray = getLocationMaskByNamesArray
  getBestSkinsList = getBestSkinsList
  getLocationsLoc = getLocationsLoc
  getIconTypeByMask = getIconTypeByMask
  debugLocationMask = debugLocationMask
}