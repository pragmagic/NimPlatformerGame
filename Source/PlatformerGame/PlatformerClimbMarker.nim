import ue4

uclass (APlatformerClimbMarker of AActor, Blueprintable):
  UProperty(VisibleDefaultsOnly, BlueprintReadOnly, Category=Mesh, meta=(AllowPrivateAccess="true")):
    var mesh: ptr UStaticMeshComponent

  proc init() {.constructor.} =
    let sceneComp = createDefaultSubobject[USceneComponent](this, u16"SceneComp")
    this.rootComponent = sceneComp

    mesh = createDefaultSubobject[UStaticMeshComponent](this, u16"ClimbMesh")
    mesh.staticMesh = ctorLoadObject(UStaticMesh, "/Game/Environment/meshes/ClimbMarker")
    mesh.relativeScale3D = vec(0.25, 1.0, 0.25)
    mesh.attachParent = sceneComp

  proc getMesh*(): ptr UStaticMeshComponent =
    result = mesh
