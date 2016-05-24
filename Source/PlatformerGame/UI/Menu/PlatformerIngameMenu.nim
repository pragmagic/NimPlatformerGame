import ue4

import GameModeInterface, PlatformerOptions

class FPlatformerIngameMenu of FGameMenuPage:
  var gameMenuContainer*: TSharedPtr[SWeakWidget]
    ## game menu container widget - used for removing
  var bIsGameMenuUp*: bool
    ## if game menu is currently opened
  var bWasActorHidden*: bool
    ## Cached actor hidden state.

  proc makeMenu*(pcOwner: ptr APlayerController) =
    ## sets owning player controller
    if gEngine == nil or gEngine.gameViewport == nil:
      return
    bWasActorHidden = false
    let platformerOptions = makeShareable(cnew[FPlatformerOptions]())
    platformerOptions.makeMenu(pcOwner)
    platformerOptions.applySettings()

    if this.initialiseRootMenu(pcOwner, u16"/Game/UI/Styles/PlatformerMenuStyle", gEngine.gameViewport):
      let resumeGameTitle = nsLocText("PlatformerGame.HUD.Menu", "ResumeGame", "RESUME GAME")
      discard this.addMenuItem(resumeGameTitle, this, resumeGame)
      let optionsTitle = nsLocText("PlatformerGame.HUD.Menu", "Options", "OPTIONS")
      discard this.addMenuItem(optionsTitle, platformerOptions)
      let quitTitle = nsLocText("PlatformerGame.HUD.Menu", "Quit", "QUIT")
      discard this.addMenuItem(quitTitle, this, closeAndExit)

      bIsGameMenuUp = false
      this.setCancelHandler(this, resumeGame)

  proc toggleGameMenu*() =
    ## toggles in game menu
    if not this.rootMenuPageWidget.isValid() or bIsGameMenuUp or not this.pcOwner.isValid():
      return
    bIsGameMenuUp = true
    let game = getGameMode(this.pcOwner.get().getWorld())
    if game != nil:
      game.setGamePaused(true)
      bWasActorHidden = this.pcOwner.get().getPawn().bHidden

    this.showRootMenu()
    this.pcOwner.get().setCinematicMode(bIsGameMenuUp, false, false, true, true)

  proc getIsGameMenuUp*(): bool =
    ## is game menu currently active?
    result = bIsGameMenuUp

  proc resumeGame*() =
    if not bIsGameMenuUp:
      return

    bIsGameMenuUp = false

    # Start hiding animation
    this.rootMenuPageWidget.get().hideMenu()
    # enable player controls during hide animation
    getFSlateApplication().setAllUserFocusToGameViewport()
    this.pcOwner.get().setCinematicMode(false, false, false, true, true)

    # Leaving Cinematic mode will always unhide the player pawn,
    # we don't want this on the intro or when game is finished.
    let game = getGameMode(this.pcOwner.get().getWorld())
    if game != nil:
      game.setGamePaused(false)
      this.pcOwner.get().getPawn().setActorHiddenInGame(bWasActorHidden)

  proc returnToMainMenu*() =
    let pc = this.pcOwner.get()
    var remoteReturnReason = nsLocText("NetworkErrors", "HostHasLeft", "Host has left the game.").toString()
    var localReturnReason: FString = u16""
    if pc != nil:
      if pc.getNetMode < NM_Client:
        for controller in playerControllers(pc.getWorld()):
          if controller != nil and controller.isPrimaryPlayer() and controller != pc:
            controller.clientReturnToMainMenu(remoteReturnReason)
      pc.clientReturnToMainMenu(localReturnReason)

    this.destroyRootMenu()

  proc detachGameMenu*() =
    this.destroyRootMenu()

  proc closeAndExit*() =
    this.hideMenu()
    this.setOnHiddenHandler(this, returnToMainMenu)
