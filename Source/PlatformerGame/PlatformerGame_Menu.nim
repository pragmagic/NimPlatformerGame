import ue4

import Player.PlatformerPlayerController_Menu

uclass APlatformerGame_Menu of AGameMode:
  proc init() {.constructor.} =
    this.playerControllerClass = APlatformerPlayerController_Menu.staticClass()

  method restartPlayer*(newPlayer: ptr AController) {.override.} =
    # don't restart
    discard
