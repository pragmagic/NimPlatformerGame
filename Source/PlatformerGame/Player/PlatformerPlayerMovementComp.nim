import ue4

import CharacterInterface, GameModeInterface

uclass UPlatformerPlayerMovementComp of UCharacterMovementComponent:
  UProperty(EditDefaultsOnly, Category=Config):
    var modSpeedObstacleHit: float32
      ## speed multiplier after hiting an obstacle
    var modSpeedLedgeGrab: float32
      ## speed multiplier after ledge grab
    var slideVelocityReduction: float32
      ## value by which speed will be reduced during slide
    var minSlideSpeed: float32
      ## minimal speed pawn can slide with
    var maxSlideSpeed: float32
      ## maximal speed pawn can slide with
    var slideHeight: float32
      ## height of pawn while sliding

  var slideMeshRelativeLocationOffset: FVector
    ## offset value, by which relative location of pawn mesh needs to be changed, when pawn is sliding
  var currentSlideVelocityReduction: float32
    ## value by which sliding pawn speed is currently being reduced
  var savedSpeed: float32
    ## saved modified value of speed to restore after animation finish
  var bInSlide: bool
    ## true when pawn is sliding
  var bWantsSlideMeshRelativeLocationOffset: bool
    ## true if pawn needs to use SlideMeshRelativeLocationOffset while sliding

  proc init() {.constructor.} =
    this.maxAcceleration = 200.0
    this.brakingDecelerationWalking = this.maxAcceleration
    this.maxWalkSpeed = 900.0

    slideVelocityReduction = 30.0
    slideHeight = 60.0
    slideMeshRelativeLocationOffset = vec(0.0, 0.0, 34.0)
    bWantsSlideMeshRelativeLocationOffset = false
    minSlideSpeed = 200.0
    maxSlideSpeed = this.maxWalkSpeed + 200.0

    modSpeedObstacleHit = 0.0
    modSpeedLedgeGrab = 0.8

  method startFalling*(iterations: int32, remainingTime: float32, timeTick: float32,
                       delta: FVector, subLoc: FVector) {.override, callSuper.} =
    ## stop slide when falling
    if this.movementMode == MOVE_Falling and this.isSliding():
      tryToEndSlide()

  proc isSliding*(): bool =
    ## returns true when pawn is sliding
    result = bInSlide

  proc tryToEndSlide*() =
    ## attempts to end slide move - fails if collisions above pawn don't allow it
    if bInSlide:
      if restoreCollisionHeightAfterSlide():
        bInSlide = false
        let owner = ueCast[APlatformerCharacterBase](this.pawnOwner)
        if owner != nil:
          owner.playSlideFinished()

  proc pauseMovementForObstacleHit*() =
    ## stop movement and save current speed with obstacle modifier
    savedSpeed = this.velocity.size() * modSpeedObstacleHit

    this.stopMovementImmediately()
    this.disableMovement()
    this.tryToEndSlide()

  proc pauseMovementForLedgeGrab*() =
    ## stop movement and save current speed with ledge grab modifier
    savedSpeed = this.velocity.size() * modSpeedLedgeGrab

    this.stopMovementImmediately()
    this.disableMovement()
    this.tryToEndSlide()

  proc restoreMovement*() =
    ## restore movement and saved speed
    this.setMovementMode(MOVE_Walking)
    if savedSpeed > 0:
      this.velocity = this.pawnOwner.getActorForwardVector() * savedSpeed

  method physWalking*(deltaTime: float32, iterations: int32) {.override, callSuperAfter.} =
    ## update slide
    let pawn = ueCast[APlatformerCharacterBase](this.pawnOwner)
    if pawn != nil:
      let bWantsToSlide = pawn.wantsToSlide()
      if isSliding():
        calcCurrentSlideVelocityReduction(deltaTime)
        calcSlideVelocity(this.velocity)

        let currentSpeedSq = this.velocity.sizeSquared()
        if currentSpeedSq <= minSlideSpeed * minSlideSpeed:
          tryToEndSlide()
      elif bWantsToSlide:
        if not this.isFlying() and this.velocity.sizeSquared() > sqr(minSlideSpeed * 2.0):
          startSlide()

  method scaleInputAcceleration*(inputAcceleration: FVector): FVector {.override, thisConst.} =
    ## force movement
    var newAccel = inputAcceleration
    let game = getGameMode(this.getWorld())
    if game != nil and game.isRoundInProgress():
      newAccel.x = 1.0

    result = invokeSuperWithResult(FVector, UCharacterMovementComponent,
                                   scaleInputAcceleration, newAccel)

  proc calcSlideVelocity(outVelocity: var FVector) =
    ## calculates OutVelocity which is new velocity for pawn during slide
    let velocityDir = this.velocity.getSafeNormal()
    var newVelocity = this.velocity + currentSlideVelocityReduction * velocityDir

    let newSpeedSq = newVelocity.sizeSquared()
    if newSpeedSq > maxSlideSpeed * maxSlideSpeed:
      newVelocity = velocityDir * maxSlideSpeed
    elif newSpeedSq < sqr(minSlideSpeed):
      newVelocity = velocityDir * minSlideSpeed

    outVelocity = newVelocity

  proc calcCurrentSlideVelocityReduction(deltaTime: float32) =
    ## while pawn is sliding calculates new value of CurrentSlideVelocityReduction
    var reductionCoef = 0.0'f32
    let floorDotVelocity = this.currentFloor.hitResult.impactNormal | this.velocity.getSafeNormal()
    let bNeedsSlopeAdjustment = (floorDotVelocity != 0.0)

    if bNeedsSlopeAdjustment:
      let multiplier = 1.0'f32 + abs(floorDotVelocity)
      if floorDotVelocity > 0.0:
        reductionCoef += slideVelocityReduction * multiplier
      else:
        reductionCoef -= slideVelocityReduction * multiplier
    else:
      reductionCoef -= slideVelocityReduction

    let timeDilation = this.getWorld().getWorldSettings().getEffectiveTimeDilation()
    currentSlideVelocityReduction += (reductionCoef * timeDilation * deltaTime)

  proc startSlide() =
    ## forces pawn to start sliding
    if not bInSlide:
      bInSlide = true
      currentSlideVelocityReduction = 0.0'f32
      setSlideCollisionHeight()

      let owner = ueCast[APlatformerCharacterBase](this.pawnOwner)
      if owner != nil:
        owner.playSlideStarted()

  proc setSlideCollisionHeight() =
    ## changes pawn height to SlideHeight and adjusts pawn collisions
    if this.characterOwner == nil or slideHeight <= 0.0: return

    # Do not perform if collision is already at desired size.
    if this.characterOwner.getCapsuleComponent().getUnscaledCapsuleHalfHeight() == slideHeight:
      return

    # Change collision size to new value
    this.characterOwner.getCapsuleComponent().setCapsuleSize(
        this.characterOwner.getCapsuleComponent().getUnscaledCapsuleRadius(), slideHeight)

    # applying correction to PawnOwner mesh relative location
    if bWantsSlideMeshRelativeLocationOffset:
      let defCharacter = getDefaultObject[ACharacter](this.characterOwner.getClass())
      let correction = defCharacter.getMesh().relativeLocation + slideMeshRelativeLocationOffset
      this.characterOwner.getMesh().setRelativeLocation(correction)

  proc restoreCollisionHeightAfterSlide(): bool =
    ## restores pawn height to default after slide, if collisions above pawn allow that
    ## returns true if height change succeeded, false otherwise
    let characterOwner = ueCast[ACharacter](this.pawnOwner)
    if characterOwner == nil or this.updatedPrimitive == nil:
      return false

    let defCharacter = getDefaultObject[ACharacter](characterOwner.getClass())
    let defHalfHeight = defCharacter.getCapsuleComponent().getUnscaledCapsuleHalfHeight()
    let defRadius = defCharacter.getCapsuleComponent().getUnscaledCapsuleRadius()

    # Do not perform if collision is already at desired size.
    if characterOwner.getCapsuleComponent().getUnscaledCapsuleHalfHeight() == defHalfHeight:
      return true

    let heightAdjust = defHalfHeight - characterOwner.getCapsuleComponent().getUnscaledCapsuleHalfHeight()
    let newLocation = characterOwner.getActorLocation() + vec(0.0, 0.0, heightAdjust)

    # check if there is enough space for default capsule size
    var traceParams = initFCollisionQueryParams(u16"FinishSlide", false, characterOwner)
    var responseParam: FCollisionResponseParams
    this.initCollisionParams(traceParams, responseParam)

    let bBlocked = this.getWorld().overlapBlockingTestByChannel(
      newLocation, identityQuat, this.updatedPrimitive.getCollisionObjectType(),
      makeCapsuleCollisionShape(defRadius, defHalfHeight), traceParams)
    if bBlocked:
      return false

    # restore capsule size and move up to adjusted location
    discard characterOwner.teleportTo(newLocation, characterOwner.getActorRotation(), false, true)
    characterOwner.getCapsuleComponent().setCapsuleSize(defRadius, defHalfHeight)

    # restoring original PawnOwner mesh relative location
    if bWantsSlideMeshRelativeLocationOffset:
      characterOwner.getMesh().setRelativeLocation(defCharacter.getMesh().relativeLocation)

    return true
