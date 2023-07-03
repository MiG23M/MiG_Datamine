crewStatus:t='<<crewStatus>>'

<<#hasExtraInfoBlock>>
extraInfoBlock {
  id:t='extra_info_block'
  <<#hasCrewInfo>>
  crewInfoBlock {
    icon {
      id:t='crew_spec'
      background-image:t='<<crewSpecIcon>>'
    }
    shopItemText {
      id:t='crew_level'
      text:t='<<crewLevel>>'
      _transp-timer:t='0'
    }
  }
  <</hasCrewInfo>>

  <<#hasSpareCount>>
  spareCount { text:t='<<spareCount>>' }
  <</hasSpareCount>>
}
<</hasExtraInfoBlock>>
