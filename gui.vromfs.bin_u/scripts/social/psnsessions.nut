//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { split_by_chars } = require("string")
let { get_game_mode } = require("mission")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { getFilledFeedTextByLang } = require("%scripts/langUtils/localization.nut")
let psn = require("%sonyLib/webApi.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

enum PSN_SESSION_TYPE {
  SKIRMISH = "skirmish"
  SQUAD = "squad"
}

//{ id = { type, info }}, joined sessions, only id is mandatory
let sessions = persist("sessions", @() Watched({}))

// in-flight cache for invitations accepted via PSN
let invitations = persist("invitations", @() Watched([]))

// { PSN_SESSION_TYPE = { type, info }} - waitng sessionId from PSN or joining
let pendingSessions = persist("pendingSessions", @() Watched({}))

let function formatSessionInfo(data, isCreateRequest = true) {
  let names = getFilledFeedTextByLang(data.locIdsArray)
  let info = {
    sessionPrivacy = data.isPrivate ? "private" : "public"
    sessionMaxUser = data.maxUsers
    sessionName = data.locIdsArray.map(@(id) loc(id, "")).reduce(@(res, str) res + str)
    localizedSessionNames = names.map(@(n) { npLanguage = n.abbreviation, sessionName = n.text })
    sessionLockFlag = false
  }
  if (isCreateRequest) {
    info.index <- data.index
    info.sessionType <- data.sessionType
    info.availablePlatforms <- ["PS4"]
  }
  return ::save_to_json(info)
}

let sessionParams = {
  [PSN_SESSION_TYPE.SKIRMISH] = {
    image = @() "ui/images/reward27"
    info = function() {
      let missionLoc = split_by_chars(::SessionLobby.getMissionData()?.locName || "", "; ")
      let defaultLoc = ["missions/" + ::SessionLobby.getMissionName(true)]
      return {
        index = 0
        locIdsArray = u.isEmpty(missionLoc) ? defaultLoc : missionLoc
        maxUsers = ::SessionLobby.getMaxMembersCount()
        isPrivate = ::SessionLobby.getPublicParam("friendOnly", false)
                 || !::SessionLobby.getPublicParam("allowJip", true)
        sessionType = "owner-migration"
      }
    }
    data = @() {
      roomId = ::SessionLobby.roomId,
      inviterUid = ::my_user_id_str,
      inviterName = ::my_user_name
      password = ::SessionLobby.password
      key = PSN_SESSION_TYPE.SKIRMISH
    }
  },

  [PSN_SESSION_TYPE.SQUAD] = {
    image = @() "ui/images/reward05"
    info = @() {
      index = 1
      locIdsArray = ["ps4/session/squad"]
      maxUsers = ::g_squad_manager.getMaxSquadSize()
      isPrivate = true
      sessionType = "owner-migration"
    }
    data = @() {
      squadId = ::my_user_id_str
      leaderId = ::my_user_id_str
      key = PSN_SESSION_TYPE.SQUAD
    }
  }
}


let function create(sType, cb = psn.noOpCb) {
  let params = sessionParams[sType] // Cache info for use in callback
  pendingSessions.update(@(v) v[sType] <- { type = sType, info = params.info })
  let saveSession = function(response, err) {
    if (!err && response?.sessionId)
      sessions.update(@(v) v[response.sessionId] <- pendingSessions.value[sType])
    pendingSessions.update(@(v) delete v[sType])

    cb(response, err)
  }
  psn.send(psn.session.create(formatSessionInfo(params.info()), params.image(), params.data()),
           Callback(saveSession, this))
}

let function invite(session, invitee, cb = psn.noOpCb) {
  if (session in sessions.value)
    psn.send(psn.session.invite(session, invitee), cb)
}

let function join(session, invitation = null, cb = psn.noOpCb) {
  // If we're in this session, just mark invitation used, favor rate limits
  if (session in sessions.value && invitation?.invitationId)
    psn.send(psn.invitation.use(invitation.invitattionId), cb)
  else {
    sessions.update(@(v) v[session] <- { type = invitation.key }) // consider ourselves in session early
    pendingSessions.update(@(v) v[invitation.key] <- { type = invitation.key })
    let afterJoin = function(response, err) {
      pendingSessions.update(@(v) delete v[invitation.key])
      if (err)
        sessions.update(@(v) delete v[session])
      else // Mark all invitations to this particular session as used
        psn.send(psn.invitation.list(), function(r, _e) {
              let all = r?.invitations ?? []
              let toMark = all.filter(@(i) !i.usedFlag && i.sessionId == session)
              toMark.apply(@(i) psn.send(psn.invitation.use(i.invitationId)))
            })

      cb(response, err)
    }
    psn.send(psn.session.join(session), Callback(afterJoin, this))
  }
}

let function update(session, info) {
  let psnSession = sessions.value?[session]
  let shouldUpdate = !u.isEqual((psnSession && psnSession?.info) || {}, info)
  log("[PSSI] update " + session + " (" + psnSession + "): " + shouldUpdate)

  if (shouldUpdate)
    psn.send(psn.session.update(session, formatSessionInfo(info, false)), function(_r, e) {
          if (!e)
            psnSession.info <- info
        })
}

let function leave(session, cb = psn.noOpCb) {
  if (session in sessions.value) {
    let afterLeave = function(response, err) {
      if (session in sessions.value)
        sessions.update(@(v) delete v[session])
      cb(response, err)
    }
    psn.send(psn.session.leave(session), Callback(afterLeave, this))
  }
  else
    cb({}, 0)
}


let function checkAfterFlight() {
  if (!isPlatformSony)
    return

  invitations.value.apply(@(i) i.processDelayed(i))
  invitations.update([])
}

subscriptions.addListenersWithoutEnv({
  RoomJoined = function(_p) {
    if (!isPlatformSony || get_game_mode() != GM_SKIRMISH)
      return

    let session = ::SessionLobby.getExternalId()
    log("[PSSI] onEventRoomJoined: " + session)
    if (u.isEmpty(session) && ::SessionLobby.isRoomOwner)
      create(PSN_SESSION_TYPE.SKIRMISH, @(r, _e) ::SessionLobby.setExternalId(r?.sessionId))
    else if (session && !(session in sessions.value))
      join(session, { key = PSN_SESSION_TYPE.SKIRMISH })
  }
  LobbyStatusChange = function(_p) {
    log("[PSSI] onEventLobbyStatusChange in room " + ::SessionLobby.isInRoom())
    // Leave psn session, join has its own event. Actually leave all skirmishes,
    // we can have only one in game but we no longer know it's psn Id in Lobby
    if (isPlatformSony && !::SessionLobby.isInRoom())
      foreach (id, _s in sessions.value.filter(@(s) s.type == PSN_SESSION_TYPE.SKIRMISH))
        leave(id)
  }
  LobbySettingsChange = function(_p) {
    let session = ::SessionLobby.getExternalId()
    if (!isPlatformSony || u.isEmpty(session))
      return

    log("[PSSI] onEventLobbySettingsChange for " + session)
    if (::SessionLobby.isRoomOwner)
      update(session, sessionParams[PSN_SESSION_TYPE.SKIRMISH].info())
    else if (!(session in sessions.value))
      join(session, { key = PSN_SESSION_TYPE.SKIRMISH })
  }
  SquadStatusChanged = function(_p) {
    if (!isPlatformSony)
      return

    let session = ::g_squad_manager.getPsnSessionId()
    let isLeader = ::g_squad_manager.isSquadLeader()
    let isInPsnSession = session in sessions.value
    log("[PSSI] onEventSquadStatusChanged " + ::g_squad_manager.state + " for " + session)
    log("[PSSI] onEventSquadStatusChanged leader: " + isLeader + ", psnSessions: " + sessions.value.len())
    log("[PSSI] onEventSquadStatusChanged session bound to PSN: " + isInPsnSession)

    let bindSquadSession = function(r, e) {
      if (!e && r?.sessionId)
        ::g_squad_manager.setPsnSessionId(r.sessionId)
      ::g_squad_manager.processDelayedInvitations()
    }

    switch (::g_squad_manager.state) {
      case squadState.IN_SQUAD:
        if (PSN_SESSION_TYPE.SQUAD in pendingSessions.value)
          break
        if (!isLeader && !isInPsnSession) // Invite accepted or normal relogin
          join(session, { key = PSN_SESSION_TYPE.SQUAD })
        if (!isLeader && sessions.value[session]?.info) // Leadership transfer
          sessions.update(@(v) delete v[session].info)
        else if (isLeader && u.isEmpty(session)) // Squad implicitly created
          create(PSN_SESSION_TYPE.SQUAD, bindSquadSession)
        else if (isLeader && u.isEmpty(sessions.value)) // Autotransfer on login
          create(PSN_SESSION_TYPE.SQUAD, bindSquadSession)
        else if (isLeader && sessions.value?[session] && !sessions.value[session]?.info) { // Leadership transfer
          update(session, sessionParams[PSN_SESSION_TYPE.SQUAD].info())
          psn.send(psn.session.change(session, sessionParams[PSN_SESSION_TYPE.SQUAD].data()))
        }
        break

      case squadState.LEAVING:
        if (isInPsnSession)
          leave(session)
        break
    }
  }
})

let function onPsnInvitation(invitation) {
  log("[PSSI] PSN invite " + invitation.invitationId + " to " + invitation.sessionId)
  let delayInvitation = function(i, cb) {
    i.processDelayed <- cb
    invitations.update(@(v) v.append(i))
  }
  let isInPsnSession = invitation.sessionId in sessions.value

  if (u.isEmpty(invitation.sessionId) || isInPsnSession)
    return // Most-likely we are joining from PS4 Blue Screen

  if (!::g_login.isLoggedIn() || ::is_in_loading_screen()) {
    log("[PSSI] delaying PSN invite until logged in and loaded")
    delayInvitation(invitation, onPsnInvitation)
    return
  }

  if (isInPsnSession) {
    log("[PSSI] stale PSN invite: already joined")
    psn.send(psn.invitation.use(invitation.invitationId)) // Stale PSN-invitation
    return
  }

  if (!::isInMenu()) {
    log("[PSSI] delaying PSN invite until in menu")
    delayInvitation(invitation, onPsnInvitation)
    get_cur_gui_scene().performDelayed(this, function() {
      showInfoMsgBox(loc("msgbox/add_to_squad_after_fight"), "add_to_squad_after_fight")
    })
    return
  }

  let acceptInvitation = function(response, err) {
    log("[PSSI] ready to accept PSN invite, error " + err)
    if (!err) {
      let fullInfo = u.extend(response, invitation)
      switch (response.key) {
        case PSN_SESSION_TYPE.SKIRMISH:
          ::g_invites.addSessionRoomInvite(fullInfo.roomId, fullInfo.inviterUid, fullInfo.inviterName, fullInfo.password).accept()
          break
        case PSN_SESSION_TYPE.SQUAD:
          ::g_invites.addInviteToSquad(fullInfo.squadId, fullInfo.leaderId).accept()
          break
      }
    }
  }
  psn.send(psn.session.data(invitation.sessionId), acceptInvitation)
}

return {
  onPsnInvitation
  invite
  checkInvitesAfterFlight = checkAfterFlight
}