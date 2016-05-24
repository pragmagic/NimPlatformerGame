import ue4

uclass UPlatformerGameUserSettings of UGameUserSettings:
  var soundVolume {.config.}: float32

  proc init() {.constructor.} =
    soundVolume = 1.0

  method applySettings*(bCheckForCommandLineOverrides: bool) {.override, callSuper.} =
    ## Applies all current user settings to the game and saves to permanent storage (e.g. file), optionally checking for command line overrides.
    if gEngine != nil and gEngine.getMainAudioDevice() != nil:
      gEngine.getMainAudioDevice().transientMasterVolume = soundVolume

  method isDirty*(): bool {.override, thisConst.} =
    ## Checks if any user settings is different from current
    result = invokeSuperWithResult(bool, UGameUserSettings, isDirty) or isSoundVolumeDirty()

  proc isSoundVolumeDirty*(): bool =
    ## Checks if the Inverted Mouse user setting is different from current
    if gEngine != nil and gEngine.getMainAudioDevice() != nil:
      let currentSoundVolume = gEngine.getMainAudioDevice().transientMasterVolume
      result = currentSoundVolume != this.getSoundVolume()

  proc getSoundVolume*(): float32 =
    result = soundVolume

  proc setSoundVolume*(inVolume: float32) =
    this.soundVolume = inVolume
