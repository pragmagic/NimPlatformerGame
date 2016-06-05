import ue4
import math

import PlatformerGameMode, UI.PlatformerHUD
import UI.Widgets.PlatformerPicture

uclass UPlatformerBlueprintLibrary of UBlueprintFunctionLibrary:
  UFunction(BlueprintCallable, Category=Game, meta=(WorldContext="WorldContextObject")):
    proc prepareRace*(worldContextObject: ptr UObject) {.isStatic.} =
      ## switch to waiting state, player will be able to start race by himself
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        game.prepareRound()

    proc finishRace*(worldContextObject: ptr UObject): bool {.isStatic.} =
      ## finish round, player will be able to replay, returns true when scoring new record
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        game.finishRound()
        result = game.isRoundWon()

    proc allowToRestartRace*(worldContextObject: ptr UObject) {.isStatic.} =
      ## allow player to restart round
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        game.setCanBeRestarted(true)

    proc decreaseRoundDuration*(worldContextObject: ptr UObject, deltaTime: float32) {.isStatic.} =
      ## allows changing round duration, while round is still in progress - used to give players time bonuses
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        let delta = abs(deltaTime)
        game.modifyRoundDuration(delta, deltaTime <= 0)

    proc markCheckpointTime*(worldContextObject: ptr UObject, checkpointID: int32): float32 {.isStatic.} =
      ## returns delta between current checkpoint time and best (negative = better time)
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        let prevBestTime = game.getBestCheckpointTime(checkpointID)
        game.saveCheckpointTime(checkpointID)
        if prevBestTime > 0:
          let currentTime = game.getCurrentCheckpointTime(checkpointID)
          result = currentTime - prevBestTime

  UFunction(BlueprintPure, Category=Game, meta=(WorldContext="WorldContextObject")):
    proc getCurrentCheckpointTime*(worldContextObject: ptr UObject, checkpointID: int32): float32 {.isStatic.} =
      ## returns checkpoint time saved in current round
      let game = getGameFromCtx(worldContextObject)
      result = -1.0
      if game != nil:
        result = game.getCurrentCheckpointTime(checkpointID)

    proc getBestCheckpointTime*(worldContextObject: ptr UObject, checkpointID: int32): float32 {.isStatic.} =
      ## returns best time on given checkpoint
      let game = getGameFromCtx(worldContextObject)
      result = -1.0
      if game != nil:
        result = game.getBestCheckpointTime(checkpointID)

    proc getLastCheckpoint*(worldContextObject: ptr UObject): int32 {.isStatic.} =
      ## returns index of last saved checkpoint
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        result = game.getNumCheckpoints() - 1

  UFunction(BlueprintCallable, Category=HUD, meta=(WorldContext="WorldContextObject")):
    proc displayMessage*(worldContextObject: ptr UObject, message: FString, displayDuration: float32 = 1.0'f32,
                        posX, posY: float32 = 0.5'f32; textScale: float32 = 1.0'f32; bRedBorder: bool  = false) {.isStatic.} =
      let myHUD = getHUDFromCtx(worldContextObject)
      if myHUD != nil:
        myHUD.addMessage(message, displayDuration, posX, posY, textScale / 4.0, bRedBorder)

    proc showPicture*(worldContextObject: ptr UObject, picture: ptr UTexture2D, fadeInTime: float32 = 0.3'f32,
                      screenCoverage: float32 = 1.0'f32, bKeepAspectRatio: bool = false) {.isStatic.} =
      ## displays specified texture covering entire screen
      let game = getGameFromCtx(worldContextObject)
      if game != nil:
        if game.platformerPicture == nil:
          game.platformerPicture = cnew[FPlatformerPicture](game.getWorld())
        game.platformerPicture.show(picture, fadeInTime, screenCoverage, bKeepAspectRatio)

    proc hidePicture*(worldContextObject: ptr UObject, fadeOutTime: float32 = 0.3'f32) {.isStatic.} =
      ## hides previously displayed picture
      let game = getGameFromCtx(worldContextObject)
      if game != nil and game.platformerPicture != nil:
        game.platformerPicture.hide(fadeOutTime)

    proc showHighscore*(worldContextObject: ptr UObject, times: TArray[float32], names: TArray[FString]) {.isStatic.} =
      ## shows highscore with provided data
      let myHUD = getHUDFromCtx(worldContextObject)
      if myHUD != nil:
        myHUD.showHighscore(times, names)

    proc hideHighscore*(worldContextObject: ptr UObject) {.isStatic.} =
      ## hides the highscore
      let myHUD = getHUDFromCtx(worldContextObject)
      if myHUD != nil:
        myHUD.hideHighscore()

    proc showHighscorePrompt*(worldContextObject: ptr UObject) {.isStatic.} =
      ## shows highscore prompt, calls HighscoreNameAccepted when user is done
      let myHUD = getHUDFromCtx(worldContextObject)
      if myHUD != nil:
        myHUD.showHighscorePrompt()

  UFunction(BlueprintPure, Category=HUD):
    proc describeTime*(timeSeconds: float32, bShowSign: bool = true): FString {.isStatic.} =
      ## converts time to string in mm:ss.sss format
      result = timeToStr(timeSeconds, bShowSign)

  proc sortHighscores*(inTimes: TArray[float32], inNames: TArray[FString], outTimes: var TArray[float32],
                       outNames: var TArray[FString], maxScores: int32) {.isStatic, bpCallable, category: "Game".} =
    for i in 0..<inTimes.len:
      for j in i..<inTimes.len:
        if inTimes[i] > inTimes[j]:
          inTimes.swap(i, j)
          inNames.swap(i, j)
    outTimes = inTimes
    outNames = inNames

    outTimes.del(maxScores, outTimes.len - 1)
    outNames.del(maxScores, outNames.len - 1)
