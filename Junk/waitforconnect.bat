@echo off
echo "Attempting to detect if client has connected..."

:scstart
for /f "tokens=*" %%a in (
'find /c "initialising desktop handler" "WinVNC.log"'
) do (
set myvar=%%a
)
rem echo/%%myvar%%=%myvar%

Set _endbit=%myvar:*1=1%
SET _result=%_endbit:~0,1%
IF %_result% EQU 1 GOTO scend
GOTO scstart

:scend
echo "Found!"