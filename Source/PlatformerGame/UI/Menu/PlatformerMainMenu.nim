import ue4

import PlatformerLevelSelect, PlatformerOptions

class FPlatformerMainMenu of FGameMenuPage:
  var platformerOptions: TSharedPtr[FPlatformerOptions]
    ## platformer options

  proc makeMenu*(inPCOwner: ptr APlayerController) =
    ## build menu
    let options = makeShareable(cnew[FPlatformerOptions]())
    options.get().makeMenu(inPCOwner)
    options.get().applySettings()

    let levelSelect = makeShareable(cnew[FPlatformerLevelSelect]())
    levelSelect.makeMenu(inPCOwner)

    if this.initialiserootMenu(inPCOwner, u16"/Game/UI/Styles/PlatformerMenuStyle", gEngine.gameViewport):
      this.menuTitle = nsLocText("PlatformerGame.HUD.Menu", "MainMenu", "MAIN MENU")

      let playGameTitle = nsLocText("PlatformerGame.HUD.Menu", "PlayGame", "PLAY GAME")
      let optionsTitle = nsLocText("PlatformerGame.HUD.Menu", "Options", "OPTIONS")
      let quitTitle = nsLocText("PlatformerGame.HUD.Menu", "Quit", "QUIT")
      discard this.addMenuItem(playGameTitle, levelSelect)
      discard this.addMenuItem(optionsTitle, options)
      discard this.addMenuItem(quitTitle, this, onQuit)

  proc onQuit*() =
    this.pcOwner.get().consoleCommand(u16"quit")
