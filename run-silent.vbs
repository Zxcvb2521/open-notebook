Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
WshShell.CurrentDirectory = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & fso.GetParentFolderName(WScript.ScriptFullName) & "\launch.ps1"" -ProjectRoot """ & fso.GetParentFolderName(WScript.ScriptFullName) & """", 0, False
Set WshShell = Nothing
