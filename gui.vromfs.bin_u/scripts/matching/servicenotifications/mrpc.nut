//checked for plus_string
from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")

matchingRpcSubscribe("mrpc.generic_notify", function(params) {
  let from = getTblValue("from", params)
  if (from == "web-service")
    ::handle_web_rpc(params)
  else if (from == "inventory")
    inventoryClient.handleRpc(params)
})

matchingRpcSubscribe("mrpc.generic_rpc", function(params, cb) {
  let from = getTblValue("from", params)
  if (from == "web-service") {
    let res = ::handle_web_rpc(params)
    if (type(res) == "table")
      cb(res)
    else
      cb({ result = res })
    return
  }
  else if (from == "inventory") {
    inventoryClient.handleRpc(params)
    return
  }
  cb({ error = "unknown service" })
})
