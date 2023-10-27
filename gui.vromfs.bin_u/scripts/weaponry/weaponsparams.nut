//checked for plus_string
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")

let saclosMissileBeaconIRSourceBand = mkWatched(persist, "saclosMissileBeaconIRSourceBand", 4)
let reloadCooldownTimeByCaliber = mkWatched(persist, "reloadCooldownTimeByCaliber", {})


let function initWeaponParams() {
  let blk = DataBlock()
  blk.load("config/gameplay.blk")
  if (blk?.sensorsConstants)
    saclosMissileBeaconIRSourceBand(blk.sensorsConstants?.saclosMissileBeaconInfraRedBrightnessSourceBand ?? 4)

  reloadCooldownTimeByCaliber({})
  let cooldown_time = blk?.reloadCooldownTimeByCaliber
  if (!cooldown_time)
    return

  foreach (time in cooldown_time % "time")
    reloadCooldownTimeByCaliber.mutate(@(v) v[time.x] <- time.y) // warning disable: -iterator-in-lambda
}

return {
  saclosMissileBeaconIRSourceBand
  reloadCooldownTimeByCaliber
  initWeaponParams
}
