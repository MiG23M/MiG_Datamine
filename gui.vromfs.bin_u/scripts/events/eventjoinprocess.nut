//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { get_time_msec } = require("dagor.time")
let stdMath = require("%sqstd/math.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let tryOpenCaptchaHandler = require("%scripts/captcha/captchaHandler.nut")

const PROCESS_TIME_OUT = 60000

let activeEventJoinProcess = []

let hasAlredyActiveJoinProcess = @() activeEventJoinProcess.len() > 0
  && (get_time_msec() - activeEventJoinProcess[0].processStartTime) < PROCESS_TIME_OUT

let function setSquadReadyFlag(event) {
  //Don't allow to change ready status, leader don't know about members balance
  if (!::events.haveEventAccessByCost(event))
    showInfoMsgBox(loc("events/notEnoughMoney"))
  else if (::events.eventRequiresTicket(event) && ::events.getEventActiveTicket(event) == null)
    ::events.checkAndBuyTicket(event)
  else
    ::g_squad_manager.setReadyFlag()
}

::EventJoinProcess <- class {
  event = null // Event to join.
  room = null
  onComplete = null
  cancelFunc = null

  processStartTime = -1
  processStepName = ""

  constructor(v_event, v_room = null, v_onComplete = null, v_cancelFunc = null) {
    if (!v_event)
      return

    this.event = v_event
    this.room = v_room
    this.onComplete = v_onComplete
    this.cancelFunc = v_cancelFunc

    if (activeEventJoinProcess.len()) {
      let prevProcessStartTime = activeEventJoinProcess[0].processStartTime
      if (get_time_msec() - prevProcessStartTime < PROCESS_TIME_OUT) {
        let eventName = v_event.name // warning disable: -declared-never-used
        let prevProcessStepName = activeEventJoinProcess[0].processStepName // warning disable: -declared-never-used
        return assert(false, "Error: trying to use 2 join event processes at once")
      }
      else
        activeEventJoinProcess[0].remove()
    }
    activeEventJoinProcess.append(this)
    this.processStartTime = get_time_msec()
    this.joinStep1_squadMember()
  }

  function remove(needCancelFunc = true) {
    foreach (idx, process in activeEventJoinProcess)
      if (process == this)
        activeEventJoinProcess.remove(idx)

    if (needCancelFunc && this.cancelFunc != null)
      this.cancelFunc()
  }

  function onDone() {
    if (this.onComplete != null)
      this.onComplete(this.event)
    this.remove(false)
  }

  function joinStep1_squadMember() {
    this.processStepName = "joinStep1_squadMember"

    if (::g_squad_manager.isSquadMember()) {
      if (!::g_squad_manager.isMeReady()) {
        let handler = this
        tryOpenCaptchaHandler(@() setSquadReadyFlag(handler.event))
      }
      else
        this.setSquadReadyFlag(this.event)
      return this.remove()
    }

    if (!antiCheat.showMsgboxIfEacInactive(this.event) ||
        !showMsgboxIfSoundModsNotAllowed(this.event))
      return this.remove()

    let handler = this
    tryOpenCaptchaHandler(
      @() ::queues.checkAndStart(
        Callback(handler.joinStep2_external, handler),
        Callback(handler.remove, handler),
        "isCanNewflight",
        { isSilentLeaveQueue = !!handler.room }
      ),
      @() handler.remove())
  }

  function joinStep2_external() {
    this.processStepName = "joinStep2_external"
    if (::events.getEventDiffCode(this.event) == DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return this.remove()

    if (!::events.checkEventFeature(this.event))
      return this.remove()

    if (!::events.isEventAllowedByComaptibilityMode(this.event)) {
      showInfoMsgBox(loc("events/noCompatibilityMode/msg"))
      this.remove()
      return
    }

    if (!::g_squad_utils.isEventAllowedForAllMembers(::events.getEventEconomicName(this.event)))
      return this.remove()

    if (!::events.checkEventFeaturePacks(this.event))
      return this.remove()

    if (!::is_loaded_model_high_quality()) {
      ::check_package_and_ask_download("pkg_main", null, this.joinStep3_internal, this, "event", this.remove)
      return
    }

    this.joinStep3_internal()
  }

  function joinStep3_internal() {
    this.processStepName = "joinStep3_internal"
    let mGameMode = ::events.getMGameMode(this.event, this.room)
    if (::events.isEventTanksCompatible(this.event.name) && !::check_tanks_available())
      return this.remove()
    if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.EVENT) ||
        !::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true, showOfflineSquadMembersPopup = true }))
      return this.remove()
    if (::events.checkEventDisableSquads(this, this.event.name))
      return this.remove()
    if (!this.checkEventTeamSize(mGameMode))
      return this.remove()
    let diffCode = ::events.getEventDiffCode(this.event)
    let unitTypeMask = ::events.getEventUnitTypesMask(this.event)
    let checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask) == 1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if (checkDiffTutorial(diffCode, checkTutorUnitType))
      return this.remove()

    this.joinStep4_cantJoinReason()
  }

  function joinStep4_cantJoinReason() {
    this.processStepName = "joinStep4_cantJoinReason"
    let reasonData = ::events.getCantJoinReasonData(this.event, this.room,
                          { continueFunc = function() { if (this) this.joinStep5_repairInfo() }.bindenv(this)
                            isFullText = true
                          })
    if (reasonData.checkStatus)
      return this.joinStep5_repairInfo()

    reasonData.actionFunc(reasonData)
    this.remove()
  }

  function joinStep5_repairInfo() {
    this.processStepName = "joinStep5_repairInfo"
    let repairInfo = ::events.getCountryRepairInfo(this.event, this.room, profileCountrySq.value)
    ::checkBrokenAirsAndDo(repairInfo, this, this.joinStep6_membersForQueue, false, this.remove)
  }

  function joinStep6_membersForQueue() {
    this.processStepName = "joinStep6_membersForQueue"
    ::events.checkMembersForQueue(this.event, this.room,
      Callback(@(membersData) this.joinStep7_joinQueue(membersData), this),
      Callback(this.remove, this)
    )
  }

  function joinStep7_joinQueue(membersData = null) {
    this.processStepName = "joinStep7_joinQueue"
    //join room
    if (this.room)
      ::SessionLobby.joinRoom(this.room.roomId)
    else {
      let joinEventParams = {
        mode    = this.event.name
        //team    = team //!!can choose team correct only with multiEvents support
        country = profileCountrySq.value
      }
      if (membersData)
        joinEventParams.members <- membersData
      ::queues.joinQueue(joinEventParams)
    }

    this.onDone()
  }

  //
  // Helpers
  //

  function checkEventTeamSize(ev) {
    let squadSize = ::g_squad_manager.getSquadSize()
    let maxTeamSize = ::events.getMaxTeamSize(ev)
    if (squadSize > maxTeamSize) {
      let locParams = {
        squadSize = squadSize.tostring()
        maxTeamSize = maxTeamSize.tostring()
      }
      this.msgBox("squad_is_too_big", loc("events/squad_is_too_big", locParams),
        [["ok", function() {}]], "ok")
      return false
    }
    return true
  }

  //
  // Delegates from current base gui handler.
  //

  function msgBox(id, text, buttons, def_btn, options = {}) {
    scene_msg_box(id, null, text, buttons, def_btn, options)
  }
}


return {
  hasAlredyActiveJoinProcess
}