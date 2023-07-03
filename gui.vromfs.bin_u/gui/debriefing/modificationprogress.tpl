tdiv {
  id:t='<<id>>'
  width:t='pw'
  margin:t='0, 1@slot_vert_pad'

  behavior:t='posNavigator'
  navigatorShortcuts:t='yes'
  <<#isTooltipByHold>>
  on_pushed:t='::gcb.delayedTooltipListPush'
  on_hold_start:t='::gcb.delayedTooltipListHoldStart'
  on_hold_stop:t='::gcb.delayedTooltipListHoldStop'
  <</isTooltipByHold>>

  tdiv {
    pos:t='0, 50%ph-50%h'; position:t='relative'
    size:t='2@modItemHeight, 1@modItemHeight'
    total-input-transparent:t='yes'
    <<#isTooltipByHold>>
    tooltipId:t='<<unitTooltipId>>'
    on_hover:t='::gcb.delayedTooltipHover'
    on_unhover:t='::gcb.delayedTooltipHover'
    <</isTooltipByHold>>

    img {
      height:t='1@slot_height -2@slot_vert_pad -2'
      pos:t='0, ph/2-h/2'; position:t='absolute'
      width:t='2.7h'
      background-image:t='<<unitImg>>'
      background-repeat:t='aspect-ratio'
      background-align:t='left'
    }

    textareaNoTab {
      width:t='pw - 0.5@cIco'
      pos:t='0, 25%ph-h/2'; position:t='absolute'
      text-align:t='right'
      style:t='font:@shopItemFont;'
      overlayTextColor:t='active'
      shadeStyle:t='textOnIcon'
      text:t='<<unitName>>'
    }

    <<^isTooltipByHold>>
    title:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='<<unitTooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    <</isTooltipByHold>>
  }

  tdiv {
    size:t='fw, 1@modItemHeight'
    <<#isTooltipByHold>>
    tooltipId:t='<<modTooltipId>>'
    on_hover:t='::gcb.delayedTooltipHover'
    on_unhover:t='::gcb.delayedTooltipHover'
    <</isTooltipByHold>>


    <<#hasModItem>>
    weaponry_item {
      id:t='mod_<<id>>'
      size:t='pw, ph'
      total-input-transparent:t='yes'
      css-hier-invalidate:t='yes'
      equipped:t='<<optEquipped>>'
      status:t= '<<optStatus>>'

      weaponBody {
        id:t='centralBlock'
        size:t='1@modItemHeight, 1@modItemHeight'
        position:t='relative'

        topLine {}
        wallpaper {
          size:t='pw, ph'
          position:t='absolute'
          css-hier-invalidate:t='yes'
          pattern {}
        }

        include "%gui/weaponry/weaponIcon.tpl"
        itemWinkBlock { buttonWink { _transp-timer:t='0' } }

      }

      tdiv {
        pos:t='0.5@cIco'
        position:t='relative'
        size:t='fw, ph'

        textareaNoTab {
          id:t='name'
          pos:t='0, 25%ph-h/2'
          width:t='pw'
          position:t='absolute'
          style:t='font:@shopItemFont; color:@activeTextColor; width:pw;'
          text:t=''
        }

        <<#isCompleted>>
        tdiv{
          pos:t='0, 75%ph-h/2'
          width:t='pw'
          position:t='absolute'
          img {
            size:t='0.75@unlockIconSize, 0.75@unlockIconSize'
            pos:t='-h/6, ph/2-h/2'; position:t='relative'
            margin-right:t='h/6'
            background-image:t='#ui/gameuiskin#favorite'
          }
          textareaNoTab {
            pos:t='0, ph/2-h/2'; position:t='relative'
            width:t='fw'
            style:t='font:@shopItemFont; color:@goodTextColor;'
            text:t='#mainmenu/completed'
          }
        }
        <</isCompleted>>
        <<^isCompleted>>
        tdiv {
          id:t='mod_research_block'
          pos:t='0, 75%ph-h/2'
          position:t='absolute'
          flow:t='vertical'
          textareaNoTab {
            id:t='mod_research_text'
            pos:t='0.5pw - 0.5w, 0'
            position:t='relative'
            tinyFont:t='yes'
            text:t=''
          }
          tdiv {
            pos:t='2@dp, 0'
            position:t='relative'

            modResearchProgress {
              id:t='mod_research_progress'
              style:t='width:100@sf/@pf_outdated'
              paused:t='no'
            }
            modResearchProgress {
              id:t='mod_research_progress_old'
              style:t='width:100@sf/@pf_outdated'
              type:t='old'
              position:t='absolute'
              value:t='500'
              paused:t='no'
            }
          }
        }
        <</isCompleted>>
      }

      <<^isTooltipByHold>>
      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<modTooltipId>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
      <</isTooltipByHold>>

      hoverHighlight {}
    }
    <</hasModItem>>

    <<^hasModItem>>
    textAreaCentered {
      id:t='no_mod_text'
      width:t='pw'
      pos:t='pw/2-w/2, ph/2-h/2'; position:t='relative'
      text:t=''
      smallFont:t='yes'
    }
    <</hasModItem>>
  }
}
