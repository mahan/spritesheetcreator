

EnableExplicit
XIncludeFile "mainform.pbf"

Structure Rectangle
  x1.i
  y1.i
  x2.i
  y2.i
EndStructure

Structure SpriteInfo Extends Rectangle
  filename.s
  w.i
  h.i
  area.i ; for sorting
  image.i
EndStructure

Structure JSONSprite ; for unknown reasons all types are strings.
  x.s
  y.s
  w.s
  h.s
  rotated.s
  extruded.s
  margin.s
  name.s
EndStructure

Structure JSONSpriteAtlas
  List sprites.JSONSprite()
EndStructure

Global NewList incomingImageFilenames.s()
Global NewList spriteInfos.SpriteInfo()
Global NewList placedSprites.SpriteInfo()
Global rightOfLastX.i
Global rightOfLastY.i

Global sheetRect.Rectangle


; Rectsoverlap solution borrowed from here https://stackoverflow.com/questions/306316/determine-if-two-rectangles-overlap-each-other
Procedure.b valueInRange(value.i, rangeStart.i, rangeEnd.i)
  ProcedureReturn Bool((value >= rangeStart) And (value <= rangeEnd))
EndProcedure

Procedure RectsOverlap(*r1.Rectangle, *r2.Rectangle)
  Protected xOverlap.b = Bool(valueInRange(*r1\x1, *r2\x1, *r2\x2) Or valueInRange(*r2\x1, *r1\x1, *r1\x2))
  Protected yOverlap.b = Bool(valueInRange(*r1\y1, *r2\y1, *r2\y2) Or valueInRange(*r2\y1, *r1\y1, *r1\y2))
  ProcedureReturn Bool (xOverlap And yOverlap)
EndProcedure

Procedure Rect1WithinRect2(*r1.Rectangle, *r2.Rectangle)
  Protected xWithin.b = Bool(valueInRange(*r1\x1, *r2\x1, *r2\x2) And valueInRange(*r1\x2, *r2\x1, *r2\x2))
  Protected yWithin.b = Bool(valueInRange(*r1\y1, *r2\y1, *r2\y2) And valueInRange(*r1\y2, *r2\y1, *r2\y2))
  ProcedureReturn Bool(xWithin And yWithin)
EndProcedure  
  
Procedure CreateSpriteInfos()
  ClearList(spriteInfos())
  ForEach incomingImageFilenames()
    Protected image = LoadImage(#PB_Any, incomingImageFilenames())
    If image = 0 : MessageRequester("Unable to open image", "Unable to open: " + incomingImageFilenames()) : Continue : EndIf
    AddElement(spriteInfos())
    spriteInfos()\filename = incomingImageFilenames()
    spriteInfos()\image = image
    spriteInfos()\w = ImageWidth(image)
    spriteInfos()\h = ImageHeight(image)
    spriteInfos()\area = spriteInfos()\w * spriteInfos()\h
    ;Debug "w: " + spriteInfos()\w + "h: " + spriteInfos()\h
  Next
EndProcedure

Procedure updateListViewWithImageFilenames()
  ClearGadgetItems(listViewIncomingFiles)
  ForEach incomingImageFilenames()
   AddGadgetItem(listViewIncomingFiles, -1, incomingImageFilenames())
  Next 
EndProcedure

Procedure OnButtonOpenPressed(EventType)
  ClearList(incomingImageFilenames())
  Protected filename.s = OpenFileRequester("Select images to add to spritesheet", "", "Image files|*.png", 0, #PB_Requester_MultiSelection)
  While filename
    AddElement(incomingImageFilenames())
    incomingImageFilenames() = filename
    filename = NextSelectedFileName()
  Wend
 updateListViewWithImageFilenames() 
EndProcedure

Procedure spriteOverlapsAnyExisting(*sprite.SpriteInfo)
  ForEach placedSprites()
    If RectsOverlap(*sprite, placedSprites()) : ProcedureReturn #True : EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure updateSpriteCoords(*sprite.SpriteInfo, x, y)
  *sprite\x1 = x
  *sprite\y1 = y
  *sprite\x2 = x + *sprite\w - 1
  *sprite\y2 = y + *sprite\h - 1
  ;Debug "Sprite: " + *sprite\filename + " x1: " + *sprite\x1 + " y1: " + *sprite\y1 + " x2: " + *sprite\x2 + " y2: " + *sprite\y2
EndProcedure

Procedure CoordsOnSheetOK(*sheetRect.Rectangle, *sprite.SpriteInfo, x, y)
  updateSpriteCoords(*sprite, x, y)
  If spriteOverlapsAnyExisting(*sprite)
    ProcedureReturn #False
  EndIf
  If Rect1WithinRect2(*sprite, *sheetRect) ; found spot!
    ProcedureReturn #True
  EndIf  
EndProcedure

Procedure updateRightOfLast(*sprite.SpriteInfo)
  rightOfLastX = *sprite\x2 + 1
  rightOfLastY = *sprite\y1
EndProcedure

Procedure findUnusedSpaceOnSheet(spriteSheet, *sprite.SpriteInfo)
  
  ;Debug "sheet: x1: " + sheetRect\x1 + " y1: " + sheetRect\y1 + " x2: " + sheetRect\x2 + " y2: " + sheetRect\y2 
  
  ;Optimization: Check if space just right of the last sprite is ok (if not we do it the hard way below)
  If CoordsOnSheetOK(sheetRect, *sprite, rightOfLastX, rightOfLastY)
    ;Debug "optimized"
    updateSpriteCoords(*sprite, rightOfLastX, rightOfLastY)
    updateRightOfLast(*sprite)
    ProcedureReturn #True
  EndIf    
  
  ;Debug "Semi hard way!"
  
  Protected x, y
  
  x = 0
  For y = 0 To ImageHeight(spriteSheet)-1
    If CoordsOnSheetOK(sheetRect, *sprite, x, y) 
      updateSpriteCoords(*sprite, x, y)
      updateRightOfLast(*sprite)
      ProcedureReturn #True
    EndIf
  Next
  
  
  ;Debug "Hard way!"
  
  For y = 0 To ImageHeight(spriteSheet)-1
    For x = 0 To ImageWidth(spriteSheet)-1
      If CoordsOnSheetOK(sheetRect, *sprite, x, y) 
        updateSpriteCoords(*sprite, x, y)
        updateRightOfLast(*sprite)
        ProcedureReturn #True
      EndIf
    Next
  Next
  ProcedureReturn #False
EndProcedure

Procedure PlaceSpriteOnSheet(spriteSheet, *sprite.SpriteInfo)
  If Not findUnusedSpaceOnSheet(spriteSheet, *sprite)
    MessageRequester("PlaceSpriteOnSheet()", "Unable to find space to put this sprite: " + *sprite\filename)
    End 1; Exit with error
  EndIf
  AddElement(placedSprites())
  CopyStructure(*sprite, @placedSprites(), SpriteInfo)
  StartDrawing(ImageOutput(spriteSheet))
  ;Debug "*sprite\image: " + *sprite\image + " isImage. " + Bool(IsImage(*sprite\image))
  DrawAlphaImage(ImageID(*sprite\image), *sprite\x1, *sprite\y1)
  StopDrawing()
EndProcedure

Procedure PlaceSpritesOnSheet(spriteSheet)
  sheetRect\x1 = 0
  sheetRect\y1 = 0
  sheetRect\x2 = ImageWidth(spriteSheet)-1
  sheetRect\y2 = ImageHeight(spriteSheet)-1
  ForEach spriteInfos()
    PlaceSpriteOnSheet(spriteSheet, @spriteInfos())
  Next
  MessageRequester("All sprites ...", "... are now placed")
EndProcedure

Procedure spritesFitSpriteSheet()
  Protected targetArea.i = Val(GetGadgetText(ComboOutputWidths)) * Val(GetGadgetText(ComboOutputHeights))
  Protected sourceArea.i = 0
  ForEach spriteInfos()
    sourceArea + spriteInfos()\area
  Next
  ProcedureReturn Bool(sourceArea <= targetArea)
EndProcedure

Procedure SaveJSONAtlas(atlasFilename.s)
  Protected json.JSONSpriteAtlas
  ForEach spriteInfos()
    AddElement(json\sprites())
    json\sprites()\extruded = "0"
    json\sprites()\margin = "0"
    json\sprites()\rotated = "0"
    json\sprites()\name = GetFilePart(spriteInfos()\filename)
    json\sprites()\x = Str(spriteInfos()\x1)
    json\sprites()\y = Str(spriteInfos()\y1)
    json\sprites()\w = Str(spriteInfos()\w)
    json\sprites()\h = Str(spriteInfos()\h)
  Next
  CreateJSON(0)
  InsertJSONStructure(JSONValue(0), @json, JSONSpriteAtlas)
  CreateFile(0, atlasFilename, #PB_UTF8)
  WriteString(0, ComposeJSON(0, #PB_JSON_PrettyPrint))
  CloseFile(0)
EndProcedure

Procedure SaveIgnitionAtlas(atlasFilename.s)
  CreateFile(0, atlasFilename, #PB_UTF8)
  ForEach spriteInfos()
    WriteStringN(0, GetFilePart(spriteInfos()\filename) + ":" + spriteInfos()\x1 + ":" + spriteInfos()\y1 + ":" + spriteInfos()\w + ":" + spriteInfos()\h)
  Next
  CloseFile(0)
EndProcedure

Procedure OnButtonSaveSpriteSheetPressed(EventType)
  CreateSpriteInfos()
  If Not spritesFitSpriteSheet()
    MessageRequester("Save error", "Source sprites do not fit target spritesheet. Try making the target spritesheet bigger.")
    ProcedureReturn
  EndIf
  ;Sort by area decreasing
  SortStructuredList(spriteInfos(), #PB_Sort_Descending, OffsetOf(SpriteInfo\area), TypeOf(SpriteInfo\area))
  Protected spriteSheet = CreateImage(#PB_Any, Val(GetGadgetText(ComboOutputWidths)), Val(GetGadgetText(ComboOutputHeights)), 32)
  StartDrawing(ImageOutput(spriteSheet))
  ;DrawingMode(#PB_2DDrawing_AlphaBlend)
  ;Box(0, 0, ImageWidth(spriteSheet), ImageHeight(spriteSheet), RGBA(128, 128, 128, 255))
  DrawingMode(#PB_2DDrawing_AlphaChannel)
  ;Box(0, 0, ImageWidth(spriteSheet), ImageHeight(spriteSheet), RGBA(128, 128, 128, 255))
  Box(0, 0, ImageWidth(spriteSheet), ImageHeight(spriteSheet), $00000000)
  StopDrawing()
  PlaceSpritesOnSheet(spriteSheet)
  ;TODO: ask for output filename ...
  SaveImage(spriteSheet, "myNewSheet.png", #PB_ImagePlugin_PNG)
  If GetGadgetState(optSaveJSONAtlas) = 1 
    SaveJSONAtlas("myNewSheet.json")
  Else
    SaveIgnitionAtlas("myNewSheet.txt")
  EndIf
EndProcedure

Procedure initOutputSizes()
  ClearGadgetItems(ComboOutputWidths)
  ClearGadgetItems(ComboOutputHeights)
  Protected i
  For i = 6 To 13
    AddGadgetItem(ComboOutputWidths, -1, Str(Pow(2, i)))
    AddGadgetItem(ComboOutputHeights, -1, Str(Pow(2, i)))
  Next
  SetGadgetText(ComboOutputWidths, GetGadgetItemText(ComboOutputWidths, 0))
  SetGadgetText(ComboOutputHeights, GetGadgetItemText(ComboOutputHeights, 0))
EndProcedure

Procedure main()
  UsePNGImageDecoder()
  UsePNGImageEncoder()
  OpenWindow_0()
  initOutputSizes()
  Protected event
  Repeat
    event = WaitWindowEvent()
    Window_0_Events(event)
  Until event = #PB_Event_CloseWindow
EndProcedure

main()
; IDE Options = PureBasic 5.42 LTS (Linux - x64)
; CursorPosition = 85
; FirstLine = 73
; Folding = ----
; Markers = 21,197
; EnableUnicode
; EnableXP