from "%rGui/globals/ui_library.nut" import *

let swapAB = gui_scene.circleButtonAsAction
gui_scene.config.setClickButtons([swapAB ? "J:B" : "J:A", "J:RT", "Space"])

return {
  A = swapAB ? "J:B" : "J:A"
  B = swapAB ?  "J:A" : "J:B"
}