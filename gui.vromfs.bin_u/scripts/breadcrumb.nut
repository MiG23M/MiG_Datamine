//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let backToMainScene = require("%scripts/mainmenu/backToMainScene.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
local lastBaseHandlerStartData = null

let function updateBackSceneObj(handler) {
  handler.backSceneParams = lastBaseHandlerStartData?.handlerLocId
    ? lastBaseHandlerStartData?.startParams : backToMainScene()
  let handlerLocId = lastBaseHandlerStartData?.handlerLocId ?? "mainmenu/hangar"
  let backSceneObj = handler.scene.findObject("back_scene_name")
  if (!backSceneObj?.isValid())
    return

  backSceneObj.setValue(loc(handlerLocId))
}

let function setBreadcrumbGoBackParams(handler) {
  if (!handler.isValid())
    return

  if (!lastBaseHandlerStartData)
    lastBaseHandlerStartData = clone handlersManager.findLastBaseHandlerStartData(handler.guiScene)
  updateBackSceneObj(handler)
}

let function setModalBreadcrumbGoBackParams(handler) {
  if (!handler.isValid())
    return

  let activeHandler = handlersManager.getActiveBaseHandler()
  if (!activeHandler.isValid())
    return

  lastBaseHandlerStartData = clone handlersManager.findLastBaseHandlerStartData(
    activeHandler.guiScene)
  updateBackSceneObj(handler)
}

add_event_listener("SwitchedBaseHandler", function(_p) {
  let handlerClass = handlersManager.getActiveBaseHandler()?.getclass()
  if (handlerClass == gui_handlers.MainMenu || handlerClass == gui_handlers.Hud)
    lastBaseHandlerStartData = null
}, this)

return {
  setBreadcrumbGoBackParams
  setModalBreadcrumbGoBackParams
}