<<#bodyBackground>>
crafBodyBackground {
  size:t='<<bodyBackgroundSize>>'
  pos:t='<<bodyBackgroundPos>>'
  position:t='absolute'
  background-image:t='<<bodyBackground>>'
  background-repeat:t='repeat'
  background-color:t='#FFFFFF'
  enable:t='no'
}
<</bodyBackground>>
<<#bodyTitles>>
  craftBranchHeader {
    size:t='<<titleSize>>'
    pos:t='<<titlePos>>'
    position:t='absolute'
    enable:t='no'
    textareaNoTab {
      position:t='absolute'
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      text:t='<<bodyTitleText>>'
    }
    <<#hasSeparator>>
      craftTreeSeparator{
        located:t='left'
      }
    <</hasSeparator>>
  }
<</bodyTitles>>
<<#shopArrows>>
  <<#arrowsParts>>
    <<partTag>> {
      <<#partType>>type:t='<<partType>>'<</partType>>
      size:t='<<partSize>>'
      pos:t='<<partPos>>'
      rotation:t='<<partRotation>>'
      enable:t='no'
      <<#isDisabled>>isDisabled:t='yes'<</isDisabled>>
    }
  <</arrowsParts>>
<</shopArrows>>
<<#conectionsInRow>>
  textareaNoTab {
    width:t='<<conectionWidth>>'
    position:t='absolute'
    pos:t='<<conectionPos>>'
    text:t='<<conectionInRowText>>'
    bigBoldFont:t='yes'
    text-align:t='center'
    enable:t='no'
  }
<</conectionsInRow>>
<<#textBlocks>>
  tdiv {
    position:t='absolute'
    size:t='<<textBlockSize>>'
    pos:t='<<textBlockPos>>'
    enable:t='no'

    textareaNoTab {
      width:t='pw'
      text:t='<<textInBlock>>'
      <<@textSize>>
      enable:t='no'
      text-align:t='<<textBlockHalign>>'
      valign:t='<<textBlockValign>>'
    }
  }
<</textBlocks>>
<<#separators>>
  <<#separatorPos>>
  craftTreeSeparator {
    pos:t='<<separatorPos>>'
    size:t='<<separatorSize>>'
  }
  <</separatorPos>>
<</separators>>

include "%gui/items/craftTreeItemBlock.tpl"

<<#buttons>>
  include "%gui/commonParts/button.tpl"
<</buttons>>

