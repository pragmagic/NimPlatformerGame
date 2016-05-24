import ue4

class FPlatformerPicture:
  var bIsVisible: bool
    ## if picture is currently drawn
  var bIsHiding: bool
    ## if picture is currently fading out
  var animStartedTime: float32
    ## fade in or fade out started time
  var animTime: float32
    ## how long current animation should be playing (fading in or fading out)
  var tintColor: FLinearColor
    ## picture tint color
  var screenCoverage: float32
    ## picture scale compared to the size of viewport 1.0f = full screen
  var bKeepAspectRatio: bool
    ## if picture should keep aspect ratio when scaling or use viewport aspect ratio
  var image: ptr UTexture2D
    ## image resource
  var ownerWorld: ptr UWorld
    ## owner world

  proc init(world: ptr UWorld) {.constructor, callSuper.} =
    ## picture constructor
    ownerWorld = world
    tintColor = whiteLinearColor
    tintColor.a = 0.0
    bIsHiding = false

  proc show*(inTexture: ptr UTexture2D, inFadeInTime: float32,
            inScreenCoverage: float32, bInKeepAspectRatio: bool) =
    ## shows picture
    if inTexture != nil:
      image = inTexture
      animStartedTime = ownerWorld.getTimeSeconds()
      bIsHiding = false
      animTime = inFadeInTime
      bIsVisible = true
      screenCoverage = inScreenCoverage / 2.0
      bKeepAspectRatio = bInKeepAspectRatio

  proc hide*(fadeOutTime: float32) =
    ## hides picture
    animTime = fadeOutTime
    animStartedTime = ownerWorld.getTimeSeconds()
    bIsHiding = true

  proc tick*(canvas: ptr UCanvas) =
    ## used for fade in and fade out
    if bIsVisible:
      var animPercentage = 0.0
      if bIsHiding:
        animPercentage = 1.0 - min(1.0, (ownerWorld.getTimeSeconds() - animStartedTime) / animTime)
        if animPercentage == 0.0:
          bIsVisible = false
      else:
        animPercentage = min(1.0, (ownerWorld.getTimeSeconds() - animStartedTime) / animTime)
      tintColor.a = animPercentage
      canvas.setDrawColor(tintColor.toFColor(true))
      var width = image.getSurfaceWidth()
      var height = image.getSurfaceHeight()
      var imageAspectRatio = width / height
      var viewAspectRatio = canvas.clipX / canvas.clipY
      if imageAspectRatio >= viewAspectRatio:
        width = canvas.clipX * screenCoverage
        height = if bKeepAspectRatio: width / imageAspectRatio else: canvas.clipY * screenCoverage
      else:
        height = canvas.clipY * screenCoverage
        width = if bKeepAspectRatio: height * imageAspectRatio else: canvas.clipX * screenCoverage

      var tileItem = initFCanvasTileItem(
        vec2D((canvas.clipX - width) / 2.0, (canvas.clipY - height) / 2.0),
        image.resource, vec2D(width, height), tintColor)
      canvas.drawItem(tileItem)

  proc isVisible*(): bool {.noSideEffect.} =
    ## check if picture is currently visible
    result = bIsVisible
