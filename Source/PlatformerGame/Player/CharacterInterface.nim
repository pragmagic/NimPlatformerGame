import ue4

uclass(APlatformerCharacterBase of ACharacter, Abstract):
  method getCameraHeightChangeThreshold*(): cfloat {.thisConst.} =
    discard

  method wantsToSlide*(): bool {.thisConst.} =
    discard

  method playSlideStarted*() =
    discard

  method playSlideFinished*() =
    discard
