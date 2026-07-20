Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
WshShell.CurrentDirectory = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.Run "cmd.exe /c """ & fso.GetParentFolderName(WScript.ScriptFullName) & "\run-silent.bat""", 0, False
Set WshShell = Nothing
