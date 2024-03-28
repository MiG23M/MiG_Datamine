from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { updateContacts = @(...) null } = isPlatformSony ? require("%scripts/contacts/psnContactsManager.nut")
    : isPlatformXboxOne ? require("%scripts/contacts/xboxContactsManager.nut")
    : null

return updateContacts
