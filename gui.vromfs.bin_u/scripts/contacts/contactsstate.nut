from "%scripts/dagui_library.nut" import *
let contactsClient = require("contactsClient.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { APP_ID } = require("app")
let { format } = require("string")
let { updateContactsGroups, predefinedContactsGroupToWtGroup,
  updateContactsListFromContactsServer } = require("%scripts/contacts/contactsManager.nut")
let { matchingApiFunc, matchingApiNotify, matchingRpcSubscribe
} = require("%scripts/matching/api.nut")
let { register_command } = require("console")
let { get_time_msec } = require("dagor.time")
let { chooseRandom } = require("%sqstd/rand.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { setInterval, clearTimer } = require("dagor.workcycle")
let { addFriendInvite } = require("%scripts/invites/invites.nut")
let { userIdStr } = require("%scripts/user/myUser.nut")
let { contactEvent, statusGroupsToRequest, GAME_GROUP_NAME } = require("%scripts/contacts/contactsConsts.nut")

let logC = log_with_prefix("[CONTACTS STATE] ")

let appIdsList = [APP_ID]
let searchContactsResults = Watched({})

let isMeAllowedToBeAddedToContacts = mkWatched(persist, "isMeAllowedToBeAddedToContacts", false)

let function setAbilityToBeAddedToContacts(isAvailable) {
  if (isAvailable == isMeAllowedToBeAddedToContacts.get())
    return

  contactsClient.contacts_request(
    "cln_set_allowed_to_be_added_to_contacts",
    { ata = isAvailable },
    function(res) {
      if (!res?.result.success)
        return
      isMeAllowedToBeAddedToContacts.set(isAvailable)
    }
   )
}

let wtGroupToRequestAddAction = {
  [EPL_FRIENDLIST] = "contacts_request_for_contact",
  [EPL_BLOCKLIST] = "contacts_add_to_blacklist"
}

let contactsGroupToRequestRemoveAction = {
  approved = "contacts_break_approval_request"
  myRequests = "contacts_cancel_request"
  myBlacklist = "contacts_remove_from_blacklist"
}

let function updatePresencesByList(presences) {
  let contactsDataList = []
  foreach (p in presences) {
    let player = {
      uid = p?.userId
    }
    if ((p?.nick ?? "") != "")
      player.name <- p.nick
    if (type(player.uid) != "string") {
      let presence = toString(p) // warning disable: -declared-never-used
      let playerData = toString(player) // warning disable: -declared-never-used
      script_net_assert_once("on_presences_update_error", "on_presences_update cant update presence for player")
      continue
    }

    if ("online" in p?.presences) {
      player.online <- p.presences.online
      player.unknown <- null
    }
    if ("unknown" in p?.presences)
      player.unknown <- p.presences.unknown

    if ("status" in p?.presences) {
      player.gameStatus <- null
      foreach (s in ["in_game", "in_queue"])
        if (s in p.presences.status) {
          let gameInfo = p.presences.status[s]

          // This is a workaround for a bug when something
          // is setting player presence with no event info.
          if (!("eventId" in gameInfo))
            continue

          player.gameStatus = s
          player.gameConfig <- {
            diff = gameInfo.diff
            country = gameInfo.country
            eventId = gameInfo?.eventId
          }
          break
        }
    }

    if ("in_game_ex" in p?.presences)
      player.inGameEx <- p.presences.in_game_ex

    player.needReset <- !(p?.update ?? true)
    contactsDataList.append(player)
  }
  ::update_contacts_by_list(contactsDataList, false)
}

let function onUpdateContactsCb(result) {
  if ("presences" not in result && "groups" not in result)
    return

  if ("presences" in result)
    updatePresencesByList(result.presences)
  if ("groups" in result)
    updateContactsGroups(result.groups)

  broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, { groupName = null })
  ::update_gamercards()
}

let function fetchContacts() {
  matchingApiFunc("mpresence.reload_contact_list", function(result) {
    onUpdateContactsCb(result)
  })
}

let function execContactsCharAction(userId, charAction, successCb = null) {
  if (userId == ::INVALID_USER_ID) {
    logC($"trying to do {charAction} with invalid contact")
    return
  }
  contactsClient[charAction](userId.tointeger(), GAME_GROUP_NAME, {
    function success() {
      fetchContacts()
      successCb?()
    }
    failure = @(err) showInfoMsgBox(loc(err), "exec_contacts_action_error")
  })
}

let defaultSearchRequestParams = {
  maxCount = 20
  ignoreCase = true
  specificAppId = ";".join(appIdsList)
}

let function searchContactsOnline(request, callback = null) {
  request = defaultSearchRequestParams.__merge(request)
  logC(request)
  contactsClient.contacts_request(
    "cln_find_users_by_nick_prefix_json",
    request,
    function (result) {
      if (!(result?.result?.success ?? true)) {
        searchContactsResults({})
        if (callback)
          callback()
        return
      }

      let resContacts = {}
      foreach (uidStr, name in result)
        if ((typeof name == "string")
            && uidStr != userIdStr.value
            && uidStr != "") {
          let a = to_integer_safe(uidStr, null, false)
          if (a == null) {
            print($"uid is not an integer, uid: {uidStr}")
            continue
          }
          ::getContact(uidStr, name) //register contact name
          resContacts[uidStr] <- name
        }

      searchContactsResults(resContacts)
      if (callback)
        callback()
    }
  )
}

//!!!FIX ME: A dirty hack to use the same matching notification for accepted and rejected friend request
let sendFriendChangedEvent = @(friendId)
  matchingApiNotify("mpresence.notify_friend_added", { friendId })

let function verifiedContactAndDoIfNeed(player, groupName, cb) {
  if (!player)
    return

  if (!("uid" in player) || !player.uid || player.uid == "") {
    if (!("name" in player))
      return

    let self = callee()
    ::find_contact_by_name_and_do(player.name, @(contact) self(contact, groupName, cb))
    return
  }

  let contact = ::getContact(player.uid, player.name)
  if (contact.canOpenXBoxFriendsWindow(groupName)) {
    contact.openXBoxFriendsEdit()
    return
  }

  cb(contact, groupName)
}

let function addContactImpl(contact, groupName) {
  if (::isPlayerInContacts(contact.uid, groupName))
    return //no need to do something

  let action = wtGroupToRequestAddAction?[groupName]
  if (action == null)
    return

  let function successCb() {
    sendFriendChangedEvent(contact.uidInt64)
    ::g_popups.add(null, format(loc($"msg/added_to_{groupName}"), contact.getName()))
  }
  execContactsCharAction(contact.uid, action, successCb)
}

let function addContact(player, groupName) { //playerConfig: { uid, name }
  if (!::can_add_player_to_contacts_list(groupName))
    return //Too many contacts

  verifiedContactAndDoIfNeed(player, groupName, addContactImpl)
}

let function removeContactImpl(contact, groupName) {
  if (!::isPlayerInContacts(contact.uid, groupName))
    return //no need to do something

  let contactGroup = contact.contactServiceGroup
  if (predefinedContactsGroupToWtGroup?[contactGroup] != groupName)
    return

  let action = contactsGroupToRequestRemoveAction?[contactGroup]
  if (action == null)
    return
  scene_msg_box(
    "remove_from_list",
    null,
    format(loc($"msg/ask_remove_from_{groupName}"), contact.getName()),
    [
      ["ok", @() execContactsCharAction(contact.uid, action, @() sendFriendChangedEvent(contact.uidInt64))],
      ["cancel", @() null ]
    ],
    "cancel", { cancel_fn = @() null }
  )
}

let function addInvitesToFriend(inviters) {
  if (inviters == null)
    return

  ::g_invites.addFriendsInvites(inviters)
  fetchContacts()
}

let function requestContactsListAndDo(cb) {
  let function callback(res) {
     updateContactsListFromContactsServer(res)
     cb(res)
  }
  contactsClient.contacts_request_rpcjson("GetContacts",
    { groups = [GAME_GROUP_NAME], satus = statusGroupsToRequest}, callback)
}

let removeContact = @(player, groupName)
  verifiedContactAndDoIfNeed(player, groupName, removeContactImpl)

let rejectContact = @(player) execContactsCharAction(player.uid, "contacts_reject_request",
  @() sendFriendChangedEvent(player.uid.tointeger()))

addListenersWithoutEnv({
  PostboxNewMsg = function(mail_obj) {
    if (mail_obj.mail?.subj == "notify_contacts_update")
      fetchContacts()
  }
  LoginComplete = function(_) {
    contactsClient.contacts_request(
      "cln_get_allowed_to_be_added_to_contacts",
      null,
      function(res) {
        if ("ata" in res)
          isMeAllowedToBeAddedToContacts.set(res.ata)
      }
    )

    requestContactsListAndDo(
      @(res) addInvitesToFriend(res?[GAME_GROUP_NAME].requestsToMe))
  }
})

matchingRpcSubscribe("mpresence.notify_presence_update", onUpdateContactsCb)
matchingRpcSubscribe("mpresence.on_added_to_contact_list", function(p) {
  let { name = "", userId = "" } = p?.user
  if (userId != "" && name != "") {
    let uidInt = to_integer_safe(userId, -1)
    requestContactsListAndDo(function(res) {
      let inviters = res?[GAME_GROUP_NAME].requestsToMe ?? []
      if (inviters.findvalue(@(v) v?.uid == uidInt) != null)
        addFriendInvite(name, userId)
    })
  }
  fetchContacts()
})

//----------- Debug Block -----------------
let fakeFriendsList = Watched([])
fakeFriendsList.subscribe(function(f) {
  updatePresencesByList(f)
  updateContactsGroups({ [$"#{GAME_GROUP_NAME}#approved"] = f })
  broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, { groupName = EPL_FRIENDLIST })
})
register_command(function(count) {
    let startTime = get_time_msec()
    fakeFriendsList(array(count).map(@(_, i) {
      nick = $"stranger{i}",
      userId = (2000000000 + i).tostring(),
      presences = { online = (i % 2) == 0 }
    }))
    logC($"Friends update time: {get_time_msec() - startTime}")
  },
  "contacts.generate_fake_friends")

local updateFakePresenceCount = 0
local updateFakePresenceTimeSec = 0
let function updateFakePresence() {
  let startTime = get_time_msec()
  for(local i = 0; i < updateFakePresenceCount; i++) {
    let f = chooseRandom(fakeFriendsList.value)
    f.presences.online = !f.presences.online
    updatePresencesByList([f])
  }
  broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, { groupName = EPL_FRIENDLIST })
  logC($"{updateFakePresenceCount} friends presence update by separate events time: {get_time_msec() - startTime}")
}
let function changeFakePresence(count, updateCycleTimeSec) {
  clearTimer(updateFakePresence)
  updateFakePresenceCount = count
  updateFakePresenceTimeSec = updateCycleTimeSec
  if (fakeFriendsList.value.len() == 0) {
    logC("No fake contacts yet. Generate them first")
    return
  }
  if (count == 0) {
    logC("New fake count is 0. Update is disable ")
    return
  }
  updateFakePresence()
  if (updateCycleTimeSec == 0)
    return
  setInterval(updateFakePresenceTimeSec, updateFakePresence)
}
register_command(changeFakePresence, "contacts.change_fake_presence")

register_command(function(count) {
    let startTime = get_time_msec()
    addInvitesToFriend(array(count).map(@(_, i) {
      nick = $"stranger{i}",
      uid = (2000000000 + i).tostring(),
    }))
    logC($"Invites add time: {get_time_msec() - startTime}")
  },
  "contacts.generate_fake_friends_invites")

register_command(function(count) {
    let startTime = get_time_msec()
    updateContactsListFromContactsServer({ [GAME_GROUP_NAME] = { meInBlacklist =
      array(count).map(@(_, i) {
        nick = $"stranger{i}",
        uid = 2000000000 + i,
      })}})
    logC($"Blocked list update time: {get_time_msec() - startTime}")
  },
  "contacts.update_fake_blocked_me_list")


return {
  searchContactsResults
  searchContacts = @(nick, callback = null) searchContactsOnline({ nick }, callback)
  searchOneContact = @(nick, callback = null)
    searchContactsOnline({ nick, maxCount = 1, ignoreCase = false }, callback)

  fetchContacts
  addContact
  removeContact
  rejectContact
  updatePresencesByList
  execContactsCharAction

  isMeAllowedToBeAddedToContacts
  setAbilityToBeAddedToContacts
}