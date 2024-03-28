from "%scripts/dagui_library.nut" import *

let { invert } = require("%sqstd/underscore.nut")
let { setCurrentGameModeById } = require("%scripts/gameModes/gameModeManagerState.nut")

let activityToGameMode = {
  air_event_arcade = "air_arcade"
  air_event_historical = "air_realistic"
  air_event_simulator = "custom_mode_fullreal"
  tank_event_arcade = "tank_event_in_random_battles_arcade"
  tank_event_historical = "tank_event_in_random_battles_historical"
  ship_event_arcade = "ship_event_in_random_battles_arcade"
  ship_event_historical = "ship_event_in_random_battles_realistic"
}

let gameModeToActivity = invert(activityToGameMode)
gameModeToActivity["air_simulation_timeDelay_battles"] <- "air_event_simulator"

function getGameModeByActivity(activity) { return activity && activityToGameMode?[activity] }
function getActivityByGameMode(mode) { return mode && gameModeToActivity?[mode] }

function switchGameModeByGameIntent(intent) {
  let gameModeId = getGameModeByActivity(intent.activityId)
  if (gameModeId) {
    log($"[PSGI] switching game mode to {gameModeId}")
    setCurrentGameModeById(gameModeId);
    return
  }
  log($"[PSGI] game mode not found for {intent.activityId} ")
}

return {
  getGameModeByActivity
  getActivityByGameMode
  switchGameModeByGameIntent
}


