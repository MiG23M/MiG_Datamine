//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let time = require("%scripts/time.nut")
let avatars = require("%scripts/user/avatars.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { eachParam, eachBlock } = require("%sqstd/datablock.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")

let statsFm = ["fighter", "bomber", "assault"]
let statsTanks = ["tank", "tank_destroyer", "heavy_tank", "SPAA"]
let statsShips = [
  "torpedo_boat"
  "gun_boat"
  "torpedo_gun_boat"
  "submarine_chaser"
  "destroyer"
  "naval_ferry_barge"
  "cruiser"
]
let statsHelicopters = ["helicopter"]
statsFm.extend(statsHelicopters)
statsFm.extend(statsTanks)
statsFm.extend(statsShips)
let statsConfig = [
  {
    name = "mainmenu/titleVersus"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "pvp_played"  //!! mode incoming by ::get_player_public_stats
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = "pvp_played"
  }
  {
    id = "respawns"
    name = "stats/flights"
    mode = "pvp_played"
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = "pvp_played"
    separateRowsByFm = true
    timeFormat = true
  }
  {
    id = "air_kills"
    name = "stats/kills_air"
    mode = "pvp_played"
  }
  {
    id = "ground_kills"
    name = "stats/kills_ground"
    mode = "pvp_played"
  }
  {
    id = "naval_kills"
    name = "stats/kills_naval"
    mode = "pvp_played"
  }

  {
    name = "mainmenu/btnSkirmish"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "skirmish_played"
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = "skirmish_played"
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = "skirmish_played"
    timeFormat = true
  }

  {
    name = "mainmenu/btnPvE"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = ["dynamic_played", "builder_played", "single_played"] //"campaign_played"
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = ["dynamic_played", "builder_played", "single_played"]
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = ["dynamic_played", "builder_played", "single_played"]
    timeFormat = true
  }
]

let defaultSummaryItem = {
  id = ""
  name = ""
  mode = null
  fm = null
  header = false
  separateRowsByFm = false
  timeFormat = false
  reqFeature = null
}
foreach (idx, stat in statsConfig)
  foreach (param, value in defaultSummaryItem)
    if (!(param in stat))
      statsConfig[idx][param] <- value

let airStatsListConfig = [
  { id = "victories", icon = "lb_each_player_victories", text = "multiplayer/each_player_victories" },
  { id = "sessions", icon = "lb_each_player_session", text = "multiplayer/each_player_session"
    countFunc = function(statBlk) {
      local sessions = statBlk?.victories ?? 0
      sessions += statBlk?.defeats ?? 0
      return sessions
    }
  },
  { id = "victories_battles", type = lbDataType.PERCENT
    countFunc = function(statBlk) {
      let victories = statBlk?.victories ?? 0
      let sessions = victories + (statBlk?.defeats ?? 0)
      if (sessions > 0)
        return victories.tofloat() / sessions
      return 0
    }
  },
  "flyouts",
  "deaths",
  "air_kills",
  "ground_kills",
  { id = "naval_kills", icon = "lb_naval_kills", text = "multiplayer/naval_kills" },
  { id = "wp_total", icon = "lb_wp_total_gained", text = "multiplayer/wp_total_gained", ownProfileOnly = true },
  { id = "online_exp_total", icon = "lb_online_exp_gained_for_common", text = "multiplayer/online_exp_gained_for_common" },
]
foreach (idx, val in airStatsListConfig) {
  if (type(val) == "string")
    airStatsListConfig[idx] = { id = val }
  if ("type" not in airStatsListConfig[idx])
    airStatsListConfig[idx].type <- lbDataType.NUM
}

let function getAirsStatsFromBlk(blk) {
  let res = {}
  eachBlock(blk, function(diffBlk, diffName) {

    let diffData = {}
    eachBlock(diffBlk, function(typeBlk, typeName) {

      let typeData = []
      eachBlock(typeBlk, function(airBlk, airName) {

        let airData = { name = airName }
        foreach (stat in airStatsListConfig) {
          if ("reqFeature" in stat && !hasAllFeatures(stat.reqFeature))
            continue

          if ("countFunc" in stat)
            airData[stat.id] <- stat.countFunc(airBlk)
          else
            airData[stat.id] <- airBlk?[stat.id] ?? 0
        }
        typeData.append(airData)
      })
      if (typeData.len() > 0)
        diffData[typeName] <- typeData
    })
    if (diffData.len() > 0)
      res[diffName] <- diffData
  })
  return res
}

let function buildProfileSummaryRowData(config, summary, diffCode, textId = "") {
  let diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
  if (diff == ::g_difficulty.UNKNOWN)
    return null

  let modeList = (type(config.mode) == "array") ? config.mode : [config.mode]
  local value = 0
  foreach (mode in modeList) {
    let sumData = summary?[mode]?[diff.name]
    if (!sumData)
      continue

    if (config.fm == null) {
      if (config.id in sumData)
        value += sumData[config.id]
      else
        for (local i = 0; i < statsFm.len(); i++)
          if ((statsFm[i] in sumData) && (config.id in sumData[statsFm[i]]))
            value += sumData[statsFm[i]][config.id]
    }
    else if ((config.fm in sumData) && (config.id in sumData[config.fm]))
        value += sumData[config.fm][config.id]
  }

  if (config.fm != null && config.id == "timePlayed" && value < time.TIME_MINUTE_IN_SECONDS)
    return null

  let s = config.timeFormat
    ? time.hoursToString(time.secondsToHours(value), false)
    : value.tostring()

  let row = [
    { id = textId, text = "#" + config.name, tdalign = "left" },
    { text = s, tooltip = diff.getLocName() }
  ]

  return ::buildTableRowNoPad("", row)
}

let function fillProfileSummary(sObj, summary, diff) {
  if (!checkObj(sObj))
    return

  let guiScene = sObj.getScene()
  local data = ""
  let textsToSet = {}
  foreach (idx, item in statsConfig) {
    if (!hasAllFeatures(item.reqFeature))
      continue

    if (item.header)
      data += ::buildTableRowNoPad("", ["#" + item.name], null,
                  format("headerRow:t='%s'; ", idx ? "yes" : "first"))
    else if (item.separateRowsByFm)
      for (local i = 0; i < statsFm.len(); i++) {
        let rowId = "row_" + idx + "_" + i
        item.fm = statsFm[i]
        let row = buildProfileSummaryRowData(item, summary, diff, rowId)
        if (!row)
          continue

        data += row
        textsToSet["txt_" + rowId] <- loc(item.name) + " (" + loc("mainmenu/type_" + statsFm[i].tolower()) + ")"
      }
    else {
      let row = buildProfileSummaryRowData(item, summary, diff)
      if (row)
        data += row
    }
  }

  guiScene.replaceContentFromText(sObj, data, data.len(), this)
  foreach (id, text in textsToSet)
    sObj.findObject(id).setValue(text)
}

let function getCountryMedals(countryId, profileData = null) {
  let res = []
  let medalsList = profileData?.unlocks?.medal ?? []
  let unlocks = getUnlocksByTypeInBlkOrder("medal")
  foreach (cb in unlocks)
    if (cb?.country == countryId)
      if ((!profileData && isUnlockOpened(cb.id, UNLOCKABLE_MEDAL)) || (medalsList?[cb.id] ?? 0) > 0)
        res.append(cb.id)
  return res
}

let function getPlayerStatsFromBlk(blk) {
  let player = {
    name = blk?.nick
    lastDay = blk?.lastDay
    registerDay = blk?.registerDay
    title = blk?.title ?? ""
    titles = (blk?.titles ?? DataBlock()) % "name"
    clanTag = blk?.clanTag ?? ""
    clanName = blk?.clanName ?? ""
    clanType = blk?.clanType ?? 0
    exp = blk?.exp ?? 0

    rank = 0
    rankProgress = 0
    prestige = 0

    unlocks = {}
    countryStats = {}

    icon = avatars.getIconById(blk?.icon)

    aircrafts = []
    crews = []

    //stats & leaderboards
    summary = blk?.summary ? ::buildTableFromBlk(blk.summary) : {}
    userstat = blk?.userstat ? getAirsStatsFromBlk(blk.userstat) : {}
    leaderboard = blk?.leaderboard ? ::buildTableFromBlk(blk.leaderboard) : {}
  }

  if (blk?.userid != null)
    player.uid <- blk.userid

  player.rank = ::get_rank_by_exp(player.exp)
  player.rankProgress = ::calc_rank_progress(player)

  player.prestige = ::get_prestige_by_rank(player.rank)

  //unlocks
  eachBlock(blk?.unlocks, function(uBlk, unlock) {
    let uType = uBlk?.type
    if (!uType)
      return

    if (!(uType in player.unlocks))
      player.unlocks[uType] <- {}
    player.unlocks[uType][unlock] <- uBlk?.stage ?? 1
  })

  foreach (_i, country in shopCountriesList) {
    let cData = {
      medalsCount = getCountryMedals(country, player).len()
      unitsCount = 0
      eliteUnitsCount = 0
    }
    if (blk?.aircrafts?[country]) {
      cData.unitsCount = blk.aircrafts[country].paramCount()
      eachParam(blk.aircrafts[country], function(unitEliteStatus) {
        if (::isUnitEliteByStatus(unitEliteStatus))
          cData.eliteUnitsCount++
      })
    }
    player.countryStats[country] <- cData
  }

  //aircrafts list
  eachBlock(blk?.aircrafts, @(_, airName) player.aircrafts.append(airName))

  //same with ::g_crews_list.get()
  eachBlock(blk?.slots, function(crewBlk, country) {
    let countryData = { country, crews = [] }
    eachParam(crewBlk, @(_, aircraft) countryData.crews.append({ aircraft }))
    player.crews.append(countryData)
  })

  return player
}

return {
  fillProfileSummary
  getCountryMedals
  getPlayerStatsFromBlk
  airStatsListConfig
}
