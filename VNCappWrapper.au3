#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.4.0
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

HotKeySet('!^{END}', 'AdminLogin') ; AdminLogin allows us to do close the program and do other stuff

; If the process exits prematurely, try to clean things up
OnAutoItExitRegister("KillAll")

; Use WinLock DLL to disable Ctrl-Alt-Del, Windows keys and Alt-Tab
$d_WinLock = DllOpen(@ScriptDir & "\WinLockDll.dll")
DllCall($d_WinLock, "int","CtrlAltDel_Enable_Disable", "boolean", False)
If @error Then MsgBox(0,"DLLerror-CAD", @error)
DllCall($d_WinLock, "int","Keys_Enable_Disable", "boolean", False)
If @error Then MsgBox(0,"DLLerror-Keys", @error)
DllCall($d_WinLock, "int","AltTab1_Enable_Disable", "boolean", False)
If @error Then MsgBox(0,"DLLerror-AltTab", @error)
;DllCall($d_WinLock, "int","AltTab1_Enable_Disable", "int", 0, "boolean", False)
If @error Then MsgBox(0,"DLLerror-AltTab", @error)

$s_ProgWindow = IniRead(@ScriptDir & "\VNCappWrapper.ini", "App", "WindowName", "")
If $s_ProgWindow = "" And MsgBox(0, "Error", "VNCappWrapper.ini not found") Then Exit

$s_App = IniRead(@ScriptDir & "\VNCappWrapper.ini", "App", "Path", "")
If $s_App = "" And MsgBox(0, "Error", "VNCappWrapper.ini not found") Then Exit

$as_AllowedWindows = IniReadSection(@ScriptDir & "\VNCappWrapper.ini", "AllowedWindows")

While 1
	; VNC can take a while to shut down and release the file handle to the log file...
	Do
		FileDelete(@ScriptDir & "\WinVNC.log")
	Until Not @error And Not FileExists(@ScriptDir & "\WinVNC.log")
	FileWrite(@ScriptDir & "\WinVNC.log", "***New Instance!***")

	; Get VNC running
	Run(@ScriptDir & "\winvnc.exe")

	; Just gives some screen feedback to the admin...
	ProgressOn("VNCappWrapper", "Waiting for user to log in to VNC...")

	; This is our hacky way of testing if a user logged in
	; The file handle is open in VNC, so we can't just use FileRead
	; We use FileReadEx, which uses the FileSystemObject to read text files
	Do
		$s_Log = FileReadEx(@ScriptDir & "\WinVNC.log")
		If @error Then MsgBox(0,"ReadFileEx Error Before Connect", @error)
		Sleep(150)
	Until StringInStr($s_Log, "initialising desktop handler")

	ProgressOff()

	; Run our kiosk app
	$i_Pid = Run($s_App)

	; Wait until the app is opened, then activate it, set it on top and make it fill the screen
	WinWait($s_ProgWindow)
	WinActivate($s_ProgWindow)
	WinSetOnTop($s_ProgWindow, "", 1)
	WinMove($s_ProgWindow,"",0,0, @DesktopWidth, @DesktopHeight)

	Do
		; We need to check for changes again
		$s_Log = FileReadEx(@ScriptDir & "\WinVNC.log")
		If @error Then MsgBox(0,"ReadFileEx Error After Connect", @error)

		; Make the program use up the whole screen, and disallow focus switching
		WinMove($s_ProgWindow,"",0,0, @DesktopWidth, @DesktopHeight)

		; This is our new code to determine if a window is allowed to be focuses on or not
		$b_Allowed = False

		; $b_Allowed will be set to True if the window is in our list of allowed window names
		For $o = 1 to $as_AllowedWindows[0][0]
			If WinActive($as_AllowedWindows[$o][1]) Then
				$b_Allowed = True
			EndIf
		Next

		; We also need to allow admin login and the main app
		If WinActive("Admin Login") Then
			$b_Allowed = True
		ElseIf WinActive($s_ProgWindow) Then
			$b_Allowed = True
		EndIf

		If $b_Allowed = False Then
			WinActivate($s_ProgWindow) ; If they aren't focused on the app, send them back to it
		EndIf
		; Keep this going until they close the kiosk program or they close WinVNC
		Sleep(150)
	Until Not WinExists($s_ProgWindow) Or StringInStr($s_Log, 'vncserver.cpp : desktop deleted')

	; Clean up our temporary files and strings
	$s_Log = ''

	; Give us a little bit of time (200ms)
	Sleep(200)

	; Close the kiosk program
	If ProcessExists($i_Pid) Then ProcessClose($i_Pid)

	; Close down VNC, terminating any user sessions and releasing the file handle
	ProcessClose("winvnc.exe")
	ProcessWaitClose("winvnc.exe")
	Sleep(200)
WEnd

; Reads a text file, even if the file is already in use
Func FileReadEx($sFilename)
	$oFS = ObjCreate("Scripting.FileSystemObject")
	$oText = $oFS.OpenTextFile($sFilename,1)
	If @error Then Return
	$sFileContents = $oText.ReadAll
	If @error Then Return
	$oText.Close
	Return $sFileContents
EndFunc

Func KillAll()
	Do
		ProcessClose("winvnc.exe")
	Until Not ProcessExists("winvnc.exe")
	Do
		ProcessClose("cmd.exe")
	Until Not ProcessExists("cmd.exe")
	Do
		ProcessClose("st32w.exe")
	Until Not ProcessExists("st32w.exe")
	DllClose($d_WinLock)
EndFunc

Func AdminLogin()
	If InputBox("Admin Login", "Enter the admin password:", "", "*") = "administrator" Then
		KillAll()
		Run("explorer.exe")
		Exit
	EndIf
EndFunc