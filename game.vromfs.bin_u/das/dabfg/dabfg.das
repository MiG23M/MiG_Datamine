module daBfg shared

require daBfgCore public
require DagorDriver3D public
require DagorShaders public


struct NameSpaceRequest
  nameSpaceId : NameSpaceNameId
  nodeId : NodeNameId
  registry : InternalRegistry?

struct Registry : NameSpaceRequest {}

struct NameSpace
  nameSpaceId : NameSpaceNameId

struct ResUid
  nameId : ResNameId
  history : bool

struct VirtualResourceRequestBase
  registry : InternalRegistry?
  resUid : ResUid
  nodeId : NodeNameId


struct VirtualResourceHandle
  registry : InternalRegistry?
  resUid : ResUid

struct VirtualResourceCreationSemiRequest : VirtualResourceRequestBase {}
struct VirtualResourceSemiRequest : VirtualResourceRequestBase {}
struct VirtualResourceRequest : VirtualResourceRequestBase {}

struct VirtualTextureHandle : VirtualResourceHandle {}
struct VirtualBufferHandle : VirtualResourceHandle {}

struct VirtualTextureRequest : VirtualResourceRequest {}
struct VirtualBufferRequest : VirtualResourceRequest {}


struct StateRequest
  registry : InternalRegistry?
  nodeId : NodeNameId

variant VrsRateTexture
  some : VirtualResourceSemiRequest
  none : void?

struct VrsRequirements
  rateX : uint
  rateY : uint
  rateTexture : VrsRateTexture
  vertexCombiner : VariableRateShadingCombiner
  pixelCombiner : VariableRateShadingCombiner

struct VirtualPassRequest
  registry : InternalRegistry?
  nodeId : NodeNameId


variant VirtualAttachmentResource
  resUid : ResUid
  name : string


struct VirtualAttachmentRequest
  resource : VirtualAttachmentResource
  mipLevel : uint
  layer : uint


struct AutoResolutionRequest
  autoResTypeId : AutoResTypeNameId
  multiplier : float = 1.0f
  registry : InternalRegistry?


variant TextureResolution
  res : tuple<x : uint; y : uint>
  autoRes : AutoResolutionRequest


struct Texture2dCreateInfo
  resolution : TextureResolution
  creationFlags : uint
  mipLevels : uint


struct BufferCreateInfo
  elementSize : uint
  elementCount : uint
  flags : uint
  format : uint


struct NamedSlot
  name : string

def root() : NameSpace
  return [[NameSpace nameSpaceId = getRegistry().knownNames |> root]]


def operator /(var self : NameSpace; child_name : string) : NameSpace
  return [[NameSpace nameSpaceId = getRegistry().knownNames |> addNameId`NameSpaceNameId(self.nameSpaceId, child_name)]]


def fillSlot(var self : NameSpace; slot : NamedSlot; res_name_space : NameSpace; res_name : string)
  fill_slot(self.nameSpaceId, slot.name, res_name_space.nameSpaceId, res_name)


def private get(var resources : idIndexedMapping`ResNameId`ResourceData&; res_id : ResNameId; cb : block<(var value : ResourceData) : void>) : void
  cb |> invoke(resources |> get(res_id))


def private get(var nodes : idIndexedMapping`NodeNameId`NodeData&; node_id : NodeNameId; cb : block<(var value : NodeData) : NodeHandle>) : NodeHandle
  return <- cb |> invoke(nodes |> get(node_id))


def registerNode(var self : NameSpace; name : string; var declaration_callback : lambda<(var reg : Registry) : lambda<void>>) : NodeHandle
  var registry = getRegistry()
  let nodeId = registry.knownNames |> addNameId`NodeNameId(self.nameSpaceId, name)
  return <- registry.nodes |> get(nodeId) <| $(var node_data : NodeData&)
    getTracker() |> unregisterNode(nodeId, node_data.generation)
    getTracker() |> registerNode(nodeId)
    node_data |> registerNodeDeclaration(self.nameSpaceId) <| @ [[ <- declaration_callback, =registry ]] ()
      return <- declaration_callback |> invoke() <| [[Registry
        nameSpaceId = self.nameSpaceId,
        nodeId = nodeId,
        registry = registry
      ]]
    return <- register_external_node(nodeId, node_data.generation)


def root(var self : Registry) : NameSpaceRequest
  return [[NameSpaceRequest nameSpaceId = self.registry.knownNames |> root, nodeId = self.nodeId, registry = self.registry]]


def orderMeBefore(var self : Registry; name : string) : Registry
  let nodeNsId = self.registry.knownNames |> getParent(self.nodeId)
  let nameId = self.registry.knownNames |> getNameId`NodeNameId(nodeNsId, name)
  if nameId != NodeNameId Invalid
    self.registry.nodes[self.nodeId].followingNodeIds |> insert(nameId)
  else
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Node {selfName} tries to order before not existing node {name}, skipping this order")

  return self


def orderMeBefore(var self : Registry; names : array<string>) : Registry
  for name in names
    self |> orderMeBefore(name)

  return self


def orderMeAfter(var self : Registry; name : string) : Registry
  let nodeNsId = self.registry.knownNames |> getParent(self.nodeId)
  let nameId = self.registry.knownNames |> getNameId`NodeNameId(nodeNsId, name)
  if nameId != NodeNameId Invalid
    self.registry.nodes[self.nodeId].precedingNodeIds |> insert(nameId)
  else
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Node {selfName} tries to order after not existing node {name}, skipping this order")

  return self


def orderMeAfter(var self : Registry; names : array<string>) : Registry
  for name in names
    self |> orderMeAfter(name)

  return self


def setPriority(var self : Registry; priority : int) : Registry
  self.registry.nodes[self.nodeId].priority = priority
  return self


def multiplex(var self : Registry; multiplexing_mode : MultiplexingMode) : Registry
  self.registry.nodes[self.nodeId].multiplexingMode = multiplexing_mode
  return self


def executionHas(var self : Registry; side_effect : SideEffect) : Registry
  self.registry.nodes[self.nodeId].sideEffect = side_effect
  return self


def create(var self : Registry; name : string; history : History) : VirtualResourceCreationSemiRequest
  let nodeNsId = self.registry.knownNames |> getParent(self.nodeId)
  let nameId = self.registry.knownNames |> addNameId`ResNameId(nodeNsId, name)
  self.registry.resources |> get(nameId) <| $(var res : ResourceData&)
    res.history = history;

  self.registry.nodes[self.nodeId].createdResources |> insert(nameId)
  using() <| $(var req : ResourceRequest#)
    req.usage = [[ResourceUsage access=Access READ_WRITE]]
    self.registry.nodes[self.nodeId].resourceRequests[nameId] := req

  return <- [[VirtualResourceCreationSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=nameId, history=false]]]]


def operator /(var self : NameSpaceRequest; child_name : string) : NameSpaceRequest
  return [[NameSpaceRequest
    nameSpaceId = self.registry.knownNames |> addNameId`NameSpaceNameId(self.nameSpaceId, child_name),
    nodeId = self.nodeId,
    registry = self.registry]]


def getResolution(var self : NameSpaceRequest; type_name : string; multiplier : float = 1.f) : AutoResolutionRequest
  return [[AutoResolutionRequest
    autoResTypeId=self.registry.knownNames |> addNameId`AutoResTypeNameId(self.nameSpaceId, type_name),
    multiplier=multiplier,
    registry=self.registry]]


def read(var self : NameSpaceRequest; name : string) : VirtualResourceSemiRequest
  let nameId = self.registry.knownNames |> addNameId`ResNameId(self.nameSpaceId, name)
  self.registry.nodes[self.nodeId].readResources |> insert(nameId)
  using() <| $(var req : ResourceRequest#)
    req.usage = [[ResourceUsage access=Access READ_ONLY]]
    self.registry.nodes[self.nodeId].resourceRequests[nameId] := req

  return <- [[VirtualResourceSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=nameId, history=false]]]]


def read(var self : NameSpaceRequest; slot : NamedSlot) : VirtualResourceSemiRequest
  let nameId = self.registry.knownNames |> addNameId`ResNameId(self.nameSpaceId, slot.name)
  self.registry.nodes[self.nodeId].readResources |> insert(nameId)
  using() <| $(var req : ResourceRequest#)
    req.slotRequest = true
    req.usage = [[ResourceUsage access=Access READ_ONLY]]
    self.registry.nodes[self.nodeId].resourceRequests[nameId] := req

  return <- [[VirtualResourceSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=nameId, history=false]]]]


def history(var self : NameSpaceRequest; var name : string) : VirtualResourceSemiRequest
  let nameId = self.registry.knownNames |> addNameId`ResNameId(self.nameSpaceId, name)
  using() <| $(var req : ResourceRequest#)
    req.usage = [[ResourceUsage access=Access READ_ONLY]]
    self.registry.nodes[self.nodeId].historyResourceReadRequests[nameId] := req

  return <- [[VirtualResourceSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=nameId, history=true]]]]


def modify(var self : NameSpaceRequest; name : string) : VirtualResourceSemiRequest
  let nameId = self.registry.knownNames |> addNameId`ResNameId(self.nameSpaceId, name)
  self.registry.nodes[self.nodeId].modifiedResources |> insert(nameId)
  using() <| $(var req : ResourceRequest#)
    req.usage = [[ResourceUsage access=Access READ_WRITE]]
    self.registry.nodes[self.nodeId].resourceRequests[nameId] := req

  return <- [[VirtualResourceSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=nameId, history=false]]]]


def modify(var self : NameSpaceRequest; slot : NamedSlot) : VirtualResourceSemiRequest
  let nameId = self.registry.knownNames |> addNameId`ResNameId(self.nameSpaceId, slot.name)
  self.registry.nodes[self.nodeId].modifiedResources |> insert(nameId)
  using() <| $(var req : ResourceRequest#)
    req.slotRequest = true
    req.usage = [[ResourceUsage access=Access READ_WRITE]]
    self.registry.nodes[self.nodeId].resourceRequests[nameId] := req

  return <- [[VirtualResourceSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=nameId, history=false]]]]


def rename(var self : NameSpaceRequest; from : string; to : string; history : History) : VirtualResourceSemiRequest
  let fromResId = self.registry.knownNames |> addNameId`ResNameId(self.nameSpaceId, from)
  let nodeNsId = self.registry.knownNames |> getParent(self.nodeId)
  let toResId = self.registry.knownNames |> addNameId`ResNameId(nodeNsId, to)

  self.registry.nodes[self.nodeId].renamedResources[toResId] := fromResId
  using() <| $(var req : ResourceRequest#)
    req.usage = [[ResourceUsage access=Access READ_WRITE]]
    self.registry.nodes[self.nodeId].resourceRequests[fromResId] := req
  self.registry.resources |> get(toResId) <| $(var res : ResourceData&)
    res.history = history

  return <- [[VirtualResourceSemiRequest registry=self.registry, nodeId=self.nodeId, resUid=[[ResUid nameId=fromResId, history=false]]]]


def texture(var self : VirtualResourceCreationSemiRequest; info : Texture2dCreateInfo) : VirtualTextureRequest
  self.registry.resources |> get(self.resUid.nameId) <| $(var res : ResourceData&)
    using() <| $(var desc : TextureResourceDescription#)
      desc.mipLevels = info.mipLevels
      desc.cFlags = info.creationFlags
      if info.resolution is autoRes
        res |> setResolution([[AutoResolutionData
          id = info.resolution as autoRes.autoResTypeId,
          multiplier = info.resolution as autoRes.multiplier]])
      else
        desc.width = info.resolution as res.x
        desc.height = info.resolution as res.y
      res |> setTextureInfo(desc)

    res.resType = ResourceType Texture

  return <- [[VirtualTextureRequest registry=self.registry, nodeId=self.nodeId, resUid=self.resUid]]


def texture(var self : VirtualResourceSemiRequest) : VirtualTextureRequest
  return <- [[VirtualTextureRequest registry=self.registry, nodeId=self.nodeId, resUid=self.resUid]]


def buffer(var self : VirtualResourceCreationSemiRequest; info : BufferCreateInfo) : VirtualBufferRequest
  self.registry.resources |> get(self.resUid.nameId) <| $(var res : ResourceData&)
    using() <| $(var desc : BufferResourceDescription#)
      desc.elementCount = info.elementCount
      desc.elementSizeInBytes = info.elementSize
      desc.viewFormat = info.format
      desc.cFlags = info.flags
      desc.activation = ResourceActivationAction DISCARD_AS_UAV
      res |> setDescription(desc)

    res.resType = ResourceType Buffer

  return <- [[VirtualBufferRequest registry=self.registry, nodeId=self.nodeId, resUid=self.resUid]]


def buffer(var self : VirtualResourceSemiRequest) : VirtualBufferRequest
  return <- [[VirtualBufferRequest registry=self.registry, nodeId=self.nodeId, resUid=self.resUid]]


def blob(var self : VirtualResourceSemiRequest) : VirtualResourceRequest
  assert(false, "Blobs are not implemented in daScript API")
  self.registry.resources |> get(self.resUid.nameId) <| $(var res : ResourceData&)
    res.resType = ResourceType Blob

  return <- [[VirtualResourceRequest registry=self.registry, nodeId=self.nodeId, resUid=self.resUid]]


def modifyRequest(var self : VirtualResourceRequest; modifier : block<(var request : daBfgCore::ResourceRequest) : void>)
  invoke(modifier, self.resUid.history ?
    self.registry.nodes[self.nodeId].historyResourceReadRequests[self.resUid.nameId] :
    self.registry.nodes[self.nodeId].resourceRequests[self.resUid.nameId])


def optional(var self : auto(TT)) : TT
  let setOptional = $ <| (var request : ResourceRequest &)
    request.optional = true
  self |> modifyRequest(setOptional)
  return self


def useAs(var self : auto(TT); usageType : Usage) : TT
  let setUsage = $ <| (var request : ResourceRequest &)
    request.usage.usageType = usageType
  self |> modifyRequest(setUsage)
  return self


def atStage(var self : auto(TT); stage : Stage) : TT
  let setStage = $ <| (var request : ResourceRequest &)
    request.usage.stage = stage
  self |> modifyRequest(setStage)
  return self


def bindToShaderVar(var self : auto(TT); name : string = "") : TT
  var svName = name
  if (name == "")
    svName = self.registry.knownNames |> getShortName(self.resUid.nameId)

  let svId = get_shader_variable_id(svName)
  assume bindings = self.registry.nodes[self.nodeId].bindings
  if !(bindings |> key_exists(svId))
    using() <| $(var info : Binding#)
      info.bindType = BindingType ShaderVar
      info.resource = self.resUid.nameId
      info.history = self.resUid.history
      bindings[svId] := info
  else
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Encountered duplicate shader var {name} binding in {selfName} frame graph node! Ignoring one of the them!")

  useAs(self, Usage SHADER_RESOURCE)
  return self


def handle(self : VirtualTextureRequest) : VirtualTextureHandle
  return <- [[VirtualTextureHandle registry=self.registry, resUid=self.resUid]]


def handle(self : VirtualBufferRequest) : VirtualBufferHandle
  return <- [[VirtualBufferHandle registry=self.registry, resUid=self.resUid]]


def view(handle : VirtualTextureHandle) : ManagedTexView
  return handle.registry |> getResourceProvider |> getTexView(handle.resUid.nameId, handle.resUid.history)


def view(handle : VirtualBufferHandle) : ManagedBufView
  return handle.registry |> getResourceProvider |> getBufView(handle.resUid.nameId, handle.resUid.history)


def get(resolution : AutoResolutionRequest) : int2
  return resolution.registry |> getResourceProvider |> getResolution(resolution.autoResTypeId)


def requestState(var self : Registry) : StateRequest
  if self.registry.nodes[self.nodeId].stateRequirements is some
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Global state requested twice on {selfName} frame graph node! Ignoring one of the requests!")

  self.registry.nodes[self.nodeId].stateRequirements |> emplace_some

  return [[StateRequest registry=self.registry, nodeId=self.nodeId]]


def private setBlock(var self : StateRequest; name : string; layer : string; var value : int&) : StateRequest
  if value != -1
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Block requested to be set to layer {layer} twice within {selfName} frame graph node! Ignoring one of the requests!")

  value = getBlockId(name)
  return self


def setFrameBlock(var self : StateRequest; name : string) : StateRequest
  return self |> setBlock(name, "'FRAME'", self.registry.nodes[self.nodeId].shaderBlockLayers.frameLayer)


def setSceneBlock(var self : StateRequest; name : string) : StateRequest
  return self |> setBlock(name, "'SCENE'", self.registry.nodes[self.nodeId].shaderBlockLayers.sceneLayer)


def setObjectBlock(var self : StateRequest; name : string) : StateRequest
  return self |> setBlock(name, "'OBJECT'", self.registry.nodes[self.nodeId].shaderBlockLayers.objectLayer)


def allowWireFrame(var self : StateRequest) : StateRequest
  assume stateReqs = self.registry.nodes[self.nodeId].stateRequirements as some
  stateReqs.supportsWireframe = true
  return self


def allowVrs(var self : StateRequest; vrs : VrsRequirements) : StateRequest
  if vrs.rateTexture is none
    // TODO: reset rate texture?
    return self

  let rateTexId = (vrs.rateTexture as some).resUid.nameId
  self.registry.nodes[self.nodeId].readResources |> insert(rateTexId)
  using() <| $(var req : ResourceRequest#)
    req.usage = [[ResourceUsage access=Access READ_ONLY, usageType=Usage VRS_RATE_TEXTURE, stage=Stage ALL_GRAPHICS]]
    self.registry.nodes[self.nodeId].resourceRequests[rateTexId] := req

  assume stateReqs = self.registry.nodes[self.nodeId].stateRequirements as some
  stateReqs.vrsState |> emplace_some
  assume vrsState = stateReqs.vrsState as some

  vrsState.rateX = vrs.rateX
  vrsState.rateY = vrs.rateY
  vrsState.rateTextureResId = rateTexId
  vrsState.vertexCombiner = vrs.vertexCombiner
  vrsState.pixelCombiner = vrs.pixelCombiner

  return self


def enableOverride(var self : StateRequest; das_override : OverrideRenderState)
  assume stateReqs = self.registry.nodes[self.nodeId].stateRequirements as some
  stateReqs.pipelineStateOverride |> emplace_some
  assume final_override = stateReqs.pipelineStateOverride as some

  final_override.bits = uint(das_override.bits)
  final_override.zFunc = uint8(das_override.zFunc)
  final_override.forcedSampleCount = das_override.forcedSampleCount
  final_override.blendOp = uint8(das_override.blendOp)
  final_override.blendOpA = uint8(das_override.blendOpA)
  final_override.sblend = uint8(das_override.sblend)
  final_override.dblend = uint8(das_override.dblend)
  final_override.sblenda = uint8(das_override.sblenda)
  final_override.dblenda = uint8(das_override.dblenda)
  final_override.colorWr = uint(das_override.colorWr)

  return self


def requestRenderPass(var self : Registry) : VirtualPassRequest
  if self.registry.nodes[self.nodeId].renderingRequirements is some
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Encountered two renderpass requests in {selfName} framegraph node! Ignoring one of the requests!")

  self.registry.nodes[self.nodeId].renderingRequirements |> emplace_some

  return [[VirtualPassRequest registry=self.registry, nodeId=self.nodeId]]


def private processAttachment(var self : VirtualPassRequest; attachment : VirtualAttachmentRequest; access_override : Access) : ResUid
  var uid : ResUid
  if attachment.resource is resUid
    uid = attachment.resource as resUid
  else
    let nodeNsId = self.registry.knownNames |> getParent(self.nodeId)
    let resId = self.registry.knownNames |> addNameId`ResNameId(nodeNsId, attachment.resource as name)
    if (access_override == Access READ_ONLY)
      self.registry.nodes[self.nodeId].readResources |> insert(resId)
    else
      self.registry.nodes[self.nodeId].modifiedResources |> insert(resId)

    uid.nameId = resId
    uid.history = false

  return uid


def color(var self : VirtualPassRequest; requests : VirtualTextureRequest[]) : VirtualPassRequest
  let attachments <- [{for req in requests; [[VirtualAttachmentRequest resource=[[VirtualAttachmentResource resUid=req.resUid]]]]}]
  return self |> color(attachments)


def color(var self : VirtualPassRequest; names : string[]) : VirtualPassRequest
  let attachments <- [{for name in names; [[VirtualAttachmentRequest resource=[[VirtualAttachmentResource name=name]]]]}]
  return self |> color(attachments)


def color(var self : VirtualPassRequest; attachments : array<VirtualAttachmentRequest>) : VirtualPassRequest
  assume reqs = self.registry.nodes[self.nodeId].renderingRequirements as some

  if reqs.colorAttachments |> length != 0
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Encountered duplicate color attachment calls on the same pass request in {selfName} frame graph node! Ignoring one of them!")
    reqs.colorAttachments |> clear()

  for attachment in attachments
    let uid = self |> processAttachment(attachment, Access READ_WRITE)
    verify(!uid.history)
    self.registry.nodes[self.nodeId].resourceRequests[uid.nameId].usage = [[
      ResourceUsage access=Access READ_WRITE, stage=Stage POST_RASTER, usageType=Usage COLOR_ATTACHMENT]]
    reqs.colorAttachments |> push([[VirtualSubresourceRef nameId=uid.nameId, mipLevel=attachment.mipLevel, layer=attachment.layer]])

  return self


def private depth(var self : VirtualPassRequest; name : string; usage_access : Access; read_only : bool) : VirtualPassRequest
  let attachment <- [[VirtualAttachmentRequest resource=[[VirtualAttachmentResource name=name]]]]
  return self |> depth(attachment, usage_access, read_only)


def private depth(var self : VirtualPassRequest; attachment : VirtualAttachmentRequest; usage_access : Access; read_only : bool) : VirtualPassRequest
  assume reqs = self.registry.nodes[self.nodeId].renderingRequirements as some

  if reqs.depthAttachment.nameId != ResNameId Invalid
    let selfName = self.registry.knownNames |> getName(self.nodeId)
    error("Encountered duplicate depth attachment calls on the same pass request in {selfName} frame graph node! Ignoring one of them!")

  let uid = self |> processAttachment(attachment, usage_access)
  verify(!uid.history)
  self.registry.nodes[self.nodeId].resourceRequests[uid.nameId].usage = [[
    ResourceUsage access=read_only ? Access READ_ONLY : Access READ_WRITE,
    stage=Stage POST_RASTER,
    usageType=read_only ? Usage DEPTH_ATTACHMENT_AND_SHADER_RESOURCE : Usage DEPTH_ATTACHMENT]]
  reqs.depthAttachment = [[VirtualSubresourceRef nameId=uid.nameId, mipLevel=attachment.mipLevel, layer=attachment.layer]]
  reqs.depthReadOnly = read_only

  return self


def depthRw(var self : VirtualPassRequest; attachment : auto) : VirtualPassRequest
  return self |> depth(attachment, Access READ_WRITE, false)


def depthRo(var self : VirtualPassRequest; attachment : auto) : VirtualPassRequest
  return self |> depth(attachment, Access READ_ONLY, true);
