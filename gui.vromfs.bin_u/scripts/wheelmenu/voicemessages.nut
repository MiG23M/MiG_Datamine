//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let localDevoice = require("%scripts/penitentiary/localDevoice.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { get_game_mode, get_game_type } = require("mission")

const HIDDEN_CATEGORY_NAME = "hidden"
const LIMIT_SHOW_VOICE_MESSAGE_PETALS = 8
let voiceMessageNames = [
  { category = "attack", name = "voice_message_attack_A", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_attack", iconBlinkTime = 6, iconTarget = "zone_A" },
  { category = "attack", name = "voice_message_attack_B", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_attack", iconBlinkTime = 6, iconTarget = "zone_B" },
  { category = "attack", name = "voice_message_attack_C", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_attack", iconBlinkTime = 6, iconTarget = "zone_C" },
  { category = "attack", name = "voice_message_attack_D", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_attack", iconBlinkTime = 6, iconTarget = "zone_D" },
  { category = "attack", name = "voice_message_attack_enemy_base", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_attack", iconBlinkTime = 6, iconTarget = "enemy_base" },
  { category = "attack", name = "voice_message_attack_enemy_troops", blinkTime = 0, haveTarget = false, showPlace = false },
  { category = "attack", name = "voice_message_attack_target", blinkTime = 10, haveTarget = true, showPlace = true, icon = "icon_attack", iconBlinkTime = 6, iconTarget = "target" },

  { category = "defend", name = "voice_message_defend_A", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_shield", iconBlinkTime = 6, iconTarget = "zone_A" },
  { category = "defend", name = "voice_message_defend_B", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_shield", iconBlinkTime = 6, iconTarget = "zone_B" },
  { category = "defend", name = "voice_message_defend_C", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_shield", iconBlinkTime = 6, iconTarget = "zone_C" },
  { category = "defend", name = "voice_message_defend_D", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_shield", iconBlinkTime = 6, iconTarget = "zone_D" },
  { category = "defend", name = "voice_message_cover_base", blinkTime = 0, haveTarget = false, showPlace = false, icon = "icon_shield", iconBlinkTime = 6, iconTarget = "base" },

  { category = "answer", name = "voice_message_yes", blinkTime = 0, haveTarget = false, showPlace = false },
  { category = "answer", name = "voice_message_no", blinkTime = 0, haveTarget = false, showPlace = false },
  { category = "answer", name = "voice_message_sorry", blinkTime = 2, haveTarget = false, showPlace = false },
  { category = "answer", name = "voice_message_thank_you", blinkTime = 2, haveTarget = false, showPlace = false },

  { category = "report", name = "voice_message_follow_me", blinkTime = 6, haveTarget = false, showPlace = true, icon = "icon_attention", iconBlinkTime = 6, iconTarget = "sender" },
  { category = "report", name = "voice_message_cover_me", blinkTime = 6, haveTarget = false, showPlace = true, icon = "icon_shield", iconBlinkTime = 6, iconTarget = "sender" },
  { category = "report", name = "voice_message_landing", blinkTime = 6, haveTarget = false, showPlace = true /*, forAircraft = true*/ },
  { category = "report", name = "voice_message_return_to_base", blinkTime = 0, haveTarget = false, showPlace = false /*, forAircraft = true*/ },
  { category = "report", name = "voice_message_reloading", blinkTime = 0, haveTarget = false, showPlace = false, useReloadTime = true },
  { category = "report", name = "voice_message_well_done", blinkTime = 0, haveTarget = false, showPlace = false },
  { category = "report", name = "voice_message_attacking_target", blinkTime = 10, haveTarget = true, showPlace = true, icon = "icon_attacking", iconBlinkTime = 6, iconTarget = "target" },
  { category = "report", name = "voice_message_repairing", blinkTime = 0, haveTarget = false, showPlace = false, forTank = true, useRepairTime = true },

  { category = "request", name = "voice_message_request_target", blinkTime = 6, haveTarget = false, showPlace = true, forAircraft = true },
  { category = "request", name = "voice_message_request_air_support", blinkTime = 6, haveTarget = false, forTank = true, showPlace = true, useTargetIfExist=true, icon = "icon_attacking", iconBlinkTime = 6},
  { category = "request", name = "voice_message_request_uav", blinkTime = 6, haveTarget = false, showPlace = true },
  { category = "request", name = "voice_message_help_me", blinkTime = 10, haveTarget = false, showPlace = true, forTank = true },

  { category = "targeting", name = "voice_message_air", blinkTime = 6, haveTarget = false, showPlace = false, showDirection = true , coneAngle = 30, targetTeam = "enemy"},

  { category = HIDDEN_CATEGORY_NAME, name = "voice_message_attention_to_point", blinkTime = 5, haveTarget = false, showPlace = true,
                                    icon = "icon_attention_to_point", iconBlinkTime = 8, iconTarget = "sender", attentionToPoint = true },
  { category = HIDDEN_CATEGORY_NAME, name = "voice_message_designate_target_from_uav", blinkTime = 5, haveTarget = false, showPlace = true, isUavDesignation = true },

  { category = HIDDEN_CATEGORY_NAME, name = "voice_message_teamkill_sorry", blinkTime = 2, haveTarget = false, showPlace = false },
  { category = HIDDEN_CATEGORY_NAME, name = "voice_message_teamkill_forgive", blinkTime = 2, haveTarget = true, showPlace = false },
]

let function initVoiceMessageList() {
  for (local i = 0; i < voiceMessageNames.len(); i++) {
    let line = voiceMessageNames[i];
    ::add_voice_message(line);
  }
}
initVoiceMessageList()

let getCategoryLoc = @(category) loc($"voice_message_category/{category}")

let function getFavoriteVoiceMessagesVariants() {
  let result = ["#options/none"];
  local categoryName = "";
  local categoryIndex = 0;
  local indexInCategory = 0;
  foreach (_idx, record in voiceMessageNames) {
    if (record.category == HIDDEN_CATEGORY_NAME)
      continue;
    if (categoryName != record.category) {
      categoryName = record.category;
      categoryIndex++;
      indexInCategory = 0;
    }
    indexInCategory++;

    result.append("" + categoryIndex + "-" + indexInCategory + ": " + format(loc(record.name + "_0"),
      loc("voice_message_target_placeholder")));
  }
  return result;
}

let function getVoiceMessageListLine(index, is_category, name, squad, targetName, _messageIndex = -1) {
  local scText = ""
  if (!isPlatformSony) {
    let shortcutNames = [];
    let key = "ID_VOICE_MESSAGE_" + (index + 1); //1based
    shortcutNames.append(key);

    let shortcuts = ::get_shortcuts(shortcutNames)

    for (local sc = 0; sc < shortcuts.len(); sc++)
      if (shortcuts[sc].len())
        scText += ((scText != "") ? "; " : "") + ::get_shortcut_text({ shortcuts = shortcuts, shortcutId = 0 })
  }

  return {
    shortcutText = scText
    name = is_category ? getCategoryLoc(name) : format(loc(name + "_0"), targetName)
    chatMode = squad ? "squad" : "team"
  }
}

let function getCantUseVoiceMessagesReason(isForSquad) {
  if (!::is_multiplayer())
    return loc("ui/unavailable")
  if (!::is_mode_with_teams(get_game_type()))
    return loc("chat/no_team")
  if (isForSquad && get_game_mode() == GM_SKIRMISH)
    return loc("squad/no_squads_in_custom_battles")
  if (isForSquad && !::g_squad_manager.isInSquad())
    return loc("squad/not_a_member")
  return ""
}

let onVoiceMessageAnswer = @(index) ::on_voice_message_button(index) //-1 means "close"

let function showVoiceMessageList(show, category, squad, targetName) {
  if (!show) {
    ::close_cur_voicemenu()
    return false
  }

  let reason = getCantUseVoiceMessagesReason(squad)
  if (reason != "") {
    ::chat_system_message(reason)
    return false
  }

  let categories = []
  let menu = []
  let heroIsTank = getAircraftByName(::get_player_unit_name())?.isTank() ?? false
  local shortcutTable = {}

  foreach (idx, record in voiceMessageNames) {
    if (category == "") { //list of categories
      if (isInArray(record.category, categories)
          || record.category == HIDDEN_CATEGORY_NAME)
        continue;

      shortcutTable = getVoiceMessageListLine(menu.len(), true, record.category, squad, targetName, -1);
      shortcutTable.type <- "group"

      categories.append(record.category);
    }
    else {
      if (record.category != category)
        continue;

      if ((getTblValue("forAircraft", record, false) && heroIsTank)
         || (getTblValue("forTank", record, false) && !heroIsTank)
         || (getTblValue("haveTarget", record, false) && targetName == "")) {
        shortcutTable = {}
      }
      else {
        shortcutTable = getVoiceMessageListLine(menu.len(), false, record.name, squad, targetName, idx)
        shortcutTable.type <- "shortcut"
      }
    }
    menu.append(shortcutTable)
  }

  //favorites:
  if (category == "") { //main level
    for (local i = 0; i < NUM_FAVORITE_VOICE_MESSAGES; i++) {
      if (menu.len() == (LIMIT_SHOW_VOICE_MESSAGE_PETALS))
        break

      let messageIndex = ::get_option_favorite_voice_message(i)
      let record = getTblValue(messageIndex, voiceMessageNames)
      if (!record)
        continue

      if (
          (getTblValue("haveTarget", record, false) && targetName == "")
          || (getTblValue("forAircraft", record, false) && heroIsTank)
          || (getTblValue("forTank", record, false) && !heroIsTank)
         ) {
        menu.append({})
        continue
      }
      shortcutTable = getVoiceMessageListLine(menu.len(), false, record.name, squad, targetName, messageIndex);
      shortcutTable.type <- "favorite"
      menu.append(shortcutTable)
    }
  }

  if (!menu.len())
    return false

  return ::gui_start_voicemenu({ menu = menu,
                                callbackFunc = onVoiceMessageAnswer,
                                squadMsg = squad,
                                category = category }) != null
}
::show_voice_message_list <- showVoiceMessageList //used from native code

let removeFavoriteVoiceMessage = @(index) ::set_option_favorite_voice_message(index, -1)

let function resetFastVoiceMessages() {
  for (local i = 0; i < NUM_FAST_VOICE_MESSAGES; i++)
    removeFavoriteVoiceMessage(i)
}

::is_voice_messages_muted <- function is_voice_messages_muted(name) { //used from native code
  return localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO)
    || ::isPlayerNickInContacts(name, EPL_BLOCKLIST)
}

//////////////////////////////////////////////////////
let getVoiceMessageNames = @() voiceMessageNames

return {
  getVoiceMessageNames = getVoiceMessageNames
  getCategoryLoc = getCategoryLoc
  getFavoriteVoiceMessagesVariants = getFavoriteVoiceMessagesVariants
  getCantUseVoiceMessagesReason = getCantUseVoiceMessagesReason
  resetFastVoiceMessages = resetFastVoiceMessages
}