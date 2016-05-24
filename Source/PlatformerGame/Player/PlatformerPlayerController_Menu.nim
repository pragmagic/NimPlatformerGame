import ue4

import UI.Menu.PlatformerMainMenu

uclass APlatformerPlayerController_Menu of APlayerController:
  var platformerMainMenu: TSharedPtr[FPlatformerMainMenu]

  method postInitializeComponents*() {.override, callSuper.} =
    ## After game is initialized
    platformerMainMenu = makeShareable(cnew[FPlatformerMainMenu]())
    platformerMainMenu.makeMenu(this)
    platformerMainMenu.get().showRootMenu()

  method endPlay*(endPlayReason: EEndPlayReason) {.override.} =
    platformerMainMenu.reset()
