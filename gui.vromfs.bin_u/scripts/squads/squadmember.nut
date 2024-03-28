from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")

let class SquadMember {
  uid = ""
  name = ""
  rank = -1
  country = ""
  clanTag = ""
  pilotIcon = "cardicon_default"
  platform = ""
  online = false
  selAirs = null
  selSlots = null
  crewAirs = null
  brokenAirs = null
  missedPkg = null
  wwOperations = null
  isReady = false
  isCrewsReady = false
  canPlayWorldWar = false
  isWorldWarAvailable = false
  cyberCafeId = ""
  unallowedEventsENames = null
  sessionRoomId = ""
  crossplay = false
  bannedMissions = null
  dislikedMissions = null
  craftsInfoByUnitsGroups = null
  isEacInited = false
  fakeName = false
  queueProfileJwt = ""

  isWaiting = true
  isInvite = false
  isApplication = false
  isNewApplication = false
  isInvitedToSquadChat = false

  updatedProperties = ["name", "rank", "country", "clanTag", "pilotIcon", "platform", "selAirs",
                       "selSlots", "crewAirs", "brokenAirs", "missedPkg", "wwOperations",
                       "isReady", "isCrewsReady", "canPlayWorldWar", "isWorldWarAvailable", "cyberCafeId",
                       "unallowedEventsENames", "sessionRoomId", "crossplay", "bannedMissions", "dislikedMissions",
                       "craftsInfoByUnitsGroups", "isEacInited", "fakeName", "queueProfileJwt"]

  constructor(v_uid, v_isInvite = false, v_isApplication = false) {
    this.uid = v_uid.tostring()
    this.isInvite = v_isInvite
    this.isApplication = v_isApplication
    this.isNewApplication = v_isApplication

    this.initUniqueInstanceValues()

    let contact = ::getContact(this.uid)
    if (contact)
      this.update(contact)
  }

  function initUniqueInstanceValues() {
    this.selAirs = {}
    this.selSlots = {}
    this.crewAirs = {}
    this.brokenAirs = []
    this.missedPkg = []
    this.wwOperations = {}
    this.unallowedEventsENames = []
    this.bannedMissions = []
    this.dislikedMissions = []
    this.craftsInfoByUnitsGroups = []
  }

  function update(data) {
    local newValue = null
    local isChanged = false
    foreach (_idx, property in this.updatedProperties) {
      newValue = getTblValue(property, data, null)
      if (newValue == null)
        continue

      if (isInArray(property, ["brokenAirs", "missedPkg", "unallowedEventsENames",     //!!!FIX ME If this parametrs is empty then msquad returns table instead array
             "bannedMissions", "dislikedMissions", "craftsInfoByUnitsGroups"])        // Need remove this block after msquad fixed
          && !u.isArray(newValue))
        newValue = []

      if (newValue != this[property]) {
        this[property] = newValue
        isChanged = true
      }
    }
    this.isWaiting = false
    return isChanged
  }

  function isActualData() {
    return !this.isWaiting && !this.isInvite
  }

  function canJoinSessionRoom() {
    return this.isReady && this.sessionRoomId == ""
  }

  function getData() {
    let result = { uid = this.uid }
    foreach (_idx, property in this.updatedProperties)
      if (!u.isEmpty(this[property]))
        result[property] <- this[property]

    return result
  }

  function getWwOperationCountryById(wwOperationId) {
    foreach (operationData in this.wwOperations)
      if (operationData?.id == wwOperationId)
        return operationData?.country

    return null
  }

  function isEventAllowed(eventEconomicName) {
    return !isInArray(eventEconomicName, this.unallowedEventsENames)
  }

  function isMe() {
    return this.uid == userIdStr.value
  }
}

return SquadMember
