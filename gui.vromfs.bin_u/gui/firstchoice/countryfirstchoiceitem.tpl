div {
  id:t='country_choice_list_box';
  left:t='50%pw-50%w'
  position:t='relative'
  width:t='<<width>>'
  flow:t='h-flow'
  total-input-transparent:t='yes'

  behaviour:t='posNavigator'
  navigatorShortcuts:t='yes'
  on_select:t='onSelectCountry';
  _on_activate:t='onEnterChoice'
  _on_click:t='onEnterChoice'

  <<#countries>>
  firstChoiceItem {
    class:t='country'

    firstChoiceImage {
      background-image:t='<<backgroundImage>>'
    }

    <<#lockText>>
    enable:t='no';
    img {
      background-image:t='#ui/gameuiskin#locked.svg';
      position:t='absolute';
      size:t='@mIco, @mIco';
      background-svg-size:t='@mIco, @mIco';
    }
    textAreaCentered {
      width:t='pw - 2@countryChoiceInterval'
      pos:t='50%pw-50%w, @countryChoiceImageHeight -  h - @countryChoiceInterval'
      position:t='absolute'
      smallFont:t='yes'
      text:t='<<lockText>>'
    }
    <</lockText>>

    firstChoiceText {
      text:t='<<countryName>>'
      css-hier-invalidate:t='yes'

      ButtonImg {
        size:t='40@sf/@pf, 40@sf/@pf'
        pos:t='50%ph-50%w, 50%ph-50%h'
        position:t='absolute'
        showOnSelect:t='yes'
        btnName:t='A'
      }
    }
  }
  <</countries>>
}
