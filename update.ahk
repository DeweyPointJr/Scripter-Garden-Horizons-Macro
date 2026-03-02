#NoEnv
SetWorkingDir %A_ScriptDir%
Sleep, 1000

; Find extracted folder
newestTime := 0
extractedDir := ""
Loop, Files, %A_ScriptDir%\*.*, D
{
    if InStr(A_LoopFileName, "Scripter-Garden-Horizons-Macro") {
        if (A_LoopFileTimeCreated > newestTime) {
            newestTime := A_LoopFileTimeCreated
            extractedDir := A_LoopFileFullPath
        }
    }
}

if (extractedDir != "") {
    ; Move all non-update files up one level
    Loop, Files, %extractedDir%\*.*, F
    {
        if (A_LoopFileName != "update.ahk" && A_LoopFileName != "config.ini") {
            FileMove, %A_LoopFileFullPath%, %A_ScriptDir%\%A_LoopFileName%, 1
        }
    }

    ; Move all folders up one level
    Loop, Files, %extractedDir%\*.*, D
    {
        FileMoveDir, %A_LoopFileFullPath%, %A_ScriptDir%\%A_LoopFileName%, 1
    }

    ; If there's a new update.ahk, move it to a staging folder
    if FileExist(extractedDir "\update.ahk") {
        FileCreateDir, %A_ScriptDir%\update_files
        FileMove, %extractedDir%\update.ahk, %A_ScriptDir%\update_files\update.ahk, 1
    }

    ; Show update log if available
    logFile := extractedDir "\updatelog.txt"
    if !FileExist(logFile)
        logFile := A_ScriptDir "\updatelog.txt"

    if FileExist(logFile) {
        FileRead, updateLog, %logFile%
        if (updateLog != "")
            MsgBox, 64, Update Log, %updateLog%
    }

    FileRemoveDir, %extractedDir%, 1
}

; Cleanup
FileDelete, %A_ScriptDir%\update.zip

; Relaunch main macro
Run, %A_ScriptDir%\Macro.ahk
ExitApp
