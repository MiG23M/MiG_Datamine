from "%scripts/dagui_library.nut" import *
let { request_matching } = require("%scripts/matching/api.nut")

function request_nick_by_uid_batch(user_ids, cb = null) {
  request_matching("mproxy.nick_server_request", cb, null,
    { ids = user_ids }, { showError = false })
}

return {
  request_nick_by_uid_batch = request_nick_by_uid_batch
}