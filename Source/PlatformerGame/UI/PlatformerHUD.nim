import ue4
import math

import GameModeInterface, Widgets.PlatformerPicture

udelegate(FOnHighscoreNameAccepted, dkDynamicMulticast, newHighscoreName: FString)

class FPlatformerMessageData:
  var message*: FString
    ## text to display
  var displayDuration*: cfloat
    ## how long this FMessageData will be displayed in seconds
  var displayStartTime*: cfloat
    ## TimeSeconds when this FMessageData was first shown
  var posX*: cfloat
    ## x axis position on screen <0, 1> (0 means left side of the screen) ; text will be centered
  var posY*: cfloat
    ## y axis position on screen <0, 1> (0 means top of the screen) ; text will be centered
  var textScale*: cfloat
    ## text scale
  var bRedBorder*: bool
    ## if red border should be drawn instead of blue

class FBorderTextures:
  var border*: ptr UTexture2D
  var background*: ptr UTexture2D
  var leftBorder*: ptr UTexture2D
  var rightBorder*: ptr UTexture2D
  var topBorder*: ptr UTexture2D
  var bottomBorder*: ptr UTexture2D

proc describeTime*(timeSeconds: float32, bShowSign: bool = true): FString =
  let absTimeSeconds = abs(timeSeconds)
  let isNegative = timeSeconds < 0

  let totalSeconds: int32 = toInt(trunc(absTimeSeconds)) mod 3600
  let numMinutes: int32 = totalSeconds div 60
  let numSeconds: int32 = totalSeconds mod 60

  let numMilliseconds = toInt(trunc((absTimeSeconds - trunc(absTimeSeconds)) * 1000.0))

  result = printfToFString(u16"%s%02d:%02d.%03d",
                            if bShowSign: (if isNegative: u16"-" else: u16"+") else: u16"",
                            numMinutes, numSeconds, numMilliseconds)

uclass APlatformerHUD of AHUD:
  var onHighscoreNameAccepted* {.bpDelegate.}: FOnHighscoreNameAccepted
    ## called when OK was hit while highscore name prompt was active
  var activeMessages: TArray[FPlatformerMessageData]
    ## array of messages that should be displayed on screen for a fixed time

  var endingMessages: TArray[FPlatformerMessageData]
    ## summary messages

  var roundTimeModification: cfloat
  var roundTimeModificationTime: cfloat

  var hudFont: ptr UFont
    ## roboto Light 48p font

  var blueBorder: FBorderTextures
    ## blue themed border textures

  var redBorder: FBorderTextures
    ## red themed border textures

  var upButtonTexture: ptr UTexture2D
    ## up button texture

  var downButtonTexture: ptr UTexture2D
    ## down button texture

  var screenRes: FIntPoint
    ## screen resolution

  var uiScale: float32
    ## current UI scale

  var highScoreName: TArray[char]
    ## current highscore name

  var currentLetter: uint8
    ## current letter to change while entering highscore name

  var bEnterNamePromptActive: bool
    ## if we should show enter name prompt

  var bHighscoreActive: bool
    ## if highscore is currently displayed

  var highscoreTimes: TArray[float32]
    ## highscore times

  var highscoreNames: TArray[FString]
    ## highscore names

  proc init() {.constructor.} =
    hudFont = ctorLoadObject(UFont, "/Game/UI/HUD/RobotoLight48")

    upButtonTexture = ctorLoadObject(UTexture2D, "/Game/UI/HUD/UpButton")
    downButtonTexture = ctorLoadObject(UTexture2D, "/Game/UI/HUD/DownButton")

    blueBorder.background = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/Background")
    blueBorder.border = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/Border")
    blueBorder.bottomBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderBottom")
    blueBorder.topBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderTop")
    blueBorder.leftBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderLeft")
    blueBorder.rightBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderRight")

    redBorder.background = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BackgroundRed")
    redBorder.border = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderRed")
    redBorder.bottomBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderBottomRed")
    redBorder.topBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderTopRed")
    redBorder.leftBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderLeftRed")
    redBorder.rightBorder = ctorLoadObject(UTexture2D, "/Game/UI/HUD/Frame/BorderRightRed")

    highScoreName.fill('A', 3)
    currentLetter = 0
    bEnterNamePromptActive = false
    bHighscoreActive = false

    highscoreNames.fill("TST".toFString(), 10)
    highscoreTimes.fill(60.0, 10)

  method drawHUD*() {.override, callSuper.} =
    if gEngine != nil and gEngine.gameViewport != nil:
      var viewportSize: FVector2D
      gEngine.gameViewport.getViewportSize(viewportSize)
      uiScale = viewportSize.x / 2048.0'f32

    invokeSuper(AHUD, drawHUD)

    let game = getGameMode(this.getWorld())
    if game != nil:
      drawActiveMessages()
      let gameState = game.getGameState()
      let platformerPicture = game.getPlatformerPicture()
      if gameState == EGameState.Playing:
        displayRoundTimer()
        displayRoundTimeModification()
      elif gameState == EGameState.Finished and
           platformerPicture != nil and platformerPicture.isVisible():
        let sizeX = this.canvas.clipX * 0.75'f32
        let sizeY = this.canvas.clipY * 0.7'f32
        let drawX = (this.canvas.clipX - sizeX) / 2.0'f32
        let drawY = (this.canvas.clipY - sizeY) / 2.0'f32

        if game.isRoundWon():
          drawBorder(drawX, drawY, sizeX, sizeY, 1.0'f32, this.blueBorder)
        else:
          drawBorder(drawX, drawY, sizeX, sizeY, 1.0'f32, this.redBorder)

        platformerPicture.tick(this.canvas)

        if endingMessages.len > 0:
          let endingMessagesScale = 1.6'f32
          let textMargin = 0.03'f32
          var strSizeX, strSizeY: float32
          this.canvas.strLen(hudFont, endingMessages[0].message, strSizeX, strSizeY)
          strSizeX = strSizeX * endingMessagesScale * uiScale
          strSizeY = strSizeY * endingMessagesScale * uiScale

          var textItem = initFCanvasTextItem(
            initFVector2D((this.canvas.clipX - strSizeX) / 2.0'f32, drawY + sizeY * textMargin),
            endingMessages[0].message.toText(), hudFont, whiteLinearColor)
          textItem.scale = initFVector2D(endingMessagesScale * uiScale, endingMessagesScale * uiScale)
          textItem.enableShadow(transparentLinearColor)
          this.canvas.drawItem(textItem)

          if endingMessages.len > 1:
            this.canvas.strLen(hudFont, endingMessages[1].message, strSizeX, strSizeY)
            strSizeX = strSizeX * endingMessagesScale * uiScale
            strSizeY = strSizeY * endingMessagesScale * uiScale
            textItem.position = initFVector2D(
              (this.canvas.clipX - strSizeX) / 2.0'f32,
              drawY + sizeY * (1.0'f32 - textMargin) - strSizeY)
            textItem.text = endingMessages[1].message.toText()
            this.canvas.drawItem(textItem)

      if gameState == EGameState.Waiting or game.canBeRestarted():
        let gameTime = round(trunc(1.0'f32 * this.getWorld().getTimeSeconds()))
        let bShowInputMessage = (gameTime mod 2 == 0)
        if bShowInputMessage:
          var inputMessage: FString = u16"Jump or Slide"
          case gameState:
          of EGameState.Waiting: inputMessage.add(u16" to start running")
          of EGameState.Finished: inputMessage.add(u16" to play again")
          else: discard

          drawMessage(inputMessage, 0.5'f32, 0.9'f32, 1.0'f32, whiteLinearColor)

      if gameState == EGameState.Finished:
        if bEnterNamePromptActive:
          drawHighscoreEntryPrompt()
        if bHighscoreActive:
          drawHighscore()

  proc addMessage*(message: FString, displayDuration: cfloat = 1.0, posX, posY: cfloat = 0.5,
                   textScale: cfloat = 1.0, bRedBorder: bool = false) =
    ## used to add new message to ActiveMessages array
    let game = getGameMode(this.getWorld())
    if game != nil:
      var msgData: FPlatformerMessageData
      msgData.message = message
      msgData.displayDuration = displayDuration
      msgData.displayStartTime = this.getWorld().getTimeSeconds()
      msgData.posX = posX
      msgData.posY = posY
      msgData.textScale = textScale
      msgData.bRedBorder = bRedBorder

      let gameState = game.getGameState()

      if gameState == EGameState.Finished:
        endingMessages.add(msgData)
      else:
        if endingMessages.len > 0:
          endingMessages.clear()
        activeMessages.add(msgData)

  proc notifyRoundTimeModified*(deltaTime: cfloat) =
    roundTimeModification = deltaTime
    roundTimeModificationTime = this.getWorld().getTimeSeconds()

  method notifyHitBoxClick*(boxName: bycopy FName) {.override, callSuper.} =
    ## Called when a hit box is clicked on. Provides the name associated with that box.
    if boxName.getPlainNameString() == "Letter":
      currentLetter = uint8(boxName.getNumber())
    if boxName == "Up" and highScoreName[currentLetter] < 'Z':
      inc highScoreName[currentLetter]
    if boxName == "Down" and highScoreName[currentLetter] > 'A':
      dec highScoreName[currentLetter]
    if boxName == "OK":
      bEnterNamePromptActive = false
      if this.playerOwner != nil:
        this.playerOwner.bShowMouseCursor = false
      var enteredName: FString
      for c in highScoreName:
        enteredName.add(toWchar(c))

      onHighscoreNameAccepted.broadcast(enteredName)

  proc showHighscore*(times: TArray[cfloat], names: TArray[FString]) =
    ## sets the data and shows the highscore
    highscoreNames = names
    highscoreTimes = times
    bHighscoreActive = true

  proc hideHighscore*() =
    ## hides highscore
    bHighscoreActive = false

  proc showHighscorePrompt*() =
    ## shows highscore prompt, calls HighscoreNameAccepted blueprint implementable event when user is done
    bEnterNamePromptActive = true
    if this.playerOwner != nil:
      this.playerOwner.bShowMouseCursor = bEnterNamePromptActive

  proc displayRoundTimer*() =
    ## used to display main game timer - top middle of the screen
    let game = getGameMode(this.getWorld())
    if game != nil:
      let roundDuration = game.getRoundDuration()
      let roundDurationText = u16"Time: " & describeTime(roundDuration, bShowSign = false)
      drawMessage(roundDurationText, 0.5'f32, 0.1'f32, 1.0'f32, whiteLinearColor)

  proc displayRoundTimeModification*() =
    let modificationDisplayDuration = 0.5'f32
    let currTime = this.getWorld().getTimeSeconds()
    if roundTimeModification != 0.0 and
       currTime - roundTimeModificationTime <= modificationDisplayDuration:
      let displayText = describeTime(roundTimeModification, true)
      let delta = clamp((currTime - roundTimeModificationTime) / modificationDisplayDuration, 0.0'f32, 1.0'f32)
      let posY = 0.11'f32 + delta * 0.24'f32

      drawMessage(displayText, 0.5'f32, posY, 1.0'f32, whiteLinearColor)

  proc drawActiveMessages*() =
    ## used to display active messages and removing expired ones
    let currTime = this.getWorld().getTimeSeconds()
    for i in countdown(activeMessages.len - 1, 0):
      let msg = activeMessages[i]
      let bIsActive = currTime < (msg.displayDuration + msg.displayStartTime)
      if bIsActive:
        drawMessage(msg.message, msg.posX, msg.posY, msg.textScale, whiteLinearColor, msg.bRedBorder)
      else:
        activeMessages.delete(i)

  proc drawMessage*(message: FString; posX, posY: cfloat; textScale: cfloat;
                    textColor: FLinearColor; bRedBorder: bool = false) =
    ## used to display single text message with specified parameters
    if this.canvas == nil: return
    var sizeX, sizeY: float32
    this.canvas.strLen(hudFont, message, sizeX, sizeY)

    let drawX = this.canvas.clipX * clamp(posX, 0.0, 1.0) - (sizeX * textScale * 0.5'f32 * uiScale)
    let drawY = this.canvas.clipY * clamp(posY, 0.0, 1.0) - (sizeY * textScale * 0.5'f32 * uiScale)
    let boxPadding = 8.0'f32 * uiScale
    drawBorder(drawX - boxPadding, drawY - boxPadding,
               sizeX * textScale * uiScale + boxPadding * 2.0'f32,
               sizeY * textScale * uiScale + boxPadding * 2.0'f32,
               0.4'f32,
               if bRedBorder: redBorder else: blueBorder)

    var textItem = initFCanvasTextItem(initFVector2D(drawX, drawY), message.toText(), hudFont, textColor)
    textItem.scale = initFVector2D(textScale * uiScale, textScale * uiScale)
    textItem.enableShadow(transparentLinearColor)
    this.canvas.drawItem(textItem)

  proc drawBorder*(posX, posY, width, height, borderScale: cfloat; borderTextures: FBorderTextures) =
    ## draws 3x3 border with tiled background
    var borderItem = initFCanvasBorderItem(
      initFVector2D(posX, posY),
      borderTextures.border.resource,
      borderTextures.background.resource,
      borderTextures.leftBorder.resource,
      borderTextures.rightBorder.resource,
      borderTextures.topBorder.resource,
      borderTextures.bottomBorder.resource,
      initFVector2D(width, height),
      whiteLinearColor)

    borderItem.blendMode = SE_BLEND_Translucent
    borderItem.cornerSize = initFVector2D(85.0 / 256.0, 95.0 / 256.0)
    borderItem.borderScale = initFVector2D(borderScale * uiScale, borderScale * uiScale)
    borderItem.backgroundScale = initFVector2D(1.0'f32 * uiScale, 1.0'f32 * uiScale)
    this.canvas.drawItem(borderItem)

  proc drawHighscoreEntryPrompt*() =
    ## draws high score entry prompt
    let sizeX = 90 * uiScale
    let sizeY = 90 * uiScale
    let drawX: float32 = (this.canvas.clipX - sizeX * 3) / 2.0
    let drawY: float32 = (this.canvas.clipY - sizeY) / 2.0

    let UVL = 90.0 / 128.0
    let textScale = 1.8

    var tileItem = initFCanvasTileItem(
      initFVector2D(drawX + sizeX * float32(currentLetter), drawY),
      upButtonTexture.resource,
      initFVector2D(sizeX, sizeY),
      initFVector2D(0, 0),
      initFVector2D(UVL, UVL),
      whiteLinearColor
    )
    tileItem.blendMode = SE_BLEND_Translucent

    if highScoreName[currentLetter] < 'Z':
      this.canvas.drawItem(tileItem)
      this.addHitBox(tileItem.position, tileItem.size, u16"Up", true, 255)

    if highScoreName[currentLetter] > 'A':
      tileItem.position = initFVector2D(drawX + sizeX * float32(currentLetter), drawY + sizeY * 2)
      tileItem.texture = downButtonTexture.resource

      this.addHitBox(tileItem.position, tileItem.size, u16"Down", true, 255)
      this.canvas.drawItem(tileItem)

    var textItem = initFCanvasTextItem(initFVector2D(drawX, drawY), initFText(), hudFont, whiteLinearColor)
    textItem.scale = initFVector2D(textScale * uiScale, textScale * uiScale)
    textItem.enableShadow(transparentLinearColor)

    var strSizeX, strSizeY: float32
    var offset: float32

    for i in 0..<highScoreName.len:
      textItem.text = highScoreName[i].toFString().toText()
      this.canvas.strLen(hudFont, textItem.text.toString(), strSizeX, strSizeY)
      strSizeX = strSizeX * textScale * uiScale
      strSizeY = strSizeY * textScale * uiScale
      textItem.position = initFVector2D(drawX + offset + (sizeX - strSizeX) / 2.0, drawY + sizeY)

      this.drawBorder(drawX + offset, drawY + sizeY, sizeX, sizeY, 0.4'f32,
                      if int(currentLetter) == i: blueBorder else: redBorder)
      this.addHitBox(initFVector2D(drawX + offset, drawY + sizeY), tileItem.size, initFName(u16"Letter", i), true, 255)

      this.canvas.drawItem(textItem)
      offset += sizeX

    let buttonWidth = 200 * uiScale
    textItem.text = nsLocText("PlatformerGame.HUD", "OK", "OK")
    this.canvas.strLen(hudFont, textItem.text.toString(), strSizeX, strSizeY)
    strSizeX = strSizeX * textScale * uiScale
    strSizeY = strSizeY * textScale * uiScale
    textItem.position = initFVector2D((this.canvas.clipX - strSizeX) / 2.0, drawY + sizeY * 4)
    this.drawBorder((this.canvas.clipX - buttonWidth) / 2.0, drawY + sizeY * 4, buttonWidth, sizeY, 0.4, blueBorder)
    this.addHitBox(initFVector2D((this.canvas.clipX - buttonWidth) / 2.0, drawY + sizeY * 4),
                   initFVector2D(buttonWidth, sizeY), initFName("OK"), true, 255)
    this.canvas.drawItem(textItem)

  proc drawHighscore*() =
    ## draws high score
    let highscore = nsLocText("PlatformerGame.HUD", "Highscore", "High score")
    let sizeX: float32 = this.canvas.clipX * 0.4'f32
    let sizeY: float32 = 1000 * uiScale
    let drawX: float32 = (this.canvas.clipX - sizeX) / 2.0'f32
    let drawY: float32 = (this.canvas.clipY - sizeY) / 2.0'f32

    drawBorder(drawX, drawY, sizeX, sizeY, 1.0'f32, blueBorder)

    let textScale = 1.4'f32
    let textMargin = 0.03'f32

    var strSizeX, strSizeY: float32
    this.canvas.strLen(hudFont, highscore.toString(), strSizeX, strSizeY)
    strSizeX = strSizeX * textScale * uiScale
    strSizeY = strSizeY * textScale * uiScale

    var textItem = initFCanvasTextItem(
      initFVector2D((this.canvas.clipX - strSizeX) / 2.0'f32, drawY + sizeY * textMargin),
      highscore, hudFont, whiteLinearColor)

    textItem.scale = initFVector2D(textScale * uiScale, textScale * uiScale)
    textItem.enableShadow(transparentLinearColor)
    this.canvas.drawItem(textItem)

    let borderSize = float32(blueBorder.leftBorder.resource.getSizeX()) * uiScale
    var tileItem = initFCanvasTileItem(
      initFVector2D(drawX + borderSize, drawY + sizeY * textmargin + strSizeY),
      blueBorder.topBorder.resource,
      initFVector2D(sizeX - 2 * borderSize, float32(blueBorder.topBorder.resource.getSizeY()) * uiScale),
      initFVector2D(0, 0),
      initFVector2D((sizeX - 2 * borderSize) / float32(blueBorder.topBorder.resource.getSizeX()) * uiScale, 1.0),
      whiteLinearColor
    )
    tileItem.blendMode = SE_BLEND_Translucent
    this.canvas.drawItem(tileItem)

    let startY = drawY + sizeY * textMargin * 3 + strSizeY * textScale * uiScale
    let colWidths = [70 * uiScale, 340* uiScale, 200 * uiScale]
    let totalWidth = colWidths[0] + colWidths[1] + colWidths[2]

    for i in 0..9:
      let texts = [(i + 1).toText() & u16".".toText(),
                   describeTime(highscoreTimes[i], false).toText(),
                   highscoreNames[i].toText()]
      var offset = 0.0'f32
      for column in 0..2:
        textItem.text = texts[column]
        this.canvas.strLen(hudFont, textItem.text.toString(), strSizeX, strSizeY)
        strSizeX = strSizeX * textScale * uiScale
        strSizeY = strSizeY * textScale * uiScale
        textItem.position = initFVector2D(
          (this.canvas.clipX - totalWidth) / 2.0'f32 + offset + colWidths[column] - strSizeX,
          startY + float32(i) * strSizeY)
        this.canvas.drawItem(textItem)
        offset += colWidths[column]
