//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getFeaturePack } = require("%scripts/user/features.nut")

let eventIdsForMainGameModeList = [
  "tank_event_in_random_battles_arcade"
  "air_arcade"
]

let needShowOverrideSlotbar = @(event) event?.showEditSlotbar ?? false

let getCustomViewCountryData = @(event) event?.customViewCountry

let getEventEconomicName = @(event) event?.economicName ?? ""

let isLeaderboardsAvailable = @() !getSeparateLeaderboardPlatformValue()
  || hasFeature("ConsoleSeparateEventsLeaderboards")

let getEventTournamentMode = @(event) event?.tournament_mode ?? GAME_EVENT_TYPE.TM_NONE

function detectEventType(event_data) {
  local result = 0
  if (::my_stats.isNewbieEventId(event_data.name))
    result = EVENT_TYPE.NEWBIE_BATTLES
  else if ((event_data?.tournament ?? false)
    && getEventTournamentMode(event_data) != GAME_EVENT_TYPE.TM_NONE_RACE)
      result = EVENT_TYPE.TOURNAMENT
  else
    result = EVENT_TYPE.SINGLE
  if (event_data?.clanBattle ?? false)
    result = result | EVENT_TYPE.CLAN
  return result
}

function getEventType(event) {
  if (!("_type" in event))
    event._type <- detectEventType(event)
  return event._type
}

let isEventMatchesType = @(event, typeMask) event ? (getEventType(event) & typeMask) != 0 : false

let getEventDisplayType = @(event) event?._displayType ?? ::g_event_display_type.NONE

let setEventDisplayType = @(event, displayType) event._displayType <- displayType

let isEventForClan = @(event) isEventMatchesType(event, EVENT_TYPE.CLAN)

let isEventForNewbies = @(event) isEventMatchesType(event, EVENT_TYPE.NEWBIE_BATTLES)

function isEventRandomBattles(event) {
  if (getEventType(event) & EVENT_TYPE.NEWBIE_BATTLES)
    return false
  if (isInArray(event.name, eventIdsForMainGameModeList))
    return true
  return getEventDisplayType(event).canBeSelectedInGcDrawer()
}

let function isRaceEvent(event_data) {
  if (!("templates" in event_data))
    return false

  return isInArray("races_template", event_data.templates)
}

let isEventLastManStanding = @(event) ("mission_decl" in event) && ("br_area_change_time" in event.mission_decl)

let getEventRankCalcMode = @(event) event?.rankCalcMode

let isEnableFriendsJoin = @(event) event?.enableFriendsJoin ?? false

let isEventWithLobby = @(event) event?.withLobby ?? false

let getMaxLobbyDisbalance = @(event) event?.maxLobbyDisbalance ?? ::global_max_players_versus

let getEventReqFeature = @(event) event?.reqFeature ?? ""

let getEventPVETrophyName = @(event) event?.pveTrophyName ?? ""

function isEventVisibleByFeature(event) {
  let feature = getEventReqFeature(event)
  if (isEmpty(feature) || hasFeature(feature))
    return true
  return hasFeature("OnlineShopPacks") && ::OnlineShopModel.getFeaturePurchaseData(feature).canBePurchased
}

//when @checkFeature return pack only if player has feature access to event.
function getEventReqPack(event, checkFeature = false) {
  let feature = getEventReqFeature(event)
  if (isEmpty(feature) || (checkFeature && !hasFeature(feature)))
    return null
  return getFeaturePack(feature)
}

//return true if me and all my squad members has packs requeired by event feature
//show msgBox askingdownload when no silent
function checkEventFeaturePacks(event, isSilent = false) {
  let pack = getEventReqPack(event)
  if (!pack)
    return true
  return ::check_package_full(pack, isSilent)
}

let hasNightGameModes = @(event) event?.minMRankForNightBattles != null

return {
  eventIdsForMainGameModeList
  getEventEconomicName
  needShowOverrideSlotbar
  getCustomViewCountryData
  isLeaderboardsAvailable
  getEventTournamentMode
  getEventType
  isEventMatchesType
  getEventDisplayType
  setEventDisplayType
  isEventForClan
  isEventForNewbies
  isEventRandomBattles
  isRaceEvent
  isEventLastManStanding
  getEventRankCalcMode
  isEnableFriendsJoin
  isEventWithLobby
  getMaxLobbyDisbalance
  getEventReqFeature
  getEventPVETrophyName
  isEventVisibleByFeature
  getEventReqPack
  checkEventFeaturePacks
  hasNightGameModes
}