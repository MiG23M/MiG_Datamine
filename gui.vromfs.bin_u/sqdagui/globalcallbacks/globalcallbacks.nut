from "%sqDagui/daguiNativeApi.nut" import *

let enums = require("%sqStdLibs/helpers/enums.nut")
let { assertf } = require("dagor.debug")
let { json_to_string, parse_json } = require("json")

let callbacks = {
  types = []
}

let cbTbl = {}

callbacks.template <- {
  id = "" //filled automatically by typeName
  cbName = "" // filled automatically
  onCb = @(_obj, _params) null
  paramsKey = "actionData"
  getParamsMarkup = @(params) $"{this.paramsKey}:t='{json_to_string(params, false)}';"
  cbFromObj = @(obj) this.onCb(obj, obj?.isValid() && (obj?[this.paramsKey] ?? "") != "" ? parse_json(obj[this.paramsKey]) : {})
}

callbacks.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable,
    function() {
      this.cbName = $"::gcb.{this.id}"
      assertf(!(this.id in cbTbl), $"globalCallbacks: Found duplicating id: {this.id}")
      cbTbl[this.id] <- this.cbFromObj.bindenv(this)
    },
    "id")
}

let EMPTY = {}

callbacks.addTypes({
  EMPTY
})

callbacks.get <- @(typeId) this?[typeId] ?? EMPTY

::gcb <- cbTbl

return callbacks
