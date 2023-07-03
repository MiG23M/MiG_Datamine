root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    max-height:t='1@maxWindowHeightNoSrh'
    position:t='absolute'
    class:t='wnd'
    padByLine:t='yes'

    frame_header {
      activeText {
        id:t='wnd_title'
        caption:t='yes'
        text:t='<<frameHeaderText>>'
      }
      Button_close {}
    }
    craftTreeScrollDiv {
      id:t='craft_tree'
      position:t='relative'
      flow:t='vertical'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      <<#itemsSize>>itemsSize:t='<<itemsSize>>'<</itemsSize>>
      tdiv {
        id:t='craft_header'
        include "%gui/items/craftTreeHeader.tpl"
      }

      craftBranchBody {
        id:t='craft_body'
        size:t='<<bodyWidth>>, <<bodyHeight>>'
        flow:t='h-flow'
        total-input-transparent:t='yes'

        behaviour:t='posNavigator'
        navigatorShortcuts:t='yes'
        moveX:t='linear'
        moveY:t='closest'

        on_activate:t='onMainAction'
        on_pushed:t='::gcb.delayedTooltipListPush'
        on_hold_start:t='::gcb.delayedTooltipListHoldStart'
        on_hold_stop:t='::gcb.delayedTooltipListHoldStop'

        include "%gui/items/craftTreeBody.tpl"
      }
    }
  }
}

timer
{
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
