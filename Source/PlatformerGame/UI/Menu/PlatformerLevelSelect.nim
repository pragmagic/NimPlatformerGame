import ue4, ue4gamemenubuilder
import lib/clibpp

wclass(IPlatformerGameLoadingScreenModule, header: "PlatformerGameLoadingScreen.h"):
  proc startInGameLoadingScreen()

class FPlatformerLevelSelect of FGameMenuPage:
  proc makeMenu*(pcOwner: TWeakObjectPtr[APlayerController]) =
    this.pcOwner = pcOwner
    this.menuTitle = nsLocText("PlatformerGame.HUD.Menu", "LevelSelect", "SELECT LEVEL")

    let streetsTitle = nsLocText("PlatformerGame.HUD.Menu", "Streets", "STREETS")
    discard this.addMenuItem(streetsTitle, this, onUIPlayStreets)
    let backTitle = nsLocText("PlatformerGame.HUD.Menu", "Back", "BACK")
    discard this.addMenuItem(backTitle, this, goBack)

  proc onUIPlayStreets() =
    if gEngine != nil:
      this.setOnHiddenHandler(this, onMenuHidden)
      this.hideMenu()

  proc goBack() =
    this.rootMenuPageWidget.get().menuGoBack(false)

  proc showLoadingScreen() =
    let loadingScreenModule = loadModulePtr[IPlatformerGameLoadingScreenModule](u16"PlatformerGameLoadingScreen")
    if loadingScreenModule != nil:
      loadingScreenModule.startInGameLoadingScreen()

  proc onMenuHidden() =
    this.destroyRootMenu()
    gEngine.setClientTravel(this.pcOwner.get().getWorld(), u16"/Game/Maps/Platformer_StreetSection", TRAVEL_Absolute)
    getFSlateApplication().setAllUserFocusToGameViewport()
    showLoadingScreen()
