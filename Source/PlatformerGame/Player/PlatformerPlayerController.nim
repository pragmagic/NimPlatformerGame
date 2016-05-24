import ue4

import GameModeInterface, PlatformerPlayerCameraManager
import UI.Menu.PlatformerIngameMenu

uclass APlatformerPlayerController of APlayerController:
  var platformerInGameMenu: TSharedPtr[FPlatformerIngameMenu]

  proc init() {.constructor, callSuper.} =
    this.playerCameraManagerClass = APlatformerPlayerCameraManager.staticClass()
    this.bEnableClickEvents = true
    this.bEnableTouchEvents = true

  method setupInputComponent*() {.override, callSuper.} =
    this.inputComponent.bindAction("InGameMenu", IE_Pressed, this, onToggleInGameMenu)

  method postInitializeComponents*() {.override, callSuper.} =
    # Build menu only after game is initialized
    # @note Initialize in FPlatformerGameModule::StartupModule is not enough - it won't execute in cooked game
    discard getIGameMenuBuilderModule()
    this.platformerInGameMenu = makeShareable(cnew[FPlatformerIngameMenu]())
    this.platformerInGameMenu.makeMenu(this)

  proc tryStartingGame*(): bool {.bpCallable, category: "Game".} =
    ## try starting game
    let game = getGameMode(this.getWorld())
    if game != nil:
      case game.getGameState():
      of EGameState.Waiting:
        game.startRound()
        result = true
      of EGameState.Finished:
        game.tryRestartRound()
        result = true
      else:
        discard

  proc onToggleInGameMenu() =
    ## toggle InGameMenu
    let game = getGameMode(this.getWorld())
    if platformerIngameMenu != nil and game != nil and
       game.getGameState() != EGameState.Finished:
      platformerIngameMenu.toggleGameMenu()
