#strict
#allow-root-table
//pseudo-module for native code
from "%scripts/dagui_natives.nut" import epic_is_running, save_common_local_settings
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let ww_leaderboard = require("ww_leaderboard")
let { get_local_unixtime   } = require("dagor.time")
let { rnd                  } = require("dagor.random")
let { format               } = require("string")
let { json_to_string       } = require("json")
let { getDistr             } = require("auth_wt")
let { get_user_system_info } = require("sysinfo")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { get_settings_blk, get_common_local_settings_blk } = require("blkGetters")
let { steam_is_running, steam_get_my_id } = require("steam")

local bqStat = persist("bqStat", @() { sendStartOnce = false })


function get_distr() {
  local distr = getDistr()
  if (distr.len() > 0)
    return distr

  let config = get_settings_blk()
  distr = config?.distr ?? config?.originalConfigBlk.distr

  return (type(distr) == "string" && distr.len() > 0) ? distr : ""
}


function add_sysinfo(table) {
  let sysinfo = get_user_system_info()

  local uuid = ""
  foreach (u in ["uuid0", "uuid2"]) {  // biosUuid, systemHddId
    local str = sysinfo?[u] ?? ""
    str = str.slice(str.len() / 2)
    uuid = $"{uuid}{str}"
  }

  if (uuid.len() > 0)
    table.uuid <- uuid

  if (sysinfo?.osCompatibility == true)
    table.compat <- true

  if (sysinfo?.is64bitClient == false)
    table.game32 <- true

  assert(platformId.len() > 0)
  table.os <- platformId
}


function add_user_info(table) {
  add_sysinfo(table)

  let distr = get_distr()
  if (distr.len() > 0)
    table.distr <- distr

  if (steam_is_running()) {
    table.steam <- true

    let steamId = steam_get_my_id()
    if (steamId > 0)
      table.steamId <- steamId
  }

  if (epic_is_running())
    table.epic <- true

  if (is_dev_version())
    table.dev <- true
}


function bq_client_no_auth(event, uniqueId, table) {
  add_user_info(table)

  let params = json_to_string(table, false)
  let request =
  {
    action = "noa_bigquery_client_noauth"
    add_token = false
    headers =
    {
      appid = 1067,
      uniqueId,
      event,
      params
    }
    data = {}
  }

  ww_leaderboard.request(request, function(_response) {})  // cloud-server
  log($"BQ CLIENT_NO_AUTH {event} {params} [{uniqueId}]")
}


function bqSendStart() {  // NOTE: call after 'reset PlayerProfile' in log
  if (bqStat.sendStartOnce)
    return

  local blk = get_common_local_settings_blk()

  if ("uniqueId" not in blk || type(blk.uniqueId) != "string" || blk.uniqueId.len() < 16) {
    blk.uniqueId <- format("%.8X%.8X", get_local_unixtime(), rnd() * rnd())
    assert(blk.uniqueId.len() == 16)
  }

  if ("runCount" not in blk || type(blk.runCount) != "integer" || blk.runCount < 0) {
    blk.runCount <- 0;
  }
  blk.runCount += 1

  save_common_local_settings()

  local table = { "run" : blk.runCount }
  if (blk?.autologin == true)
    table.auto <- true

  bq_client_no_auth("start", blk.uniqueId, table)

  bqStat.sendStartOnce = true
}


function bqSendLoginState(table) {
  let blk = get_common_local_settings_blk()

  table.uniq <- blk?.uniqueId ?? ""
  table.run  <- blk?.runCount ?? -1
  if (blk?.autologin == true)
    table.auto <- true

  add_user_info(table)
  let params = json_to_string(table)

  sendBqEvent("CLIENT_LOGIN_2", "login_state", table)
  log($"BQ CLIENT login_state {params}")
}


return {
  bqSendStart,
  bqSendLoginState
}
