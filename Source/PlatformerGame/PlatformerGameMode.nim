import ue4

import GameModeInterface
import Player.PlatformerPlayerController
import UI.Widgets.PlatformerPicture
import UI.PlatformerHUD
import Player.PlatformerCharacter

udelegate(FRoundFinishedDelegate, dkDynamicMulticast)

proc getPawn*(world: ptr UWorld): ptr APlatformerCharacter =
  let pc = ueCast[APlatformerPlayerController](gEngine.getFirstLocalPlayerController(world))
  result = if pc != nil: ueCast[APlatformerCharacter](pc.getPawn()) else: nil

proc getHUDFromCtx*(worldContextObject: ptr UObject): ptr APlatformerHUD =
  let world = gEngine.getWorldFromContextObject(worldContextObject)
  let localPC = gEngine.getFirstLocalPlayerController(world)
  result = if localPC != nil: ueCast[APlatformerHUD](localPC.getHUD()) else: nil

uclass APlatformerGameMode of (AGameMode, IPlatformerGameModeInterface):
  var platformerPicture*: ptr FPlatformerPicture
    ## full screen picture info
  var onRoundFinished* {.bpDelegate.}: FRoundFinishedDelegate
    ## delegate to broadcast about finished round

  var timerHandle_startRound: FTimerHandle
  var roundStartTime: float32
  var gameState: EGameState
  var bRoundWasWon: bool
  var bIsGamePaused: bool
  var bCanBeRestarted: bool
  var currentTimes: TArray[float32]
  var bestTimes: TArray[float32]

  proc init() {.constructor, callSuper.} =
    let pawnClass = ctorLoadClass(APawn, "/Game/Pawn/PlayerPawn")

    this.playerControllerClass = APlatformerPlayerController.staticClass()
    this.defaultPawnClass = pawnClass
    this.HUDClass = APlatformerHUD.staticClass()

    gameState = EGameState.Intro
    bRoundWasWon = false
    roundStartTime = 0.0
    bIsGamePaused = false

    if gEngine != nil and gEngine.gameViewport != nil:
      gEngine.gameViewport.setSuppressTransitionMessage(true)

  method prepareRound*(bRestarting: bool = false) {.override.} =
    ## prepare game state and show HUD message
    if bRestarting:
      onRoundFinished.broadcast()

    gameState = if bRestarting: EGameState.Restarting else: EGameState.Waiting
    bRoundWasWon = false
    roundStartTime = 0.0

    let pc = ueCast[APlatformerPlayerController](gEngine.getFirstLocalPlayerController(this.getWorld()))
    let pawn = getPawn(this.getWorld())
    if pawn != nil:
      pawn.onRoundReset()
      let startSpot = this.findPlayerStart(pc)
      discard pawn.teleportTo(startSpot.getActorLocation(), startSpot.getActorRotation())

      if pawn.bHidden:
        pawn.setActorHiddenInGame(false)

  method startRound*() {.override.} =
    ## used to start this round
    roundStartTime = this.getWorld().getTimeSeconds()
    gameState = EGameState.Playing

  method finishRound*() {.override.} =
    ## finish current round
    gameState = EGameState.Finished

    let lastCheckpointIdx = getNumCheckpoints() - 1
    let bestTime = getBestCheckpointTime(lastCheckpointIdx)
    bRoundWasWon = (bestTime < 0 or getRoundDuration() < bestTime)

    let pawn = getPawn(this.getWorld())
    if pawn != nil:
      pawn.onRoundFinished()

    while lastCheckpointIdx >= bestTimes.len:
      bestTimes.add(-1.0'f32)

    for i in 0..<bestTimes.len:
      if bestTimes[i] < 0 or bestTimes[i] > currentTimes[i]:
        bestTimes[i] = currentTimes[i]

  method isGamePaused*(): bool {.noSideEffect, override.} =
    ## is game paused?
    result = bIsGamePaused

  method setGamePaused*(bIsPaused: bool) {.override.} =
    ## pauses/unpauses the game
    let pc = gEngine.getFirstLocalPlayerController(this.getWorld())
    discard pc.setPause(bIsPaused)
    bIsGamePaused = bIsPaused

  method setCanBeRestarted*(bAllowRestart: bool) {.override.} =
    ## sets if round can be restarted
    if gameState == EGameState.Finished:
      bCanBeRestarted = bAllowRestart

  method canBeRestarted*(): bool {.noSideEffect, override.} =
    ## returns if round can be restarted
    result = (gameState == EGameState.Finished and bCanBeRestarted)

  method tryRestartRound*() {.override.} =
    ## tries to restart round
    if canBeRestarted():
      prepareRound(true)
      let timerManager = this.getWorldTimerManager()
      timerManager.setTimer(timerHandle_startRound, this, startRound, 2.0'f32, false)
      bCanBeRestarted = false

  method saveCheckpointTime*(checkpointID: int32) {.override.} =
    ## save current time for checkpoint
    while checkpointID >= currentTimes.len:
      currentTimes.add(-1.0)
    if checkpointID >= 0:
      currentTimes[checkpointID] = getRoundDuration()

  method getCurrentCheckpointTime*(checkpointID: int32): float32 {.noSideEffect, override.} =
    ## get checkpoint time: current round
    result = if currentTimes.isValidIndex(checkpointID): currentTimes[checkpointID] else: -1.0

  method getBestCheckpointTime*(checkpointID: int32): float32 {.noSideEffect, override.} =
    ## get checkpoint time: best
    result = if bestTimes.isValidIndex(checkpointID): bestTimes[checkpointID] else: -1.0

  method getNumCheckpoints*(): int32 {.noSideEffect, override.} =
    ## get number of checkpoints
    result = max(currentTimes.len(), bestTimes.len())

  method getRoundDuration*(): float32 {.override.} =
    ## returns time that passed since round has started (in seconds)
    ## if the round has already ended returns round duration
    if isRoundInProgress():
      let currTime = this.getWorld().getTimeSeconds()
      result = currTime - roundStartTime
    else:
      let lastCheckpoint = getNumCheckpoints() - 1
      result = getCurrentCheckpointTime(lastCheckpoint)

  method modifyRoundDuration*(deltaTime: float32, bIncrease: bool) {.override.} =
    ## increases/decreases round duration by DeltaTime
    if not isRoundInProgress(): return

    let prevRoundStartTime = roundStartTime

    let delta = abs(deltaTime)
    if bIncrease:
      roundStartTime -= delta
    else:
      let currTime = this.getWorld().getTimeSeconds()
      roundStartTime += delta
      roundStartTime = min(roundStartTime, currTime)

    let pc = gEngine.getFirstLocalPlayerController(this.getWorld())
    let hud = if pc != nil: ueCast[APlatformerHUD](pc.myHUD) else: nil
    if hud != nil:
      hud.notifyRoundTimeModified(prevRoundStartTime - roundStartTime)

  method isRoundInProgress*(): bool {.noSideEffect, override.} =
    ## returns true if round is in progress - player is still moving
    result = (gameState == EGameState.Playing)

  method isRoundWon*(): bool {.noSideEffect, override.} =
    ## returns true if round was won (best time)
    result = bRoundWasWon

  method getGameState*(): EGameState {.noSideEffect, override.} =
    ## get current state of game
    result = gameState

  method getPlatformerPicture*(): ptr FPlatformerPicture {.override.} =
    result = platformerPicture

proc getGameFromCtx*(worldContextObject: ptr UObject): ptr APlatformerGameMode =
  let world = gEngine.getWorldFromContextObject(worldContextObject)
  result = getAuthGameMode[APlatformerGameMode](world)

getGameMode = proc(world: ptr UWorld): ptr IPlatformerGameModeInterface =
  result = getAuthGameMode[APlatformerGameMode](world)
