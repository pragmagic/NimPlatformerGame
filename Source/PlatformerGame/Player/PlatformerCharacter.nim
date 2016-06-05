import ue4

import strutils

import GameModeInterface, PlatformerClimbMarker, CharacterInterface
import PlatformerPlayerController, PlatformerPlayerMovementComp

uclass APlatformerCharacter of APlatformerCharacterBase:
  UProperty(EditDefaultsOnly, Category=Config):
    var cameraHeightChangeThreshold: float32
      ## Camera is fixed to the ground, even when player jumps.
      ## But, if player jumps higher than this threshold, camera will start to follow.
      ## UPROPERTY(EditDefaultsOnly, Category=Config)

  UProperty(EditDefaultsOnly, Category=Animation):
    var wonMontage: ptr UAnimMontage
      ## animation for winning game
    var lostMontage: ptr UAnimMontage
      ## animation for loosing game
    var hitWallMontage: ptr UAnimMontage
      ## animation for running into an obstacle
    var minSpeedForHittingWall: float32
      ## minimal speed for pawn to play hit wall animation
    var climbOverSmallMontage: ptr UAnimMontage
      ## animation for climbing over small obstacle
    var climbOverSmallHeight: float32
      ## height of small obstacle
    var climbOverMidMontage: ptr UAnimMontage
      ## animation for climbing over mid obstacle
    var climbOverMidHeight: float32
      ## height of mid obstacle
    var climbOverBigMontage: ptr UAnimMontage
      ## animation for climbing over big obstacle
    var climbOverBigHeight: float32
      ## height of big obstacle
    var climbLedgeMontage: ptr UAnimMontage
      ## animation for climbing to ledge
    var climbLedgeRootOffset: FVector
      ## root offset in climb legde animation
    var climbLedgeGrabOffsetX: float32
      ## grab point offset along X axis in climb legde animation

  var animPositionAdjustment: FVector
    ## mesh translation used for position adjustments
  var prevRootMotionPosition: FVector
    ## root motion translation from previous tick

  UPROPERTY(EditDefaultsOnly, Category=Sound):
    var slideSound: ptr USoundCue
      ## looped slide sound

  var slideAC {.ue.}: ptr UAudioComponent
    ## audio component playing looped slide sound

  var bPressedSlide: bool
    ## true when player is holding slide button

  var climbToMarker {.ue.}: ptr UStaticMeshComponent
  var climbToMarkerLocation: FVector

  var timerHandle_ClimbOverObstacle: FTimerHandle
    ## Handle for efficient management of ClimbOverObstacle timer
  var timerHandle_ResumeMovement: FTimerHandle
    ## Handle for efficient management of ResumeMovement timer

  proc initObjInitializer*(objInitializer: var FObjectInitializer): ptr FObjectInitializer {.objInitializer.} =
    let moveCompName = ACharacter.characterMovementComponentName
    objInitializer.setDefaultSubobjectClass(UPlatformerPlayerMovementComp, moveCompName)
    result = addr objInitializer

  proc init() {.constructor, callSuper.} =
    minSpeedForHittingWall = 200.0
    this.getMesh().meshComponentUpdateFlag = EMeshComponentUpdateFlag.AlwaysTickPoseAndRefreshBones

  method postInitializeComponents*() {.override, callSuper.} =
    ## player pawn initialization
    this.setActorRotation(rot(0.0'f32, 0.0'f32, 0.0'f32))

  method tick*(deltaSeconds: float32) {.override, callSuperAfter.} =
    ## perform position adjustments
    if not animPositionAdjustment.isNearlyZero():
      animPositionAdjustment = vInterpConstantTo(animPositionAdjustment, zeroVector, deltaSeconds, 400.0)
      this.getMesh().setRelativeLocation(this.getBaseTranslationOffset() + animPositionAdjustment)

    if climbToMarker != nil:
      let adjustDelta = climbToMarker.getComponentLocation() - climbToMarkerLocation
      if not adjustDelta.isZero():
        this.setActorLocation(this.getActorLocation + adjustDelta, false)
        climbToMarkerLocation += adjustDelta

  method setupPlayerInputComponent*(inputComponent: ptr UInputComponent) {.override, callSuper.} =
    ## setup input bindings
    inputComponent.bindAction("Jump", IE_Pressed, this, onStartJump)
    inputComponent.bindAction("Jump", IE_Released, this, onStopJump)
    inputComponent.bindAction("Slide", IE_Pressed, this, onStartSlide)
    inputComponent.bindAction("Slide", IE_Released, this, onStopSlide)

  method checkJumpInput*(deltaTime: cfloat) {.override.} =
    ## used to make pawn jump ; overridden to handle additional jump input functionality
    if this.bPressedJump:
      let moveComp = ueCast[UPlatformerPlayerMovementComp](this.getCharacterMovement())
      if moveComp != nil and moveComp.isSliding():
        moveComp.tryToEndSlide()
        return

    invokeSuper(APlatformerCharacterBase, checkJumpInput, deltaTime)

  method moveBlockedBy*(impact: FHitResult) {.override.} =
    ## notify from movement about hitting an obstacle while running
    let forwardDot = impact.normal | forwardVector
    let movementMode = this.getCharacterMovement().movementMode
    if movementMode != MOVE_None:
      ueLog("Collision with $#, normal=$#, dot=$#, $#" %
            [$getNameSafe(impact.actor.get()),
             $impact.normal, $forwardDot, $this.getCharacterMovement().getMovementName()])

    if movementMode == MOVE_Walking and forwardDot < -0.9'f32:
      let movement: ptr UPlatformerPlayerMovementComp = ueCast[UPlatformerPlayerMovementComp](this.getCharacterMovement())
      let speed = abs(movement.velocity | forwardVector)
        ## if running or sliding: play bump reaction and jump over obstacle

      var duration = 0.01'f32
      if speed > minSpeedForHittingWall:
        duration = this.playAnimMontage(hitWallMontage)
      let timerManager = this.getWorldTimerManager()
      timerManager.setTimer(timerHandle_climbOverObstacle, this, climbOverObstacle, duration, false)
      movement.pauseMovementForObstacleHit()
    elif movementMode == MOVE_Falling:
      let marker = ueCast[APlatformerClimbMarker](impact.actor.get())
      if marker != nil:
        climbToLedge(marker)
        let movementComp = ueCast[UPlatformerPlayerMovementComp](this.getCharacterMovement())
        movementComp.pauseMovementForLedgeGrab()

  method landed*(hit: FHitResult) {.override, callSuper.} =
    ## play end of round if game has finished with character in mid air
    let game = getGameMode(this.getWorld())
    if game != nil and game.getGameState() == EGameState.Finished:
      playRoundFinished()

  proc onRoundFinished*() =
    ## try playing end of round animation
    if this.getCharacterMovement().movementMode != MOVE_Falling:
      playRoundFinished()

  proc onRoundReset*() =
    ## stop any active animations, reset movement state
    if this.getMesh() != nil and this.getMesh().animScriptInstance != nil:
      this.getMesh().animScriptInstance.montage_Stop(0.0)
    this.getCharacterMovement().stopMovementImmediately()
    this.getCharacterMovement().setMovementMode(MOVE_Walking)

    this.bPressedJump = false
    bPressedSlide = false

  proc isSliding*(): bool {.bpCallable, category: "Pawn|Character", thisConst.} =
    ## returns true when pawn is sliding ; used in AnimBlueprint
    let moveComp = ueCast[UPlatformerPlayerMovementComp](this.getCharacterMovement())
    result = moveComp != nil and moveComp.isSliding()

  proc wantsToSlide*(): bool {.override, thisConst.} =
    ## gets bPressedSlide value
    result = bPressedSlide

  proc canHandleMovement(pc: ptr APlatformerPlayerController): bool =
    let game = getGameMode(this.getWorld())
    if pc.tryStartingGame(): return false
    result = (not pc.isMoveInputIgnored and game != nil and game.isRoundInProgress())

  proc onStartJump*() =
    ## event called when player presses jump button
    let pc = ueCast[APlatformerPlayerController](this.controller)
    if canHandleMovement(pc):
      this.bPressedJump = true

  proc onStopJump*() =
    ## event called when player releases jump button
    this.bPressedJump = false

  proc onStartSlide*() =
    ## event called when player presses slide button
    let pc = ueCast[APlatformerPlayerController](this.controller)
    if canHandleMovement(pc):
      bPressedSlide = true

  proc onStopSlide*() =
    ## event called when player releases slide button
    bPressedSlide = false

  method playSlideStarted*() {.override.} =
    ## handle effects when slide starts
    if slideSound != nil:
      slideAC = spawnSoundAttached(slideSound, this.getMesh())

  method playSlideFinished*() {.override.} =
    ## handle effects when slide is finished
    if slideAC != nil:
      slideAC.stop()
      slideAC = nil

  method getCameraHeightChangeThreshold*(): float32 {.override, thisConst.}=
    ## gets CameraHeightChangeThreshold value
    result = cameraHeightChangeThreshold

  proc climbOverObstacle() =
    ## determine obstacle height type and play animation

    # climbing over obstacle:
    # - there are three animations matching with three types of predefined obstacle heights
    # - pawn is moved using root motion, ending up on top of obstacle as animation ends

    let forwardDir = this.getActorForwardVector()
    let traceStart = this.getActorLocation() + forwardDir * 150.0 +
                     vec(0.0, 0.0, 0.1) * this.getCapsuleComponent().getScaledCapsuleHalfHeight() + 150.0
    let traceEnd = traceStart + vec(0.0, 0.0, -1.0) * 500.0

    let traceParams = initFCollisionQueryParams(NAME_None, true)
    var hit: FHitResult
    discard this.getWorld().lineTraceSingleByChannel(hit, traceStart, traceEnd, ECC_Pawn, traceParams)

    if hit.bBlockingHit:
      let destPosition = hit.impactPoint + vec(0.0, 0.0, this.getCapsuleComponent().getScaledCapsuleHalfHeight())
      let zDiff = destPosition.z - this.getActorLocation().z
      ueLog("Climb over obstacle, Z difference: $# ($#)" %
            [$zDiff, if zDiff < climbOverMidHeight: "small" elif zDiff < climbOverBigHeight: "mid" else: "big"])
      let montage = if zDiff < climbOverMidHeight: climbOverSmallMontage
                    elif zDiff < climbOverBigHeight: climbOverMidMontage
                    else: climbOverBigMontage
      this.getCharacterMovement().setMovementMode(MOVE_Flying)
      this.setActorEnableCollision(false)
      let duration = this.playAnimMontage(montage)
      let timerManager = this.getWorldTimerManager()
      let rate = duration - 0.1
      timerManager.setTimer(timerHandle_ResumeMovement, this, resumeMovement, rate, false)
    else:
      resumeMovement()

  proc climbToLedge(moveToMarker: ptr APlatformerClimbMarker) =
    ## position pawn on ledge and play animation with position adjustment
    climbToMarker = if moveToMarker != nil: findComponentByClass[UStaticMeshComponent](moveToMarker) else: nil
    climbToMarkerLocation = if climbToMarker != nil: climbToMarker.getComponentLocation() else: zeroVector

    let markerBox = moveToMarker.getMesh().bounds.getBox()
    let desiredPosition = vec(markerBox.min.x, this.getActorLocation().y, markerBox.max.z)

    let startPosition = this.getActorLocation()
    var adjustedPosition = desiredPosition
    adjustedPosition.x += climbLedgeGrabOffsetX * this.getMesh().relativeScale3D.x - this.getBaseTranslationOffset().x
    adjustedPosition.z += this.getCapsuleComponent().getScaledCapsuleHalfHeight()

    discard this.teleportTo(adjustedPosition, this.getActorRotation(), false, true)

    animPositionAdjustment = startPosition - (this.getActorLocation() - (climbLedgeRootOffset * this.getMesh().relativeScale3D))
    this.getMesh().setRelativeLocation(this.getBaseTranslationOffset() + animPositionAdjustment)

    let duration = this.playAnimMontage(climbLedgeMontage)
    let timerManager = this.getWorldTimerManager()
    let rate = duration - 0.1
    timerManager.setTimer(timerHandle_ResumeMovement, this, resumeMovement, rate, false)

  proc resumeMovement() =
    ## restore pawn's movement state
    this.setActorEnableCollision(true)

    # restore movement state and saved speed
    let movement = ueCast[UPlatformerPlayerMovementComp](this.getCharacterMovement())
    movement.restoreMovement()

    climbToMarker = nil

  proc playRoundFinished() =
    ## play end of round animation
    let game = getGameMode(this.getWorld())
    let bWon = game != nil and game.isRoundWon()

    this.playAnimMontage(if bWon: wonMontage else: lostMontage)

    this.getCharacterMovement().stopMovementImmediately()
    this.getCharacterMovement().disableMovement()
