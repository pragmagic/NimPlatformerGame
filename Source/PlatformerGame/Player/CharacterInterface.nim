import ue4

uclass(APlatformerCharacterBase of ACharacter, Abstract):
  method getCameraHeightChangeThreshold*(): cfloat =
    discard

  method wantsToSlide*(): bool =
    discard

  method playSlideStarted*() =
    discard

  method playSlideFinished*() =
    discard
