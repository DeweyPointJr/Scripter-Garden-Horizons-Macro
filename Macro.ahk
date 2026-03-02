#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.



; GLOBAL VARIABLES

global RobloxWindow
global iniFile := A_ScriptDir "\config.ini"

global AutoAlignCamera
global CurrentShop := ""
global PLOT := 0

global SEEDERRORS := 0
global GEARERRORS := 0
global ALIGNERRORS := 0

global AutoHarvest
global HarvestNow := false

global shopKeys := Object()
shopKeys["Seeds"] := "Seed"
shopKeys["Gears"] := "Gear"

; === Read from INI ===
iniFile := "config.ini"

IniRead, StartHotkey, %iniFile%, Settings, StartHotkey, F1
IniRead, PauseHotkey, %iniFile%, Settings, PauseHotkey, F2
IniRead, StopHotkey, %iniFile%, Settings, StopHotkey, F3
IniRead, SettingsStart, %iniFile%, Settings, SettingsStart, 0
IniRead, AutoHarvest, %iniFile%, Settings, AutoHarvest, 0
IniRead, HarvestTime, %iniFile%, Settings, HarvestTime, 30
IniRead, AutoSell, %iniFile%, Settings, AutoSell, 0
IniRead, AutoBotanist, %iniFile%, Settings, AutoBotanist, 0

; === Bind Hotkeys Dynamically ===
Hotkey, %StartHotkey%, StartHotkeyLabel
Hotkey, %PauseHotkey%, PauseHotkeyLabel
Hotkey, %StopHotkey%, StopHotkeyLabel

; === Reconnect ===
global VIP_SERVER_LINK
global AutoReconnect
global JoinPublicServer
IniRead, VIP_SERVER_LINK, %iniFile%, Settings, VipServerLink, "Enter a private server link here."
IniRead, AutoReconnect, %iniFile%, Settings, AutoReconnect, 0
IniRead, JoinPublicServer, %iniFile%, Settings, JoinPublicServer, 0

; === Positiniong ===
global backpackBtnX
global backpackBtnY

IniRead, backpackBtnX, %iniFile%, Settings, backpackBtnX, 204
IniRead, backpackBtnY, %iniFile%, Settings, backpackBtnY, 53


; ITEMS
global seeds := ["Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple", "Rose", "Wheat", "Banana", "Plum", "Potato", "Cabbage", "Cherry", "Bamboo", "Mango"]

global gears := ["Watering Can", "Basic Sprinkler", "Harvest Bell", "Turbo Sprinkler", "Favorite Tool", "Super Sprinkler", "Trowel"]

; SHOPS
; Create global shop objects
global shops := Object()
shops["Seeds"] := seeds
shops["Gears"] := gears

global shopPrefixes := Object()
shopPrefixes["Seeds"] := "Seed"
shopPrefixes["Gears"] := "Gear"

; FUNCTIONS
ClickRelative(relX, relY, coord := 0, noDelay := 0) {
    global RobloxWindow

    ; Ensure RobloxWindow is valid
    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow) {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow {
            Tooltip, Roblox window not found!
            return
        }
    }

    ; Activate & restore window
    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2
    WinGet, winState, MinMax, ahk_id %RobloxWindow%
    if (winState = -1) {
        ; Window is minimized, restore it
        WinRestore, ahk_id %RobloxWindow%
    }

    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2


    ; Get window position
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%
    if (ErrorLevel || W = 0 || H = 0) {
        Tooltip, wingetpos failed
        return
    }

    ; Calculate click coordinates
    if (coord = 1) {
        clickX := Round(X + (relX / 1936) * W)
        clickY := Round(Y + (relY / 1056) * H)
    } else if (coord = 2) {
        clickX := relX
        clickY := relY
    } else {
        clickX := Round(X + (W * relX))
        clickY := Round(Y + (H * relY))
        clickY += 3
    }

    oldMode := A_SendMode
    

    if (noDelay = 0) {
        SendMode Event
        MouseMove, %clickX%, %clickY%, 3
    }
    Sleep, 10
    Click, %clickX%, %clickY%

    SendMode %oldMode%
}

CheckCameraMode() {
    global RobloxWindow
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%

    Send, {Esc}
    Sleep, 1000
    Send, {Tab}
    Sleep, 500
    Send, {Down}

    baseDir = A_ScriptDir . Images
    CoordMode, Pixel, Window
    CoordMode, Mouse, Window

    Loop, 4 {
        imagePath := A_ScriptDir . "\Images\Camera" . A_Index . ".png"
        ImageSearch, FoundX, FoundY, (((X+557)/1936)*W), (((Y+218)/1056)*H), (((X+1376)/1936)*W), (((Y+910)/1056)*H), *80 %imagePath%
        if (ErrorLevel = 0) {
            return A_Index
        }
    }
    Loop, 4 {
        Send, {Right}
        Sleep, 100
    }
    Loop, 4 {
        imagePath := A_ScriptDir . "\Images\Camera" . A_Index . ".png"
        ImageSearch, FoundX, FoundY, (((X+557)/1936)*W), (((Y+218)/1056)*H), (((X+1376)/1936)*W), (((Y+910)/1056)*H), *80 %imagePath%
        if (ErrorLevel = 0) {
            return A_Index
        }
    }
    Tooltip, ERROR: Unable to detect camera mode
    return 0  ; No match found
}

SetCameraMode(number) {
    if (number > 4)
        number := 4

    mode := CheckCameraMode()
    if (mode) {
        distance := mode - number
        if (distance > 0) {
            Loop, %distance% {
                Send, {Left}
                Sleep, 100
            }
        } else if (distance < 0) {
            Loop, % Abs(distance) {
                Send, {Right}
                Sleep, 100
            }
        }
        Sleep, 1000
    }
    Send, {Esc}
    Sleep, 1000
    Return
}

CheckRobloxStatusFunc() {

    ; Check if Roblox is not open
    if !(WinExist("Roblox")) {
        Tooltip, Roblox not open. Reconnecting...
        ReconnectToGame()
    }
    
    ; Check if the disconnected text exists
    global RobloxWindow
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%

    imagePath := A_ScriptDir . "\Images\Disconnected.png"
    ImageSearch, FoundX, FoundY, (((X+702)/1936)*W), (((Y+361)/1056)*H), (((X+1224)/1936)*W), (((Y+718)/1056)*H), *80 %imagePath%
    if (ErrorLevel = 0) {
        ReconnectToGame()
        return
    }
    
    ; Check for error windows
    try {
        if (WinExist("ahk_class #32770 ahk_exe RobloxPlayerBeta.exe")) {
            errorText := WinGetText, ahk_class #32770 ahk_exe RobloxPlayerBeta.exe
            if (InStr(errorText, "disconnected") || InStr(errorText, "lost connection") || InStr(errorText, "error") || InStr(errorText, "Disconnected")) {
                Tooltip, ⚠ Connection error detected. Reconnecting...
                WinClose, ahk_class #32770 ahk_exe RobloxPlayerBeta.exe
                Sleep, 1000
                ReconnectToGame()
                return
            }
        }
        
        ; Check Roblox window titles
        robloxWindows := WinGetList, ahk_exe RobloxPlayerBeta.exe
        for hwnd in robloxWindows {
            try {
                windowTitle := WinGetTitle, "ahk_id " . hwnd
                if (InStr(windowTitle, "Disconnected") || InStr(windowTitle, "Lost connection") || InStr(windowTitle, "Error")) {
                    Tooltip, ⚠ Game disconnection detected. Reconnecting...
                    ReconnectToGame()
                    return
                }
            }
        }
    }
}

ReconnectToGame() {
    global VIP_SERVER_LINK, RECONNECT_DELAY
    if (VIP_SERVER_LINK = "") || (VIP_SERVER_LINK = "Enter a private server link here.") {
        Tooltip, Cannot reconnect: No VIP Server link
        return
    }
    
    Tooltip, Starting reconnection process...
    
    ; Close all Roblox processes
    try {
        WinClose, Roblox
        Sleep, 1000
        WinClose, Roblox
        Tooltip, Roblox closed. Waiting...
        Sleep, 2000
        
        ; Wait before reopening
        Sleep, %RECONNECT_DELAY%
        
        ; Open VIP Server link
        Tooltip, Opening Roblox...
        if JoinPublicServer {
            joinLink := "roblox://placeID=130594398886540"
        } else {
            ; --- Extract the link-code part from the URL ---
            if (RegExMatch(VIP_SERVER_LINK, "i)(?<=privateServerLinkCode=)[A-Za-z0-9]+", linkCode))
            {
                ; Build the Roblox deeplink URI
                joinLink := "roblox://placeID=130594398886540&linkCode=" linkCode
            }
        }
        ; Launch via Windows Shell (same behavior as Win+R)
        try
        {
            ComObjCreate("Shell.Application").ShellExecute(joinLink)
        }
        catch e
        {
            MsgBox, 16, Error, % "Failed to launch Roblox:`n" e.Message
        }
        
        ; Wait for Roblox to open
        Loop 30 {
            global RobloxWindow
            if (WinExist("Roblox")) {
                WinMaximize, Roblox
                Tooltip, Roblox opened successfully. Loading game...
                WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
                Sleep, 15000  ; Wait for game to load
                ; Check for connection failed
                imagePath := A_ScriptDir . "\Images\ConnectionFailed.png"
                ImageSearch, FoundX, FoundY, (((X+702)/1936)*W), (((Y+361)/1056)*H), (((X+1224)/1936)*W), (((Y+718)/1056)*H), *80 %imagePath%
                if (ErrorLevel = 0) {
                    Tooltip, Connection Failed. Retrying...
                    Sleep, 2500
                    ReconnectToGame()
                }
                ; Connection didn't fail. Return to previous function
                if (PixelColorFound(0xF4F4AF, 1111, 404, 1261, 521)) {
                    Tooltip, Successfully joined game!
                    ClickRelative(0.5, 0.5)
                    Sleep, 2500
                    if (PixelColorFound(0xAD4515, 802, 778, 1142, 950, 10)) {
                        ; Detect which plot the player is claiming
                        Loop, 6
                        {
                            plotImage := "Plot" . A_Index . ".png"
                            tooltip, Checking %plotImage%
                            if ImageDetect(plotImage, 808, 788, 1131, 889, 80) {
                                tooltip, Plot found as %A_Index%!
                                PLOT := A_Index
                                Sleep, 1000
                                break
                            }
                            Sleep, 1000
                        }
                        Tooltip, Plot %PLOT% Claimed
                        ClickRelative(972, 894, 1)
                        Sleep, 1000
                    } else {
                        Tooltip, ERROR: Claim button not detected.
                        Sleep, 1000
                        ReconnectToGame()
                    }
                } else {
                    Tooltip, ERROR: Game logo not detected.
                    Sleep, 1000
                    ReconnectToGame()
                }
                break
            }
            Sleep, 1000
        }
        if (!WinExist("Roblox")) {
            Tooltip, Failed to open Roblox. Retrying...
            Sleep, 2500
            ReconnectToGame()
        }
    }
}


UINavigation(command, uialreadyopen := 0, closeUi := 1, delay := 100) {
    ; If UI is not already open, press backslash to open it
    if (!uialreadyopen) {
        Send, {sc02B}  ; sc02B is the scancode for the backslash key ("\")
        Sleep, %delay%
    }

    ; Navigate to hotbar if settings start
    if (SettingsStart) {
        UINavigation("DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD", 1, 0)
    }

    ; Loop through each character in the command string
    Loop, Parse, command
    {
        char := A_LoopField
        if (char = "U") {
            Send, {Up}
            Sleep, %delay% 
        } else if (char = "R") {
            Send, {Right}
            Sleep, %delay%
        } else if (char = "D") {
            Send, {Down}
            Sleep, %delay%
        } else if (char = "L") {
            Send, {Left}    
            Sleep, %delay%
        } else if (char = "E") {
            Send, {Enter}
            Sleep, %delay%
        } else if (char = "|") {
            Sleep, %delay%
        }
        
    }

    ; If closeUi flag is set, press backslash again to close
    if (closeUi) {
        Sleep, %delay%
        Send, {sc02B}
    }
}

searchItem(search := "nil") {
    global backpackBtnX
    global backpackBtnY

    if (search = "nil") {
        return
    }

    ClickRelative(%backpackBtnX%, %backpackBtnY%, 2)
    Sleep, 1000
    ClickRelative(1172, 678, 1)
    Sleep, 1000
    ; Delete any existing text
    Send, {Ctrl down}
    Send, {Right}
    Send, {Backspace}
    Send, {Ctrl up}
    Sleep, 1000
    Send, %search%

}
PixelColorFound(color, x1, y1, x2, y2, variation := 0) {
    ; Reference resolution
    refW := 1936
    refH := 1056

    ; Get the current Roblox window position and size
    global RobloxWindow
    WinGetPos, winX, winY, winW, winH, ahk_id %RobloxWindow%
    if (winW = "" || winH = "") {
        return 0 ; something went wrong
    }

    ; Scale coordinates to current window size
    scaleX := winW / refW
    scaleY := winH / refH

    sx1 := winX + (x1 * scaleX)
    sx2 := winX + (x2 * scaleX)
    sy1 := winY + (y1 * scaleY)
    sy2 := winY + (y2 * scaleY)

    ; Search for the pixel in the selected area
    PixelSearch, foundX, foundY, %sx1%, %sy1%, %sx2%, %sy2%, %color%, %variation%, Fast RGB
    if (ErrorLevel = 0)
        return 1
    else
        return 0
}

FindPixelRelative(color, x1, y1, x2, y2, ByRef outX, ByRef outY, variation := 0) {
    ; Reference resolution
    refW := 1936
    refH := 1056

    ; Get the current Roblox window position and size
    global RobloxWindow
    WinGetPos, winX, winY, winW, winH, ahk_id %RobloxWindow%
    if (winW = "" || winH = "") {
        return 0 ; window not found
    }

    ; Scale coordinates to current window size
    scaleX := winW / refW
    scaleY := winH / refH

    sx1 := winX + (x1 * scaleX)
    sx2 := winX + (x2 * scaleX)
    sy1 := winY + (y1 * scaleY)
    sy2 := winY + (y2 * scaleY)

    ; Search for the pixel
    PixelSearch, foundX, foundY, %sx1%, %sy1%, %sx2%, %sy2%, %color%, %variation%, Fast RGB

    if (ErrorLevel = 0) {
        outX := foundX
        outY := foundY
        return 1
    } else {
        return 0
    }
}

ImageDetect(imageName, x1, y1, x2, y2, variation = 80) {
    ; === Setup ===
    baseDir := A_ScriptDir . "\Images\"
    imagePath := baseDir . imageName

    ; Reference resolution (your base)
    refW := 1936
    refH := 1056

    ; Get Roblox window position & size
    WinGetPos, X, Y, W, H, Roblox
    if (ErrorLevel) {
        Tooltip, Roblox window not found!
        Sleep, 1500
        Tooltip
        return 0
    }

    CoordMode, Pixel, Window
    CoordMode, Mouse, Window

    ; === Try up to 4 times ===
    Loop, 4 {

        ; Scale coordinates relative to Roblox window
        x1s := X + ((x1 / refW) * W)
        y1s := Y + ((y1 / refH) * H)
        x2s := X + ((x2 / refW) * W)
        y2s := Y + ((y2 / refH) * H)

        ; Search within Roblox window
        ImageSearch, FoundX, FoundY, %x1s%, %y1s%, %x2s%, %y2s%, *%variation% %imagePath%

        if (ErrorLevel = 0) {
            Sleep, 500
            Tooltip
            return 1
        }
        Sleep, 1000
    }

    Sleep, 1000
    Tooltip
    return 0
}

capitalizeFirst(text) {
    firstChar := SubStr(text, 1, 1)
    StringUpper, firstChar, firstChar, T
    return firstChar . SubStr(text, 2)
}


AnyItemsSelected(shopName) {
    global shops
    anyItemsSelected := false
    capitalized := capitalizeFirst(shopName)

    shop := shops[capitalized]

    ; Determine the INI key prefix from the dictionary
    keyPrefix := shopKeys[capitalized]
    if (keyPrefix = "")
    {
        MsgBox, 48, Error, No key mapping found for shop "%capitalized%"
        return false
    }
    anyItemsSelected := false

    ; Loop through the items in the given shop array (e.g., Seeds, Tools, etc.)
    for i, item in shop
    {
        IniRead, checked, %iniFile%, %capitalized%, %keyPrefix%%i%, 0
        if (checked = "1" || checked = 1)
        {
            anyItemsSelected := true
            break
        }
    }

    return anyItemsSelected
}

BuyFromShop(shopName) {
    global doubleScrolls, itemPositions, seeds, gears, iniFile, shops
    global RobloxWindow

    WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
    if !RobloxWindow {
        MsgBox, Roblox window not found!
        return
    }

    ; Navigate to the first item in the shop
    UINavigation("UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUULLLLLLLLLLLLRDUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU")
    Sleep, 100
    ClickRelative(1010, 628, 1)
    Sleep, 1000
    UINavigation("UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUULLLLLLLLLLLLLLRDEE", 0, 0)
    Sleep, 1000

    ; Get shop items and prefix
    if shops.hasKey(shopName) {
        shopItems := shops[shopName]
        section := shopName
        prefix := shopPrefixes[shopName]
    } else {
        MsgBox, Shop name not found: %shopName%
        return
    }

    ; Read selected items from INI
    selectedItems := []
    for i, item in shopItems {
        IniRead, checked, %iniFile%, %section%, %prefix%%i%, 0
        if (checked = "1" || checked = 1) {
            selectedItems.Push(item)
        }
    }

    ; Build name-based lookup map
    selectedNameMap := {}
    for _, item in selectedItems {
        selectedNameMap[item] := true
    }

    ; Loop through shop items
    for index, item in shopItems {
        idx := index + 0

        ; Scroll down if not the first item
        if (idx != 1) {
            Send, {Down}
            Sleep, 500
        }

        UINavigation("E|||||DLL", 1, 0)

        ; Only buy if item is selected
        if selectedNameMap.HasKey(item) {

            Sleep, 100
            buyX := 0
            buyY := 0
            if (FindPixelRelative(0x72FF90, 698, 343, 1244, 910, buyX, buyY, 10)) {
                if (PixelColorFound(0xFFB571, (buyX+68), (buyY-209), (buyX+407), (buyY-56), 10)) {
                    Tooltip, %item% In Stock
                    UINavigation("EEEEEEEEEEEEEEEEEEEEEEEEEEE", 1, 0)
                } else if (PixelColorFound(0xFF7C63, (buyX+68), (buyY-209), (buyX+407), (buyY-56), 10)) {
                    Tooltip, %item% Out of Stock
                    Sleep, 1000
                }
            }
        }

        Sleep, 150
    }

    ; Exit shop
    UINavigation("", 1, 1)
    Sleep, 1000
    ClickRelative(388, 544, 1)
    Sleep, 1000
    ClickRelative(1300, 269, 1)
    Sleep, 1000
    UINavigation("UUUUUUUUUUUUUUUUUUUUUUURRE")

    ; Confirm Roblox window still exists
    WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
    if !RobloxWindow {
        MsgBox, Roblox window not found!
        return
    }

    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 1000
    Return
}

CloseRobuxPrompt() {
    Send, {Esc}
    Sleep, 100
    Send, {Esc}
    Sleep, 1000
}

CheckForUpdate() {
    currentVersion := "Release1.02" ; <-- Set your current version here
    latestURL := "https://api.github.com/repos/DeweyPointJr/Scripter-Garden-Horizons-Macro/releases/latest"

    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", latestURL, false)
    whr.Send()
    whr.WaitForResponse()
    status := whr.Status + 0

    if (status != 200) {
        MsgBox, Failed to fetch release info. Status: %status%
        return
    }

    json := whr.ResponseText
    RegExMatch(json, """tag_name"":\s*""([^""]+)""", m)
    latestVersion := m1

    if (latestVersion = "") {
        MsgBox, Could not find latest version in response.
        return
    }

    if (latestVersion != currentVersion) {
        MsgBox, 4, Update Available, New version %latestVersion% found! Download and install?
        IfMsgBox, Yes
        {
            RegExMatch(json, """zipball_url"":\s*""([^""]+)""", d)
            downloadURL := d1
            if (downloadURL = "") {
                MsgBox, Could not find zipball_url in release JSON.
                return
            }

            whr2 := ComObjCreate("WinHttp.WinHttpRequest.5.1")
            whr2.Open("GET", downloadURL, false)
            whr2.Send()
            whr2.WaitForResponse()
            status2 := whr2.Status + 0

            if (status2 != 200) {
                MsgBox, Failed to download update file. Status: %status2%
                return
            }

            stream := ComObjCreate("ADODB.Stream")
            stream.Type := 1 ; binary
            stream.Open()
            stream.Write(whr2.ResponseBody)
            stream.SaveToFile(A_ScriptDir "\update.zip", 2)
            stream.Close()

            ; Extract the update
            RunWait, %ComSpec% /c powershell -Command "Expand-Archive -Force '%A_ScriptDir%\update.zip' '%A_ScriptDir%'",, Hide

            ; Run updater (it will handle the log and file moves)
            Run, %A_ScriptDir%\update.ahk
            ExitApp
        }
    } else {
        ; On startup, check if update.ahk has a pending replacement
        CheckForUpdatedUpdater()
    }
}

; --- Helper function to replace update.ahk safely ---
CheckForUpdatedUpdater() {
    updateCandidate := A_ScriptDir "\update_files\update.ahk"
    if FileExist(updateCandidate) {
        FileMove, %updateCandidate%, %A_ScriptDir%\update.ahk, 1
        FileRemoveDir, %A_ScriptDir%\update_files, 1
    }
}

Walk(direction, duration, delay := 250) {
    Send, {%direction% down}
    Sleep, %duration%
    Send, {%direction% up}
    Sleep, %delay%
}


CheckForUpdate()

; Show Gui
Gosub, MainGui
return

; MAIN LOOP

MainLoop:
    Gui, Destroy

    WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
    if (RobloxWindow) {
        WinActivate, ahk_id %RobloxWindow%

        ; Roblox is active. Start main macro actions.

        ; Check for reconnect
        global AutoReconnect
        if (AutoReconnect) {
            CheckRobloxStatusFunc()
        }

        ; Start the harvest timer
        SetTimer, AutoHarvestTimer, % (AutoHarvest ? HarvestTime * 60000 : "Off")

        ; Make sure camera is aligned correctly
        Gosub, AutoAlignCameraLabel
        
        ; Check if any seeds are selected (by reading config.ini where SaveSeeds writes them)
        anySeedsSelected := false
        for i, item in seeds {
            IniRead, checked, %iniFile%, Seeds, Seed%i%, 0
            if (checked = "1" || checked = 1) {
                anySeedsSelected := true
                break
            }
        }
        if (anySeedsSelected) {
            Gosub, SeedShopLabel
        }

        ; Check if any gears are selected (by reading config.ini where SaveGears writes them)
        anyGearsSelected := false
        for i, item in gears {
            IniRead, checked, %iniFile%, Gears, Gear%i%, 0
            if (checked = "1" || checked = 1) {
                anyGearsSelected := true
                break
            }
        }
        if (anyGearsSelected) {
            Gosub, GearShopLabel
        }

        if (AutoHarvest && HarvestNow) {
            Gosub, AutoHarvestLabel
        }

        if (AutoBotanist) {
            Gosub, AutoBotanistLabel
        }

         if (AutoSell) {
            Gosub, AutoSellLabel
        }

    } else {
        if (AutoReconnect) {
            CheckRobloxStatusFunc()
        } else {
            MsgBox, Roblox window not found! Please open Roblox.
        }
        
    }

    SetTimer, MainLoop, -1000
Return

; GUI Code

MainGui:
    Gui, Destroy
    Gui, New, +Resize, Scripter Macro

    ; Title label at the top
    Gui, Add, Text, w180 h30 Center vTitleText, Scripter Garden Horizons Macro

    ; Buttons stacked vertically
    Gui, Add, Button, w180 h40 gShopsGui, Shops
    Gui, Add, Button, w180 h40 gSettingsGui, Settings
    Gui, Add, Button, w180 h40 gMainLoop, Start (%StartHotkey%)

    ; Show GUI
    Gui, Show, w200 h200, Scripter Macro
return

ShopsGui:
    Gui, Destroy
    Gui, New, +Resize, Scripter Macro

    ; Buttons stacked vertically
    Gui, Add, Button, w180 h40 gSeedsGui, Seeds
    Gui, Add, Button, w180 h40 gGearsGui, Gears
    Gui, Add, Button, w180 h40 gMainGui, Back

    ; Show GUI
    Gui, Show, w200 h150, Scripter Macro
return

SeedsGui:
    CurrentShop := "Seeds"
    Gosub, ShowShopGui
return

GearsGui:
    CurrentShop := "Gears"
    Gosub, ShowShopGui
return

SettingsGui:
    Gui, Destroy
    Gui, New, +Resize, Settings

    ; Create tab control
    Gui, Add, Tab2, x10 y10 w280 h200, General|Hotkeys|Reconnect

    ; === General Tab ===
    Gui, Add, Text, x20 y50, Auto Align Camera:
    IniRead, AutoAlignCamera, config.ini, Settings, AutoAlignCamera, 1
    Gui, Add, Checkbox, vAutoAlignCamera x120 y50
    GuiControl,, AutoAlignCamera, %AutoAlignCamera%

    Gui, Add, Text, x20 y70, Auto Harvest
    Gui, Add, Checkbox, vAutoHarvest gHarvestCheck x90 y70
    GuiControl,, AutoHarvest, %AutoHarvest%

    ; Hidden text for autoharvest
    Gui, Add, Text, x120 y70 Hidden vHarvestEveryText1, every
    Gui, Add, Edit, x150 y68 w50 h20 Hidden vHarvestTimeEdit, %HarvestTime%
    Gui, Add, Text, x205 y70 Hidden vHarvestEveryText2, minutes

    Gosub, HarvestCheck

    Gui, Add, Text, x20 y90, Auto Sell
    Gui, Add, Checkbox, vAutoSell x70 y90
    GuiControl,, AutoSell, %AutoSell%

    Gui, Add, Text, x20 y110, Auto Botanist
    Gui, Add, Checkbox, vAutoBotanist x90 y110
    GuiControl,, AutoBotanist, %AutoBotanist%

    ; === Hotkeys Tab ===
    Gui, Tab, 2
    Gui, Add, Text, x20 y50, Start Hotkey:
    Gui, Add, Edit, vStartHotkeyEdit x150 y48 w100
    GuiControl,, StartHotkeyEdit, %StartHotkey%

    Gui, Add, Text, x20 y80, Pause Hotkey:
    Gui, Add, Edit, vPauseHotkeyEdit x150 y78 w100
    GuiControl,, PauseHotkeyEdit, %PauseHotkey%

    Gui, Add, Text, x20 y110, Stop Hotkey:
    Gui, Add, Edit, vStopHotkeyEdit x150 y108 w100
    GuiControl,, StopHotkeyEdit, %StopHotkey%

    ; === Reconnect Tab ===
    Gui, Tab, 3
    Gui, Add, Text, x20 y40 w150, VIP Server Link:
    Gui, Add, Edit, x20 y60 w200 h20 vVipLink, %VIP_SERVER_LINK%
    Gui, Add, Text, x20 y90 w120, Auto Reconnect:
    Gui, Add, Checkbox, x110 y92 vAutoReconnect
    Gui, Add, Text, x20 y115 w120, Join Public Server:
    Gui, Add, Checkbox, x110 y117 vJoinPublicServer
    GuiControl,, AutoReconnect, %AutoReconnect%
    GuiControl,, JoinPublicServer, %JoinPublicServer%
    Gui, Add, Button, gReconnectToGame x20 y145 w80 h30, Test Reconnect

    ; === Save Button ===
    Gui, Tab  ; Ends tab section
    Gui, Add, Button, gSaveSettings x100 y220 w100 h30, Save

    Gui, Show, w300 h260, Settings
return

SaveSettings:
    Gui, Submit, NoHide

    ; Save general to INI
    IniWrite, %AutoAlignCamera%, config.ini, Settings, AutoAlignCamera
    IniWrite, %AutoHarvest%, config.ini, Settings, AutoHarvest
    IniWrite, %HarvestTimeEdit%, config.ini, Settings, HarvestTime
    IniWrite, %AutoSell%, config.ini, Settings, AutoSell
    IniWrite, %AutoBotanist%, config.ini, Settings, AutoBotanist

    ; Save hotkeys to INI
    IniWrite, %StartHotkeyEdit%, config.ini, Settings, StartHotkey
    IniWrite, %PauseHotkeyEdit%, config.ini, Settings, PauseHotkey
    IniWrite, %StopHotkeyEdit%, config.ini, Settings, StopHotkey

    ; Save Reconnect Settings
    IniWrite, %VipLink%, config.ini, Settings, VipServerLink
    IniWrite, %AutoReconnect%, config.ini, Settings, AutoReconnect
    IniWrite, %JoinPublicServer%, config.ini, Settings, JoinPublicServer

    Reload ; hotkey changes take effect
Return

HarvestCheck:
    Gui, Submit, NoHide
    if (AutoHarvest) {
        GuiControl, Show, HarvestEveryText1
        GuiControl, Show, HarvestTimeEdit
        GuiControl, Show, HarvestEveryText2
    } else {
        GuiControl, Hide, HarvestEveryText1
        GuiControl, Hide, HarvestTimeEdit
        GuiControl, Hide, HarvestEveryText2
    }
Return

; Closing GUI exits macro
GuiClose:
    ExitApp
Return

; Hotkey Labels
StartHotkeyLabel() {
    Gui, Submit
    if (AutoHarvest && AutoReconnect == false) {
        MsgBox, Warning: Auto Harvest is enabled without Auto Reconnect. The macro needs to know which plot you are in to be able to harvest. Please enable Auto Reconnect.
        Reload
    }
    Gosub, MainLoop
}

PauseHotkeyLabel() {
    Pause
}

StopHotkeyLabel() {
    Reload
}

; Positioning Labels
SetBackpackPos:
    MsgBox, 64, Backpack Setup, Click where your backpack button is located.
    Gui, Hide
    ; Wait for left click
    KeyWait, LButton, D
    MouseGetPos, backpackBtnX, backpackBtnY
    MsgBox, 64, Backpack Setup, Backpack button set at X %backpackBtnX% Y %backpackBtnY%

    ; Save the location
    IniWrite, %backpackBtnX%, %iniFile%, Settings, backpackBtnX
    IniWrite, %backpackBtnY%, %iniFile%, Settings, backpackBtnY
    Gui, Show
Return

; Action Labels

ClearTooltip:
    Tooltip,
Return

SeedShopLabel:
    Tooltip, Buying Seeds
    SetTimer, ClearTooltip, -1500
    ClickRelative(679, 139, 1)
    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 1000
    Send, {e}
    Sleep, 5000
    if PixelColorFound(0x0F693E, 988, 239, 1146, 320, 10) {
        ToolTip, Seed Shop Opened
        SEEDERRORS := 0
        SetTimer, ClearTooltip, -1500
        Sleep, 1000
        BuyFromShop("Seeds")
        Tooltip, Seeds Completed
        Sleep, 1000
        Gosub, ClearTooltip
        Sleep, 1000
        ClickRelative(1298, 264, 1)
        Sleep, 1000
        CloseRobuxPrompt()
    } else {
        Tooltip, ERROR: Seed Shop Not Opening
        SEEDERRORS += 1
        if (SEEDERRORS >= 3) {
            SEEDERRORS := 0
            GEARERRORS := 0
            ALIGNERRORS := 0
            Sleep, 1000
            ReconnectToGame()
        }
    }
    
Return

GearShopLabel:
    Tooltip, Buying Gears
    SetTimer, ClearTooltip, -1500
    ;Walk to gear shop
    ClickRelative(679, 139, 1)
    Sleep, 1000
    Send, {s down}
    Sleep, 1000
    Send, {s up}
    Sleep, 500
    Send, {d down}
    Sleep, 2750
    Send, {d up}
    Sleep, 500
    Send, {s down}
    Sleep, 1000
    Send, {s up}
    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 1000
    Send, {e}
    Sleep, 5000
    if PixelColorFound(0x7586AF, 675, 185, 1261, 340, 10) {
        ToolTip, Gear Shop Opened
        GEARERRORS := 0
        SetTimer, ClearTooltip, -1500
        Sleep, 1000
        BuyFromShop("Gears")
        Tooltip, Gears Completed
        Sleep, 1000
        Gosub, ClearTooltip
    } else {
        Tooltip, ERROR: Gear Shop Not Opening
        GEARERRORS += 1
        if (GEARERRORS >= 3) {
            GEARERRORS := 0
            SEEDERRORS := 0
            ALIGNERRORS := 0
            Sleep, 1000
            ReconnectToGame()
        }
    }
    Sleep, 1000
    ClickRelative(1298, 264, 1)
    Sleep, 1000
    CloseRobuxPrompt()
Return

AutoAlignCameraLabel:
    alignmentFailed := 0
    Tooltip, Aligning Camera
    SetTimer, ClearTooltip, -1500
    ; First zoom alignment
    Loop, 25 {
        Send, {WheelUp}
        Sleep, 30
    }
    Sleep, 1000
    Loop, 6 {
        Send, {WheelDown}
        Sleep, 30
    }
    Sleep, 1000

    ; Next, put the camera into a top-down view
    ClickRelative(0.5, .4)
    Sleep, 500
    Click, Right, Down
    Sleep, 250
    ClickRelative(0.5, 0.8)
    Sleep, 250
    Click, Right, Up
    Sleep, 1000

    ; Last align the camera through the shops
    IniRead, AutoAlignCamera, config.ini, Settings, AutoAlignCamera
    if (AutoAlignCamera) {
        SetCameraMode(3)

        ; Teleport to shops
        Loop, 4 {
            ClickRelative(679, 139, 1)
            Sleep, 500
            ClickRelative(1250, 137, 1)
            Sleep, 500

        }
        Sleep, 1000
        ; Change camera back
        SetCameraMode(1)
        if (PixelColorFound(0xFFE304, 551, 141, 775, 290, 50)) {
            Tooltip, Camera Alignment Successful
        } else {
             Tooltip, Camera Alignment Failed
             alignmentFailed := 1
             ALIGNERRORS += 1
             if (ALIGNERRORS >= 3) {
                    ALIGNERRORS := 0
                    SEEDERRORS := 0
                    GEARERRORS := 0
                    Sleep, 1000
                    ReconnectToGame()
             }
        }
        Sleep, 1000
        Gosub, ClearTooltip
        if (alignmentFailed) {
            Gosub, AutoAlignCameraLabel
        }
    }

Return

DynamicDone:
    global CurrentShop, shops, shopKeys, iniFile

    if (CurrentShop = "" || !shops.HasKey(CurrentShop)) {
        MsgBox, 48, Warning, No shop is currently open or invalid!
        return
    }

    shopItems := shops[CurrentShop]       ; array of items
    keyPrefix := shopKeys[CurrentShop]    ; prefix for INI keys

    ; Loop through items and save checkbox states
    for i, item in shopItems {
        controlVar := keyPrefix . "_" . i    ; must match vVariable of the checkbox
        
        GuiControlGet, checked, , %controlVar%
        if (checked = "")                  ; ensure unchecked boxes are saved as 0
            checked := 0

        iniKey := keyPrefix . i            ; desired INI key format: Egg1, Egg2, etc.
        IniWrite, %checked%, %iniFile%, %CurrentShop%, %iniKey%
    }

    CurrentShop := ""                      ; reset after saving
    Gosub, MainGui                         ; return to main GUI
Return

ShowShopGui:
    global shopKeys, shopPrefixes, shops, CurrentShop, iniFile

    shopName := CurrentShop
    if (shopName = "" || !shops.HasKey(shopName)) {
        MsgBox, 48, Error, ShowShopGui called with invalid shop name: "%shopName%"
        return
    }

    capitalized := shopName
    keyPrefix := shopKeys[capitalized]
    if (keyPrefix = "") {
        MsgBox, 48, Error, No key mapping found for shop "%capitalized%"
        return
    }

    shopItems := shops[shopName]

    Gui, Destroy
    Gui, New, +Resize, %capitalized% Selection

    xOffset := 10
    yOffset := 10
    spacingX := 150
    spacingY := 30
    perColumn := 15

    Count := shopItems.MaxIndex()
    if (Count = "")
        Count := 0

    ; Add checkboxes dynamically
    for i, item in shopItems {
        col := Floor((i - 1) / perColumn)
        row := Mod(i - 1, perColumn)
        xPos := xOffset + (col * spacingX)
        yPos := yOffset + (row * spacingY)

        IniRead, checked, %iniFile%, %capitalized%, %keyPrefix%%i%, 0
        ctrlName := keyPrefix . "_" . i
        Gui, Add, Checkbox, v%ctrlName% x%xPos% y%yPos% w140 h25, %item%
        GuiControl,, %ctrlName%, %checked%
    }

    ; Calculate GUI size
    totalCols := Floor((Count - 1) / perColumn) + 1
    totalRows := (Count < perColumn) ? Count : perColumn
    buttonWidth := 100
    buttonSpacing := 20
    buttonsTotalWidth := (buttonWidth * 2) + buttonSpacing
    minWidthForButtons := buttonsTotalWidth + 40  ; extra padding
    calculatedWidth := xOffset + (totalCols * spacingX) + 20
    totalWidth := (calculatedWidth < minWidthForButtons) ? minWidthForButtons : calculatedWidth
    totalHeight := yOffset + (totalRows * spacingY) + 60

    ; Center buttons horizontally
    buttonsTotalWidth := (buttonWidth * 2) + buttonSpacing
    buttonsStartX := (totalWidth - buttonsTotalWidth) / 2
    buttonY := yOffset + (totalRows * spacingY) + 10

    ; Select All/None button
    Gui, Add, Button, x%buttonsStartX% y%buttonY% w%buttonWidth% h30 gToggleSelectAll vSelectAllButton, Select All

    ; Done button
    doneX := buttonsStartX + buttonWidth + buttonSpacing
    Gui, Add, Button, x%doneX% y%buttonY% w%buttonWidth% h30 gDynamicDone, Done

    ; Determine initial Select All/None button label
    allInitiallyChecked := true
    Loop, % Count {
        ctrlName := keyPrefix . "_" . A_Index
        GuiControlGet, state, , %ctrlName%
        if (!state) {
            allInitiallyChecked := false
            break
        }
    }
    initialLabel := allInitiallyChecked ? "Select None" : "Select All"
    GuiControl,, SelectAllButton, %initialLabel%
    
    ; Show GUI after setting correct button label
    Gui, Show, w%totalWidth% h%totalHeight%, %capitalized% Selection
Return

ToggleSelectAll:
    allChecked := true
    Loop, % Count {
        ctrlName := keyPrefix . "_" . A_Index
        GuiControlGet, state, , %ctrlName%
        if (!state) {
            allChecked := false
            break
        }
    }

    newState := allChecked ? 0 : 1
    Loop, % Count {
        ctrlName := keyPrefix . "_" . A_Index
        GuiControl,, %ctrlName%, %newState%
    }

    newLabel := allChecked ? "Select All" : "Select None"
    GuiControl,, SelectAllButton, %newLabel%
Return

AutoHarvestTimer:
    global HarvestNow := true
Return

ResetCharacter:
    Send, {Esc}
    Sleep, 500
    Send, R
    Sleep, 250
    Send, {Enter}
    Sleep, 4000
Return

AutoHarvestLabel:
    Tooltip, Auto Harvesting. Reconnecting to Reset Camera...
    Sleep, 2000

    ReconnectToGame()

    ; Set camera to top-down view
    ClickRelative(0.5, .4)
    Sleep, 500
    Click, Right, Down
    Sleep, 250
    ClickRelative(0.5, 0.8)
    Sleep, 250
    Click, Right, Up
    Sleep, 1000

    ; Zoom out
    Loop, 25 {
        Send, {WheelDown}
        Sleep, 30
    }

    Tooltip, Harvesting Left Side
    SetTimer, ClearTooltip, -1500

    ClickRelative(0.5, 0.5)

    ; Harvest Left Side
    Walk("w", 500)
    Walk("a", 1000)

    Walk("e", 5000)

    Walk("a", 1000)

    Walk("e", 5000)

    Walk("a", 500)
    Walk("w", 500)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 350)
    Walk("d", 1000)

    Walk("e", 5000)

    Walk("d", 1000)

    Walk("e", 5000)

    Tooltip, Left Side Complete
    SetTimer, ClearTooltip, -1500
    Sleep, 1500

    ClickRelative(961, 137, 1)
    Sleep, 1000

    Tooltip, Harvesting Right Side
    SetTimer, ClearTooltip, -1500

    ; Harvest Right Side
    Walk("w", 500)
    Walk("d", 1000)

    Walk("e", 5000)

    Walk("d", 1000)

    Walk("e", 5000)

    Walk("d", 500)
    Walk("w", 500)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 350)
    Walk("a", 1000)

    Walk("e", 5000)

    Walk("a", 1000)

    Walk("e", 5000)

    Tooltip, Right Side Complete
    SetTimer, ClearTooltip, -1500
    Sleep, 1000

    ClickRelative(961, 137, 1)
    Sleep, 1000

    Tooltip, Harvesting Middle
    SetTimer, ClearTooltip, -1500

    ; Harvest Middle
    
    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Walk("w", 1000)

    Walk("e", 5000)

    Sleep, 1000

    Tooltip, Middle Complete. Realigning Camera.
    Sleep, 1000
    Gosub, AutoAlignCameraLabel

Return

AutoBotanistLabel:
    Tooltip, Donating Plants to Botanist
    SetTimer, ClearTooltip, -1500
    ;Walk to botanist
    ClickRelative(679, 139, 1)
    Sleep, 1000
    Send, {s down}
    Sleep, 1000
    Send, {s up}
    Sleep, 500
    Send, {d down}
    Sleep, 2000
    Send, {d up}
    Sleep, 500
    Send, {s down}
    Sleep, 1000
    Send, {s up}
    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 1000
    Send, {e}
    Sleep, 5000
    ClickRelative(1404, 660, 1)
    Sleep, 10000
    CloseRobuxPrompt()
Return

AutoSellLabel:
    Tooltip, Selling Plants
    SetTimer, ClearTooltip, -1500

    ClickRelative(1250, 137, 1)
    Sleep, 2000
    Send, {e}
    Sleep, 5000
    ClickRelative(1391, 553, 1)
    Sleep, 10000
Return