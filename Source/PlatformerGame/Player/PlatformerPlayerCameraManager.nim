import ue4

import CharacterInterface

uclass APlatformerPlayerCameraManager of APlayerCameraManager:
  var maxCameraZoomOffset: FVector
    ## fixed maximal camera distance from player pawn ; used for zoom
  var minCameraZoomOffset: FVector
    ## fixed minimal camera distance from player pawn ; used for zoom
  var cameraOffsetInterpSpeed: float32
    ## interpolation speed for changing camera Z axis offset
  var fixedCameraOffsetZ: float32
    ## fixed camera Z axis offset from player pawn
  var cameraFixedRotation: FRotator
    ## Fixed rotation of the camera relative to player pawn
  var currentZoomAlpha: float32
    ## current value of zoom <0, 1> (0 means MinCameraZoomOffset will be used, 1 means MaxCameraZoomOffset will)
  var currentCameraOffsetZ: float32
    ## currently used camera Z axis offset
  var desiredCameraOffsetZ: float32

  proc init() {.constructor.} =
    minCameraZoomOffset = vec(240.0, 600.0, 0.0)
    maxCameraZoomOffset = minCameraZoomOffset * 4.0
    currentZoomAlpha = 0.1

    desiredCameraOffsetZ = 0.0
    currentCameraOffsetZ = 0.0
    cameraOffsetInterpSpeed = 5.0

    cameraFixedRotation = rot(0.0, -90.0, 0.0)
    fixedCameraOffsetZ = 130.0

  proc setFixedCameraOffsetZ*(inOffset: float32) {.bpCallable, category: "Game|Player".} =
    ## sets new value of FixedCameraOffsetZ
    fixedCameraOffsetZ = inOffset

  proc setCameraZoom*(zoomAlpha: float32) {.bpCallable, category: "Game|Player".} =
    ## sets new value of CurrentZoomAlpha <0, 1>
    currentZoomAlpha = clamp(zoomAlpha, 0.0, 1.0)

  proc getCameraZoom*(): float32 {.bpCallable, category: "Game|Player", thisConst.} =
    ## gets current value of CurrentZoomAlpha
    result = currentZoomAlpha

  method updateViewTargetInternal*(outVT: var FTViewTarget, deltaTime: float32) {.override.} =
    ## handle camera updates
    var viewLoc: FVector
    var viewRot: FRotator

    outVT.target.getActorEyesViewPoint(viewLoc, viewRot)
    viewLoc.z = calcCameraOffsetZ(deltaTime)
    viewLoc.z += fixedCameraOffsetZ

    let currentCameraZoomOffset = minCameraZoomOffset + currentZoomAlpha * (maxCameraZoomOffset - minCameraZoomOffset)
    outVT.POV.location = viewLoc + currentCameraZoomOffset
    outVT.POV.rotation = cameraFixedRotation

  proc calcCameraOffsetZ*(deltaTime: float32): float32 =
    ## calculates camera Z axis offset dependent on player pawn movement
    let pawn = if this.PCOwner != nil: ueCast[APlatformerCharacterBase](this.PCOwner.getPawn()) else: nil
    if pawn != nil:
      let locZ = pawn.getActorLocation().z
      if pawn.getCharacterMovement() != nil and pawn.getCharacterMovement().isFalling:
        if locZ < desiredCameraOffsetZ:
          desiredCameraOffsetZ = locZ
        elif locZ > desiredCameraOffsetZ + pawn.getCameraHeightChangeThreshold():
          desiredCameraOffsetZ = locZ
      else:
        desiredCameraOffsetZ = locZ

      if currentCameraOffsetZ != desiredCameraOffsetZ:
        currentCameraOffsetZ = fInterpTo(currentCameraOffsetZ, desiredCameraOffsetZ, deltaTime, cameraOffsetInterpSpeed)

    result = currentCameraOffsetZ
