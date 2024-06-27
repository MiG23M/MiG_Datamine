from "%scripts/dagui_natives.nut" import ps4_show_chat_restriction, gchat_is_voice_enabled, gchat_is_enabled, ps4_is_chat_enabled
from "%scripts/dagui_library.nut" import *

let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { hasChat } = require("%scripts/user/matchingFeature.nut")
let { isGuestLogin } = require("%scripts/user/profileStates.nut")
let { check_communications_privilege, check_crossnetwork_communications_permission, CommunicationState } = require("%scripts/xbox/permissions.nut")
let { getContactByName } = require("%scripts/contacts/contactsManager.nut")

function getXboxChatEnableStatus() {
  if (!is_platform_xbox || !::g_login.isLoggedIn())
    return CommunicationState.Allowed
  return check_crossnetwork_communications_permission()
}

function isChatEnabled(needOverlayMessage = false) {
  if (!gchat_is_enabled())
    return false

  if (!ps4_is_chat_enabled()) {
    if (needOverlayMessage)
      ps4_show_chat_restriction()
    return false
  }
  return getXboxChatEnableStatus() != CommunicationState.Blocked
}

// Two funcitons below were made to workaround global variables usage check
// These checks are introduced for good reasons, but this commit is not
// intended to reduce global variables usage
local function is_player_in_friends_group(uid, searchByUid, playerNick) {
  return ::isPlayerInFriendsGroup(uid, searchByUid, playerNick)
}

function isCrossNetworkMessageAllowed(playerName) {
  if (platformModule.isPlayerFromXboxOne(playerName)
      || platformModule.isPlayerFromPS4(playerName))
    return true

  let crossnetStatus = crossplayModule.getCrossNetworkChatStatus()
  if (crossnetStatus == CommunicationState.FriendsOnly
    && (is_player_in_friends_group(null, false, playerName)))
    return true

  return crossnetStatus == CommunicationState.Allowed
}

function checkChatEnableWithPlayer(playerName, callback) { //when you have contact, you can use direct contact.canInteract
  let contact = getContactByName(playerName)
  if (contact) {
    contact.checkCanChat(callback)
    return
  }

  if (getXboxChatEnableStatus() == CommunicationState.FriendsOnly) {
    callback?(is_player_in_friends_group(null, false, playerName))
    return
  }

  if (!isCrossNetworkMessageAllowed(playerName)) {
    callback?(false)
    return
  }

  callback?(isChatEnabled())
}

function isChatEnableWithPlayer(playerName, comms_state) {
  let contact = getContactByName(playerName)
  if (contact) {
    return contact.canChat(comms_state)
  }

  if (getXboxChatEnableStatus() == CommunicationState.FriendsOnly) {
    return is_player_in_friends_group(null, false, playerName)
  }

  if (!isCrossNetworkMessageAllowed(playerName)) {
    return false
  }

  return isChatEnabled()
}

function attemptShowOverlayMessage() { //tries to display Xbox overlay message
  check_communications_privilege(true, null)
}

function canUseVoice() {
  return hasFeature("Voice") && gchat_is_voice_enabled()
}

let hasMenuChat = Computed(@() hasChat.value && !isGuestLogin.value)

return {
  getXboxChatEnableStatus = getXboxChatEnableStatus
  isChatEnabled = isChatEnabled
  checkChatEnableWithPlayer = checkChatEnableWithPlayer
  isChatEnableWithPlayer = isChatEnableWithPlayer
  attemptShowOverlayMessage = attemptShowOverlayMessage
  isCrossNetworkMessageAllowed = isCrossNetworkMessageAllowed
  chatStatesCanUseVoice = canUseVoice
  hasMenuChat
}
