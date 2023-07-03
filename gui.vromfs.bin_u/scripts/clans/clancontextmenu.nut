//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let { isChatEnableWithPlayer, hasMenuChat } = require("%scripts/chat/chatStates.nut")

let getClanActions = function(clanId) {
  if (!hasFeature("Clans"))
    return []

  let myClanId = ::clan_get_my_clan_id()

  return [
    {
      text = loc("clan/btn_membership_req")
      show = myClanId == "-1" && ::clan_get_requested_clan_id() != clanId
      action = @() ::g_clans.requestMembership(clanId)
    }
    {
      text = loc("clan/clanInfo")
      show = clanId != "-1"
      action = @() ::showClanPage(clanId, "", "")
    }
    {
      text = loc("mainmenu/btnComplain")
      show = myClanId != clanId
      action = @() ::g_clans.requestOpenComplainWnd(clanId)
    }
  ]
}

let getRequestActions = function(clanId, playerUid, playerName = "", handler = null) {
  if (!playerUid)
    return []

  let myClanRights = ::g_clans.getMyClanRights()
  let isClanAdmin = ::clan_get_admin_editor_mode()

  let isBlock = ::isPlayerInContacts(playerUid, EPL_BLOCKLIST)
  let contact = ::getContact(playerUid, playerName)
  let name = contact?.name ?? playerName
  let canChat = contact?.canChat() ?? isChatEnableWithPlayer(name)
  let isProfileMuted = contact?.isMuted() ?? false

  return [
    {
      text = loc("contacts/message")
      isVisualDisabled = !canChat || isBlock || isProfileMuted
      show = playerUid != ::my_user_id_str
             && ::ps4_is_chat_enabled()
             && !u.isEmpty(name)
             && hasMenuChat.value
      action = function() {
        if (isBlock)
          return playerContextMenu.showBlockedPlayerPopup(name)

        if (isProfileMuted) //There was no xbox message, so don't try to call overlay msg
          return playerContextMenu.showXboxPlayerMuted(name)

        if (!canChat)
          return playerContextMenu.notifyPlayerAboutRestriction(contact)

        ::openChatPrivate(name, handler)
      }
    }
    {
      text = loc("mainmenu/btnUserCard")
      action = @() ::gui_modal_userCard({ uid = playerUid })
    }
    {
      text = loc("clan/requestApprove")
      show = isInArray("MEMBER_ADDING", myClanRights) || isClanAdmin
      action = @() ::g_clans.approvePlayerRequest(playerUid, clanId)
    }
    {
      text = loc("clan/requestReject")
      show = isInArray("MEMBER_REJECT", myClanRights) || isClanAdmin
      action = @() ::g_clans.rejectPlayerRequest(playerUid, clanId)
    }
    {
      text = loc("clan/blacklistAdd")
      show = isInArray("MEMBER_BLACKLIST", myClanRights) || isClanAdmin
      action = @() ::g_clans.blacklistAction(playerUid, true, clanId)
    }
  ]
}

return {
  getClanActions = getClanActions
  getRequestActions = getRequestActions
}