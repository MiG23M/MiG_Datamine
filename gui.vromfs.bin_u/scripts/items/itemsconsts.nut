enum MARK_RECIPE {
  NONE
  BY_USER
  USED
}


enum itemsTab {
  INVENTORY
  SHOP
  WORKSHOP

  TOTAL
}

enum itemType { //bit values for easy multitype search
  UNKNOWN      = 0

  TROPHY          = 0x0000000001  //chest
  BOOSTER         = 0x0000000002
  TICKET          = 0x0000000004  //tournament ticket
  WAGER           = 0x0000000008
  DISCOUNT        = 0x0000000010
  ORDER           = 0x0000000020
  FAKE_BOOSTER    = 0x0000000040
  UNIVERSAL_SPARE = 0x0000000080
  MOD_OVERDRIVE   = 0x0000000100
  MOD_UPGRADE     = 0x0000000200
  SMOKE           = 0x0000000400

  //external inventory
  VEHICLE         = 0x0000010000
  SKIN            = 0x0000020000
  DECAL           = 0x0000040000
  ATTACHABLE      = 0x0000080000
  KEY             = 0x0000100000
  CHEST           = 0x0000200000
  WARBONDS        = 0x0000400000
  INTERNAL_ITEM   = 0x0000800000 //external inventory coupon which gives internal item
  ENTITLEMENT     = 0x0001000000
  WARPOINTS       = 0x0002000000
  UNLOCK          = 0x0004000000
  BATTLE_PASS     = 0x0008000000
  RENTED_UNIT     = 0x0010000000
  UNIT_COUPON_MOD = 0x0020000000
  PROFILE_ICON    = 0x0040000000

  //workshop
  CRAFT_PART      = 0x1000000000
  RECIPES_BUNDLE  = 0x2000000000
  CRAFT_PROCESS   = 0x4000000000

  //masks
  ALL             = 0xFFFFFFFFFF
  INVENTORY_ALL   = 0xAFFFBFFFFF //~CRAFT_PART ~CRAFT_PROCESS ~WARBONDS
}


return {
  MARK_RECIPE
  itemsTab
  itemType
}
