import ue4

import math

import PlatformerGameUserSettings

udelegate(FOnOptionsClosing, dkSimple)

let platformerResolutions = [initFIntPoint(800,600), initFIntPoint(1024,768), initFIntPoint(1280,720), initFIntPoint(1920,1080)]

class FPlatformerOptions of FGameMenuPage:
  var soundVolumeOption*: TSharedPtr[FGameMenuItem]
    ## holds volume option menu item
  var videoResolutionOption*: TSharedPtr[FGameMenuItem]
    ## holds video resolution menu item
  var fullScreenOption*: TSharedPtr[FGameMenuItem]
    ## holds full screen option menu item
  var fullScreenOpt*: EWindowMode
    ## full screen setting set in options
  var resolutionOpt*: FIntPoint
    ## resolution setting set in options
  var soundVolumeOpt*: float32
    ## sound volume set in options
  var acceptChangesSound*: FSlateSound
    ## Sound to play when changes are accepted
  var discardChangesSound*: FSlateSound
    ## Sound to play when changes are discarded
  var userSettings*: TWeakObjectPtr[UPlatformerGameUserSettings]
    ## User settings pointer

  proc makeMenu*(pcOwner: TWeakObjectPtr[APlayerController]) =
    ## sets owning player controller
    this.pcOwner = pcOwner
    userSettings.set(nil)

    var resolutionList: TArray[FText]
    var onOffList: TArray[FText]
    var volumeList: TArray[FText]

    for resolution in platformerResolutions:
      resolutionList.add(($resolution.x & "x" & $resolution.y).toText())

    onOffList.add(nsLocText("PlatformerGame.HUD.Menu", "Off", "OFF"))
    onOffList.add(nsLocText("PlatformerGame.HUD.Menu", "On", "ON"))

    for i in 0..10:
      volumeList.add(i.toText())

    this.menuTitle = nsLocText("PlatformerGame.HUD.Menu", "Options", "OPTIONS")
    let soundVolumeTitle = nsLocText("PlatformerGame.HUD.Menu", "SoundVolume", "SOUND VOLUME")
    let resolutionTitle = nsLocText("PlatformerGame.HUD.Menu", "Resolution", "RESOLUTION")
    let fullScreenTitle = nsLocText("PlatformerGame.HUD.Menu", "FullScreen", "FULL SCREEN")
    soundVolumeOption = this.addMenuItemWithOptions(soundVolumeTitle, volumeList, this, soundVolumeOptionChanged)
    videoResolutionOption = this.addMenuItemWithOptions(resolutionTitle, resolutionList, this, videoResolutionOptionChanged)
    fullScreenOption = this.addMenuItemWithOptions(fullScreenTitle, onOffList, this, fullScreenOptionChanged)

    # setup some handlers for misc actions
    this.setAcceptHandler(this, applySettings)
    this.setCancelHandler(this, discardSettings)
    this.setOnOpenHandler(this, updateOptions)

    let acceptChangesText = nsLocText("PlatformerGame.HUD.Menu", "AcceptChanges", "ACCEPT CHANGES")
    let discardChangesText = nsLocText("PlatformerGame.HUD.Menu", "DiscardChanges", "DISCARD CHANGES")
    discard this.addMenuItem(acceptChangesText, this, onAcceptSettings)
    discard this.addMenuItem(discardChangesText, this, onDiscardSettings)

    userSettings = ueCast[UPlatformerGameUserSettings](gEngine.getGameUserSettings())
    soundVolumeOpt = userSettings.getSoundVolume()
    resolutionOpt = userSettings.get().getScreenResolution()
    fullScreenOpt = userSettings.get().getFullscreenMode()

  proc updateOptions*() =
    ## get current options values for display
    userSettings = ueCast[UPlatformerGameUserSettings](gEngine.getGameUserSettings())
    videoResolutionOption.get().selectedMultiChoice = getCurrentResolutionIndex(userSettings.get().getScreenResolution())
    fullScreenOption.get().selectedMultiChoice = if userSettings.get().getFullscreenMode() != EWindowMode.Windowed: 1 else: 0
    soundVolumeOption.get().selectedMultiChoice = toInt(trunc(userSettings.getSoundVolume() * 10.0'f32))

  proc applySettings*() =
    ## applies changes in game settings
    userSettings.get().setSoundVolume(soundVolumeOpt)
    userSettings.get().setScreenResolution(resolutionOpt)
    userSettings.get().setFullscreenMode(fullScreenOpt)
    userSettings.get().applySettings(false)

  proc discardSettings*() =
    ## discard changes and go back
    revertChanges()

  proc revertChanges*() =
    ## reverts non-saved changes in game settings
    updateOptions()

  proc onAcceptSettings*() =
    this.rootMenuPageWidget.get().menuGoBack(false)

  proc onDiscardSettings*() =
    this.rootMenuPageWidget.get().menuGoBack(true)

  proc videoResolutionOptionChanged*(menuItem: TSharedPtr[FGameMenuItem], multiOptionIndex: int32) =
    ## video resolution option changed handler
    resolutionOpt = platformerResolutions[multiOptionIndex]

  proc fullScreenOptionChanged*(menuItem: TSharedPtr[FGameMenuItem], multiOptionIndex: int32) =
    ## full screen option changed handler
    let cvar = getConsoleManager().findTConsoleVariableDataInt(u16"r.FullScreenMode")
    let fullScreenMode = if cvar.getValueOnGameThread() == 1: EWindowMode.WindowedFullscreen else: EWindowMode.Fullscreen

    fullScreenOpt = if multiOptionIndex == 0: EWindowMode.Windowed else: fullScreenMode

  proc soundVolumeOptionChanged*(menuItem: TSharedPtr[FGameMenuItem], multiOptionIndex: int32) =
    ## sound volume option changed handler
    soundVolumeOpt = float32(multiOptionIndex) / 10.0'f32

  proc getCurrentResolutionIndex*(currentRes: FIntPoint): int32 =
    ## try to match current resolution with selected index
    for i, resolution in platformerResolutions.pairs():
      if platformerResolutions[i] == currentRes:
        result = i
        break
