import ue4

import UI.Widgets.PlatformerPicture

uenum EGameState:
  Intro
  Waiting
  Playing
  Finished
  Restarting

uinterface IPlatformerGameModeInterface:
  method prepareRound*(bRestarting: bool = false)
    ## prepare game state and show HUD message

  method startRound*()
    ## used to start this round

  method finishRound*()
    ## finish current round

  method isGamePaused*(): bool {.noSideEffect.}
    ## is game paused?

  method setGamePaused*(bIsPaused: bool)
    ## pauses/unpauses the game

  method setCanBeRestarted*(bAllowRestart: bool)
    ## sets if round can be restarted

  method canBeRestarted*(): bool {.noSideEffect.}
    ## returns if round can be restarted

  method tryRestartRound*()
    ## tries to restart round

  method saveCheckpointTime*(checkpointID: int32)
    ## save current time for checkpoint

  method getCurrentCheckpointTime*(checkpointID: int32): float32 {.noSideEffect.}
    ## get checkpoint time: current round

  method getBestCheckpointTime*(checkpointID: int32): float32 {.noSideEffect.}
    ## get checkpoint time: best

  method getNumCheckpoints*(): int32 {.noSideEffect.}
    ## get number of checkpoints

  method getRoundDuration*(): float32 {.noSideEffect.}
    ## returns time that passed since round has started (in seconds)
    ## if the round has already ended returns round duration

  method modifyRoundDuration*(deltaTime: float32, bIncrease: bool)
    ## increases/decreases round duration by DeltaTime

  method isRoundInProgress*(): bool {.noSideEffect.}
    ## returns true if round is in progress - player is still moving

  method isRoundWon*(): bool {.noSideEffect.}
    ## returns true if round was won (best time)

  method getGameState*(): EGameState {.noSideEffect.}
    ## get current state of game

  method getPlatformerPicture*(): ptr FPlatformerPicture

var getGameMode*: proc(world: ptr UWorld): ptr IPlatformerGameModeInterface = nil
