//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { Cost } = require("%scripts/money.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { split_by_chars } = require("string")
let { eachBlock } = require("%sqstd/datablock.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isString, isArray, isTable, isFunction } = u
let time = require("%scripts/time.nut")
let contentPreview = require("%scripts/customization/contentPreview.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let stdMath = require("%sqstd/math.nut")
let { targetPlatform, canSpendRealMoney } = require("%scripts/clientState/platform.nut")
let { getLastWeapon, isWeaponEnabled,
  isWeaponVisible } = require("%scripts/weaponry/weaponryInfo.nut")
let { unitClassType, getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getDefaultPresetId } = require("%scripts/weaponry/weaponryPresets.nut")
let { initUnitWeapons, initWeaponryUpgrades, initUnitModifications, initUnitWeaponsContainers
} = require("%scripts/unit/initUnitWeapons.nut")
let { getWeaponryCustomPresets } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")
let { shopPromoteUnits } = require("%scripts/shop/shopUnitsInfo.nut")
let { get_skins_for_unit } = require("unitCustomization")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { get_charserver_time_sec } = require("chard")
let { shopIsModificationEnabled } = require("chardResearch")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { get_wpcost_blk, get_warpoints_blk, get_unittags_blk,
  get_modifications_blk } = require("blkGetters")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { getUnitCountry, isUnitGift } = require("%scripts/unit/unitInfo.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")

let MOD_TIERS_COUNT = 4

let unitIntParams = [ "costGold", "rank", "reqExp",
  "repairCost", "repairTimeHrsArcade", "repairTimeHrsHistorical", "repairTimeHrsSimulation",
  "train2Cost", "train3Cost_gold", "train3Cost_exp",
  "gunnersCount", "bulletsIconParam"
]

local Unit = class {
   name = ""
   rank = 0
   shopCountry = ""
   isInited = false //is inited by wpCost, warpoints, and unitTags

   expClass = unitClassType.UNKNOWN
   unitType = unitTypes.INVALID
   esUnitType = ES_UNIT_TYPE_INVALID
   isPkgDev = false

   cost = 0
   costGold = 0
   reqExp = 0
   expMul = 1.0
   gift = null //""
   giftParam = null //""
   event = null //""
   premPackAir = false
   repairCost = 0
   repairTimeHrsArcade = 0
   repairTimeHrsHistorical = 0
   repairTimeHrsSimulation = 0
   freeRepairs = 0
   trainCost = 0
   train2Cost = 0
   train3Cost_gold = 0
   train3Cost_exp = 0
   gunnersCount = 0
   hasDepthCharge = false

   isInShop = false
   reqAir = null //name of unit required by shop tree
   futureReqAir = null
   futureReqAirDesc = null
   group = null //name of units group in shop
   fakeReqUnits = null //[] or null when no required fake units
   showOnlyWhenBought = false
   showOnlyWhenResearch = false
   showOnlyIfPlayerHasUnlock = null //"" or null
   hideForLangs = null //[] or null when no lang restrictions
   reqFeature = null //"" or null
   hideFeature = null //"" or null
   reqUnlock = null //"" or null
   isCrossPromo = false
   crossPromoBanner = null

   customImage = null //""
   customClassIco = null //""
   customTooltipImage = null //""

   tags = null //[]
   weapons = null //[]
   modifications = null //[]
   skins = null //[]
   skinsBlocks = null //{}
   previewSkinId = null //""
   weaponUpgrades = null //[]
   spare = null //{} or null
   needBuyToOpenNextInTier = null //[]

   commonWeaponImage = "#ui/gameuiskin#weapon"
   primaryBullets = null //{}
   secondaryBullets = null //{}
   bulletsIconParam = 0

   shop = null //{} - unit params table for shop unit info
   info = null //{} - tank params info

   testFlight = ""

   isToStringForDebug = true

   //!!FIX ME: params below are still set from outside of unit
   modificatorsRequestTime = -1
   modificators = null //{} or null
   modificatorsBase = null //{} or null
   minChars = null //{} or null
   maxChars = null //{} or null
   primaryWeaponMods = null //[] or null
   secondaryWeaponMods = null //{} or null
   bulGroups = -1
   bulModsGroups = -1
   bulletsSets = null //{}
   primaryBulletsInfo = null //[] or null
   shopReq = true //used in shop, but look like shop can get it from other sources than from unit.
   researchType = null
   marketplaceItemdefId = null

   defaultWeaponPreset  = null
   disableFlyout        = false
   hideBrForVehicle     = false
   showShortestUnitInfo = false // only name, tag and image
   nvdSights = null // {[modName]: []} NVD sights for mods info
   hasWeaponSlots = false
   weaponsContainers = null

  //unit table generated by native function gather_and_build_aircrafts_list
  constructor(unitTbl) {
    //!!FIX ME: Is it really required? we can init units by unittags self without native code
    foreach (key, value in unitTbl)
      if (key in this)
        this[key] = value

    foreach (key in ["tags", "weapons", "modifications", "skins", "weaponUpgrades", "needBuyToOpenNextInTier"])
      if (!isArray(this[key]))
        this[key] = []
    foreach (key in ["shop", "info", "primaryBullets", "secondaryBullets", "bulletsSets", "skinsBlocks", "weaponsContainers"])
      if (!isTable(this[key]))
        this[key] = {}
  }

  function setFromUnit(unit) {
    foreach (key, value in unit)
      if (!isFunction(value)
        && (key in this)
        && !isFunction(this[key])
      )
        this[key] = value
    return this
  }

  function initOnce() {
    if (this.isInited)
      return null
    this.isInited = true

    let warpoints = get_warpoints_blk()
    let uWpCost = this.getUnitWpCostBlk()

    let expClassStr = uWpCost?.unitClass
    this.expClass = getUnitClassTypeByExpClass(expClassStr)
    this.esUnitType = this.expClass.unitTypeCode
    this.unitType = unitTypes.getByEsUnitType(this.esUnitType)

    foreach (p in unitIntParams)
      this[p] = uWpCost?[p] ?? 0

    this.cost                      = uWpCost?.value || 0
    this.freeRepairs               = uWpCost?.freeRepairs ?? warpoints?.freeRepairs ?? 0
    this.expMul                    = uWpCost?.expMul ?? 1.0
    this.shopCountry               = uWpCost?.country ?? ""
    this.trainCost                 = uWpCost?.trainCost ?? warpoints?.trainCostByRank[$"rank{this.rank}"] ?? 0
    this.gift                      = uWpCost?.gift
    this.giftParam                 = uWpCost?.giftParam
    this.event                     = uWpCost?.event
    this.premPackAir               = uWpCost?.premPackAir ?? false
    this.hasDepthCharge            = uWpCost?.hasDepthCharge ?? false
    this.commonWeaponImage         = uWpCost?.commonWeaponImage ?? this.commonWeaponImage
    this.customClassIco            = uWpCost?.customClassIco
    this.customTooltipImage        = uWpCost?.customTooltipImage
    this.isPkgDev                  = ::is_dev_version && (uWpCost?.pkgDev ?? false)
    this.researchType              = uWpCost?.researchType
    this.hideBrForVehicle          = this.tags.contains("hideBrForVehicle")
    this.showShortestUnitInfo      = this.tags.contains("showShortestUnitInfo")
    this.hasWeaponSlots            = uWpCost?.hasWeaponSlots ?? false

    foreach (weapon in this.weapons)
      weapon.type <- ::g_weaponry_types.WEAPON.type

    if (uWpCost?.weapons != null) {
      if (this.hasWeaponSlots)
        initUnitWeaponsContainers(this.weaponsContainers, uWpCost.weapons)
      initUnitWeapons(this, this.weapons, uWpCost.weapons)
      initWeaponryUpgrades(this, uWpCost)
    }

    let errorsTextArray = initUnitModifications(this.modifications,
      uWpCost?.modifications ?? ::get_full_unit_blk(this.name)?.modifications, this.esUnitType)
    if (uWpCost?.spare != null) {
      let spareBlk = get_modifications_blk()?.modifications.spare

      this.spare = {
        name = "spare"
        type = ::g_weaponry_types.SPARE.type
        cost = uWpCost?.spare.value || 0
        image = ::get_weapon_image(this.esUnitType, spareBlk, uWpCost?.spare)
        animation = spareBlk && (spareBlk % "animationByUnit")
          .findvalue((@(anim) anim.unitType == this.esUnitType).bindenv(this))?.src
      }
      if (uWpCost?.spare.costGold != null)
        this.spare.costGold <- uWpCost.spare.costGold
    }

    for (local i = 1; i <= MOD_TIERS_COUNT; i++)
      this.needBuyToOpenNextInTier.append(uWpCost?[$"needBuyToOpenNextInTier{i}"] ?? 0)

    this.customImage = uWpCost?.customImage ?? ::get_unit_preset_img(this.name)
    if (!this.customImage && ::is_harmonized_unit_image_reqired(this))
      this.customImage = ::get_tomoe_unit_icon(this.name)
    if (this.customImage && !isInArray(this.customImage.slice(0, 1), ["#", "!"]))
      this.customImage = ::get_unit_icon_by_unit(this, this.customImage)
    shopSearchCore.cacheUnitSearchTokens(this)

    return errorsTextArray
  }

  function hasPlatformFromBlkStr(blk, fieldName, defValue = false, separator = "; ") {
    let listStr = blk?[fieldName]
    if (!isString(listStr))
      return defValue
    return split_by_chars(listStr, separator).contains(targetPlatform)
  }

  function applyShopBlk(shopUnitBlk, prevShopUnitName, unitGroupName = null) {
    this.isInShop = true
    this.reqAir = prevShopUnitName
    this.futureReqAir = shopUnitBlk?.futureReqAir
    this.futureReqAirDesc = shopUnitBlk?.futureReqAirDesc
    this.group = unitGroupName
    if ("fakeReqUnitType" in shopUnitBlk)
      this.fakeReqUnits = shopUnitBlk % "fakeReqUnitType"

    let isVisibleUnbought = !shopUnitBlk?.showOnlyWhenBought
      && this.hasPlatformFromBlkStr(shopUnitBlk, "showByPlatform", true)
      && !this.hasPlatformFromBlkStr(shopUnitBlk, "hideByPlatform", false)

    this.showOnlyWhenBought = !isVisibleUnbought
    this.showOnlyWhenResearch = shopUnitBlk?.showOnlyWhenResearch ?? false
    this.isCrossPromo = !!shopUnitBlk?.isCrossPromo
    this.crossPromoBanner = shopUnitBlk?.crossPromoBanner

    if (isVisibleUnbought && isString(shopUnitBlk?.hideForLangs))
      this.hideForLangs = split_by_chars(shopUnitBlk?.hideForLangs, "; ")

    foreach (key in ["reqFeature", "hideFeature", "showOnlyIfPlayerHasUnlock", "reqUnlock"])
      if ((shopUnitBlk?[key] ?? "") != "")
        this[key] = shopUnitBlk[key]

    this.gift = shopUnitBlk?.gift //we already got it from wpCost. is we still need it here?
    this.giftParam = shopUnitBlk?.giftParam
    this.marketplaceItemdefId = shopUnitBlk?.marketplaceItemdefId
    this.disableFlyout = shopUnitBlk?.disableFlyout ?? false
  }

  isAir                 = @() this.esUnitType == ES_UNIT_TYPE_AIRCRAFT
  isTank                = @() this.esUnitType == ES_UNIT_TYPE_TANK
  isShip                = @() this.esUnitType == ES_UNIT_TYPE_SHIP
  isBoat                = @() this.esUnitType == ES_UNIT_TYPE_BOAT
  isShipOrBoat          = @() this.esUnitType == ES_UNIT_TYPE_SHIP || this.esUnitType == ES_UNIT_TYPE_BOAT
  isSubmarine           = @() this.esUnitType == ES_UNIT_TYPE_SHIP && this.tags.indexof("submarine") != null
  isHelicopter          = @() this.esUnitType == ES_UNIT_TYPE_HELICOPTER
  isHuman               = @() this.esUnitType == ES_UNIT_TYPE_TANK && this.tags.indexof("type_exoskeleton") != null
  //



  getUnitWpCostBlk      = @() get_wpcost_blk()?[this.name]
  isBought              = @() ::shop_is_aircraft_purchased(this.name)
  isUsable              = @() ::shop_is_player_has_unit(this.name)
  isRented              = @() ::shop_is_unit_rented(this.name)
  isBroken              = @() ::isUnitBroken(this)
  isResearched          = @() ::isUnitResearched(this)
  isInResearch          = @() ::isUnitInResearch(this)
  getRentTimeleft       = @() ::rented_units_get_expired_time_sec(this.name)
  getRepairCost         = @() Cost(::wp_get_repair_cost(this.name))
  getCrewTotalCount     = @() this.getUnitWpCostBlk()?.crewTotalCount || 1
  getCrewUnitType       = @() this.unitType.crewUnitType
  getExp                = @() ::getUnitExp(this)

  _endRecentlyReleasedTime = null
  function getEndRecentlyReleasedTime() {
    if (this._endRecentlyReleasedTime != null)
      return this._endRecentlyReleasedTime

    this._endRecentlyReleasedTime = -1
    let releaseDate = get_unittags_blk()?[this.name].releaseDate
    if (releaseDate == null)
      return this._endRecentlyReleasedTime

    let recentlyReleasedUnitsDays = GUI.get()?.markRecentlyReleasedUnitsDays ?? 0
    if (recentlyReleasedUnitsDays == 0)
      return this._endRecentlyReleasedTime

    this._endRecentlyReleasedTime = time.getTimestampFromStringUtc(releaseDate)
      + time.daysToSeconds(recentlyReleasedUnitsDays)
    return this._endRecentlyReleasedTime
  }

  _isRecentlyReleased = null
  function isRecentlyReleased() {
    if (this._isRecentlyReleased != null)
      return this._isRecentlyReleased

    this._isRecentlyReleased = this.getEndRecentlyReleasedTime() > get_charserver_time_sec()
    return this._isRecentlyReleased
  }

  _operatorCountry = null
  function getOperatorCountry() {
    if (this._operatorCountry)
      return this._operatorCountry
    local res = get_unittags_blk()?[this.name].operatorCountry ?? ""
    this._operatorCountry = res != "" && getCountryIcon(res) != "" ? res : this.shopCountry
    return this._operatorCountry
  }

  function getEconomicRank(ediff) {
    return ::get_unit_blk_economic_rank_by_mode(this.getUnitWpCostBlk(), ediff)
  }

  function getBattleRating(ediff) {
    if (!::CAN_USE_EDIFF)
      ediff = ediff % EDIFF_SHIFT
    let mrank = this.getEconomicRank(ediff)
    return ::calc_battle_rating_from_rank(mrank)
  }

  function getCostRepairPerMin(diff) {
    let wp = this.getUnitWpCostBlk()?[$"repairCostPerMin{diff.getEgdName()}"]
    return wp ? Cost(wp) : null
  }

  function getWpRewardMulList(difficulty = ::g_difficulty.ARCADE) {
    let warpoints = get_warpoints_blk()
    let uWpCost = this.getUnitWpCostBlk()
    let mode = difficulty.getEgdName()

    let isSpecial = ::isUnitSpecial(this)
    let premPart = isSpecial ? warpoints?.rewardMulVisual?.premRewardMulVisualPart ?? 0.5 : 0.0
    let mul = (uWpCost?["rewardMul" + mode] ?? 1.0) *
      (warpoints?.rewardMulVisual?["rewardMulVisual" + mode] ?? 1.0)
    let timedAward = uWpCost?[$"timedAward{mode}"] ?? 0

    return {
      wpMul   = stdMath.round_by_value(mul * (1.0 - premPart), isSpecial ? 0.05 : 0.1)
      wpTimed = timedAward * (1.0 - premPart)
      premMul = stdMath.round_by_value(1.0 / (1.0 - premPart), 0.1)
    }
  }

  function _tostring() {
    return "Unit( " + this.name + " )"
  }

  function canAssignToCrew(country) {
    return getUnitCountry(this) == country && this.canUseByPlayer()
  }

  function canUseByPlayer() {
    return this.isUsable() && this.isVisibleInShop() && this.unitType.isAvailable()
  }

  function isVisibleInShop() {
    if (!this.isInShop || !this.unitType.isVisibleInShop())
      return false
    if (::is_debug_mode_enabled || this.isUsable())
      return true
    if (this.showOnlyWhenBought)
      return false
    if (this.hideForLangs && this.hideForLangs.indexof(getLanguageName()) != null)
      return false
    if (this.showOnlyIfPlayerHasUnlock && !isUnlockOpened(this.showOnlyIfPlayerHasUnlock))
      return false
    if (this.showOnlyWhenResearch && !this.isInResearch() && this.getExp() <= 0)
      return false
    if (this.hideFeature != null && hasFeature(this.hideFeature))
      return false
    if (isUnitGift(this) && !canSpendRealMoney())
      return false
    if (shopPromoteUnits.value?[this.name] != null && !promoteUnits.value?[this.name].isActive)
      return false
    return true
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function resetSkins() {
    this.skins = []
    this.skinsBlocks = {}
  }

  function getSkins() {
    if (this.skins.len() == 0)
      this.skins = get_skins_for_unit(this.name) //always returns at least one entry
    return this.skins
  }

  function getSkinBlockById(skinId) {
    if (!this.skinsBlocks.len()) //Will be default skin at least.
      foreach (skin in this.getSkins())
        this.skinsBlocks[skin.name] <- skin

    return this.skinsBlocks?[skinId]
  }

  function getPreviewSkinId() {
    if (!this.previewSkinId) {
      this.previewSkinId = ""
      foreach (skin in this.getSkins())
        if (getDecorator(this.name + "/" + skin.name, decoratorTypes.SKINS)?.blk?.useByDefault)
          this.previewSkinId = skin.name
    }
    return this.previewSkinId
  }

  getSpawnScore = @(weaponName = null) ::shop_get_spawn_score(this.name, weaponName || getLastWeapon(this.name), [])

  function getMinimumSpawnScore() {
    local res = -1
    foreach (weapon in this.getWeapons())
      if (isWeaponVisible(this, weapon) && isWeaponEnabled(this, weapon)) {
        let spawnScore = this.getSpawnScore(weapon.name)
        if (res < 0 || res > spawnScore)
          res = spawnScore
      }
    return max(res, 0)
  }

  function invalidateModificators() {
    if (this.modificatorsRequestTime > 0) {
      ::remove_calculate_modification_effect_jobs()
      this.modificatorsRequestTime = -1
    }
    this.modificators = null
  }

  function canPreview() {
    return this.isInShop
  }

  function doPreview() {
    if (this.canPreview())
      contentPreview.showUnitSkin(this.name)
  }

  isDepthChargeAvailable = @() this.hasDepthCharge || shopIsModificationEnabled(this.name, "ship_depth_charge")

  function getNVDSights(modName) {
    if (!this.isTank())
      return []

    this.initNVDSightsOnce()
    return this.nvdSights?[modName] ?? []
  }

  function initNVDSightsOnce() {
    if (this.nvdSights)
      return

    this.nvdSights = {}
    eachBlock(::get_full_unit_blk(this.name)?.modifications, function(mode, modeName) {
      this.nvdSights[modeName] <- []
      eachBlock(mode?.effects.nightVision, @(_, name) this.nvdSights[modeName].append(name), this) //-ident-hides-ident
    }, this)
  }

  function getDefaultWeapon() {
    if (this.defaultWeaponPreset)
      return this.defaultWeaponPreset

    let unitBlk = ::get_full_unit_blk(this.name)
    if (!unitBlk)
      return null

    this.defaultWeaponPreset = getDefaultPresetId(unitBlk)
    return this.defaultWeaponPreset
  }

  function getEntitlements() {
    if (this.gift == null)
      return []

    return ::OnlineShopModel.searchEntitlementsByUnit(this.name)
  }

  function getUnlockImage() {
    if (this.isAir())
      return "#ui/gameuiskin#blueprint_items_aircraft"
    if (this.isTank())
      return "#ui/gameuiskin#blueprint_items_tank"
    if (this.isShipOrBoat())
      return "#ui/gameuiskin#blueprint_items_ship"

    return "#ui/gameuiskin#blueprint_items_aircraft"
  }

  isSquadronVehicle       = @() this.researchType == "clanVehicle"
  getOpenCost             = @() Cost(0, ::clan_get_unit_open_cost_gold(this.name))
  getWeapons = function() {
    if (!this.hasWeaponSlots || !hasFeature("WeaponryCustomPresets"))
      return this.weapons

    return [].extend(this.weapons, getWeaponryCustomPresets(this))
  }
}

u.registerClass("Unit", Unit, @(u1, u2) u1.name == u2.name, @(unit) !unit.name.len())

return Unit