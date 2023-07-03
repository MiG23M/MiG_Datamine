id:t='<<slotId>>'
<<#isTooltipByHold>>tooltipId:t='<<tooltipId>>'<</isTooltipByHold>>

<<#position>>
position:t='<<position>>'
pos:t='<<posX>>w, <<posY>>h'
<</position>>

<<#slotInactive>>
inactive:t='yes'
<</slotInactive>>

shopItem {
  id:t='<<shopItemId>>'
  behavior:t='Timer'
  timer_interval_msec:t='1000'
  unit_name:t='<<unitName>>'

  <<#isTooltipByHold>>
  tooltipId:t='<<tooltipId>>'
  on_hover:t='::gcb.delayedTooltipHover'
  on_unhover:t='::gcb.delayedTooltipHover'
  <</isTooltipByHold>>

  slotPlate {
    middleBg {
      pattern {
        type:t='bright_texture'
      }
    }
    topLine {}
    bottomShade {}
  }

  itemWinkBlock {
    buttonWink {
      _transp-timer:t='0'
    }
  }

  hoverHighlight {}

  shopStat:t='<<shopStatus>>'
  unitRarity:t='<<unitRarity>>'
  shopAirImg {
    foreground-image:t='<<shopAirImg>>'
  }

  <<#isElite>>
  eliteIcon {}
  <</isElite>>

  <<#hasTalismanIcon>>
  talismanIcon {}
  <</hasTalismanIcon>>

  topline {
    shopItemText {
      id:t='<<shopItemTextId>>'
      text:t='<<shopItemText>>'
      header:t='yes'
      <<#needMultiLineName>>isMultiLine:t='yes'<</needMultiLineName>>

      <<#isItemDisabled>>
      disabled:t='yes'
      <</isItemDisabled>>
      <<^isItemDisabled>>
      disabled:t='no'
      <</isItemDisabled>>
    }
  }

  bottomline {
    <<^bottomLineText>>
    shopItemText {
      id:t='rank_text'
      text:t='<<unitRankText>>'
      header:t='yes'
    }
    <</bottomLineText>>
    <<#bottomLineText>>
    tdiv{
      width:t='pw'
      overflow:t='hidden'
      shopItemText {
        autoScrollText:t='hoverOrSelect'
        min-width:t="pw-0.006@sf"
        text:t='<<bottomLineText>>'
        text-align:t='right'
      }
    }
    <</bottomLineText>>
  }

  <<^isTooltipByHold>>
  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  title:t='$tooltipObj'
  <</isTooltipByHold>>

  focus_border{}
}
