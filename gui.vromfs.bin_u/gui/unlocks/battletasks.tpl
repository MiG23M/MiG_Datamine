frame {
  size:t='1.1@scrn_tgt, 1@maxWindowHeight'
  class:t='wndNav'
  isCenteredUnderLogo:t='yes'

  frame_header {
    HorizontalListBox {
      id:t='tasks_sheet_list'
      class:t='header'
      height:t='ph'
      activeAccesskeys:t='RS'
      on_select:t = 'onChangeTab'
      <<@tabs>>
    }

    Button_close {}
  }

  CheckBox {
    id:t='show_all_tasks'
    pos:t='0, 0';
    position:t='relative'
    text:t='#mainmenu/battleTasks/showAllTasks'
    on_change_value:t='onShowAllTasks'
    btnName:t='LB'
    value:t='<<showAllTasksValue>>'
    display:t = 'hide'
    enable:t='no'

    CheckBoxImg{}
    ButtonImg{}
  }

  tdiv {
    id:t='tasks_list_frame'
    size:t='pw, fh'
    position:t='relative'
    flow:t='vertical'

    listbox {
      id:t='tasks_list'
      size:t='pw, fh'
      overflow-y:t='auto';
      flow:t='vertical'
      scrollBox-dontResendShortcut:t="yes"

      on_select:t='onSelectTask'

      navigatorShortcuts:t='yes'
      selImgType:t='gamepadFocused'
    }

    textAreaCentered {
      id:t='battle_tasks_no_tasks_text'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      max-width:t='pw'
      hideEmptyText:t='yes'
      text:t=''
    }

    RadioButtonList {
      id:t='battle_tasks_modes_radiobuttons'
      left:t='50%pw-50%w'
      position:t='relative'
      margin-bottom:t='0.01@scrn_tgt'

      navigatorShortcuts:t='yes'
      on_select:t = 'onChangeShowMode'

      <<#radiobuttons>>
        RadioButton {
          text:t='<<radiobuttonName>>';
          <<#selected>>
            selected:t='yes'
          <</selected>>
          RadioButtonImg{}
        }
      <</radiobuttons>>
    }
  }

  tdiv {
    id:t='warbond_shop_progress_block'
    width:t='pw'
    position:t='relative'
    display:t='hide'
    flow:t='vertical'
    margin-bottom:t='0.01@scrn_tgt'

    tdiv {
      id:t='medal_icon'
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      max-width:t='pw'
    }
  }

  tdiv {
    id:t='tasks_history_frame'
    size:t='pw,ph'
    overflow-y:t='auto'
  }

  navBar {
    navLeft {
      Button_text {
        id:t = 'btn_requirements_list'
        text:t = '#unlocks/requirements'
        _on_click:t = 'onViewBattleTaskRequirements'
        btnName:t='RB'
        ButtonImg {}
        display:t = 'hide'
        enable:t='no'
      }

      textareaNoTab {
        id:t='warbonds_balance'
        pos:t='1@buttonMargin, 50%ph-50%h'
        position:t='relative'
        margin-right:t='1@buttonMargin'
        hideEmptyText:t='yes'
        text:t=''

        behaviour:t='Timer'
      }
    }
    navRight {
      Button_text {
        id:t = 'btn_warbonds_shop'
        display:t = 'hide'
        enable:t='no'
        visualStyle:t='secondary'
        btnName:t='X'
        _on_click:t = 'onWarbondsShop'
        buttonWink{}
        buttonGlance{}
        ButtonImg {}
        <<#unseenIcon>>
        unseenIcon {
          value:t='<<unseenIcon>>'
          valign:t='center'
          noMargin:t='yes'
          tooltip = '#mainmenu/items_shop_new_items'
          unseenText {}
        }
        <</unseenIcon>>
        img {
          size:t='1@cIco, 1@cIco'
          background-svg-size:t='1@cIco, 1@cIco'
          background-image:t='#ui/gameuiskin#wb.svg'
        }
        text {
          margin-left:t='1@blockInterval'
          text:t='#mainmenu/btnWarbondsShop'
        }
      }
    }
  }
}
