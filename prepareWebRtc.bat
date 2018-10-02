:: Name:     prepareWebRtc.bat
:: Purpose:  Prepare webrtc to be buildable
:: Author:   Sergej Jovanovic
:: Email:	 sergej@gnedo.com
:: Revision: September 2016 - initial version

@ECHO off

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set powershell_path=%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe
set taskFailed=0

::platforms

SET platform_winuwp=0
SET platform_win32=0

SET cpu_arm=0
SET cpu_x86=0
SET cpu_x64=0

SET CONFIG_debug=0
SET CONFIG_release=0

SET platform_winuwp_cpu_arm_prepared=0
SET platform_winuwp_cpu_x86_prepared=0
SET platform_winuwp_cpu_x64_prepared=0

SET platform_win32_cpu_x86_prepared=0
SET platform_win32_cpu_x64_prepared=0

::log variables
SET globalLogLevel=2											

SET error=0														
SET info=1														
SET warning=2													
SET debug=3														
SET trace=4	

::input arguments
SET supportedInputArguments=;platform;cpu;config;help;logLevel;diagnostic;target;			
SET platform=all
SET help=0
SET logLevel=2
SET diagnostic=0
SET target=webrtc
SET cpu=all
SET config=all

::predefined messages
SET folderStructureError="WebRTC invalid folder structure."
SET errorMessageInvalidArgument="Invalid input argument. For the list of available arguments and usage examples, please run script with -help option."
SET errorMessageInvalidPlatform="Invalid platform name. For the list of available targets and usage examples, please run script with -help option."
SET errorMessageInvalidCpu="Invalid cpu name. For the list of available targets and usage examples, please run script with -help option."
SET errorMessageInvalidConfig="Invalid config name. For the list of available targets and usage examples, please run script with -help option."
SET errorMessageMissingDebuggerTools="Windows SDK is not fully installed. Debugger Tools are missing. Please install standalone Windows SDK version. You can download installer from this link https://developer.microsoft.com/de-de/windows/downloads/sdk-archive"

::path constants
SET baseWebRTCPath=webrtc\xplatform\webrtc
SET webRtcLibsTemplatePath=webrtc\windows\templates\libs\webrtc
SET webRtcx64TemplatePath=webrtc\windows\templates\libs\webrtc\WebRtc.x64.sln
SET webRtcx86TemplatePath=webrtc\windows\templates\libs\webrtc\WebRtc.x86.sln
rem SET webRTCDestinationPath=webrtc\xplatform\webrtc\webrtcLib.sln

SET webRTCGnArgsTemplatePath=..\..\..\webrtc\windows\templates\gns\args.gn

SET stringToUpdateWithSDKVersion='WindowsTargetPlatformVersion', '10.0.10240.0'
SET pythonFilePathToUpdateSDKVersion=webrtc\xplatform\webrtc\tools\gyp\pylib\gyp\generator\msvs.py

SET lastChangeScriptPath=build\util

ECHO.
CALL:print %info% "Running WebRTC prepare script ..."
CALL:print %info% "================================="
::ECHO.

:parseInputArguments
IF "%1"=="" (
	IF NOT "%nome%"=="" (
		SET "%nome%=1"
		SET nome=""
		
	) ELSE (
		GOTO:main
	)
)
SET aux=%1
IF "%aux:~0,1%"=="-" (
	IF NOT "%nome%"=="" (
		SET "%nome%=1"
	)
   SET nome=%aux:~1,250%
   SET validArgument=0
   CALL:checkIfArgumentIsValid !nome! validArgument
   IF !validArgument!==0 CALL:error 1 %errorMessageInvalidArgument%
) ELSE (
	IF NOT "%nome%"=="" (
		SET "%nome%=%1"
	) else (
		CALL:error 1 %errorMessageInvalidArgument%
	)
   SET nome=
)

SHIFT
GOTO parseInputArguments

::===========================================================================
:: Start execution of main flow (if parsing input parameters passed without issues)

:main

CALL:showHelp

CALL:identifyPlatform

CALL:identifyCpu

CALL:identifyConfig

CALL:prepareWebRTC

GOTO:EOF

::===========================================================================

REM check if entered valid input argument
:checkIfArgumentIsValid
IF "!supportedInputArguments:;%~1;=!" neq "%supportedInputArguments%" (
	::it is valid
	SET %2=1
) ELSE (
	::it is not valid
	SET %2=0
)
GOTO:EOF


:showHelp
IF %help% EQU 0 GOTO:EOF

ECHO.
ECHO    [92mAvailable parameters:[0m
ECHO.
ECHO 	[93m-help[0m 		Show script usage
ECHO.
ECHO 	[93m-logLevel[0m	Log level (error=0, info =1, warning=2, debug=3, trace=4)
ECHO.
ECHO 	[93m-target[0m		Name of the target to prepare environment for. Ortc or WebRtc. If this parameter is not set dev environment will be prepared for both available targets.
ECHO.
ECHO		[93m-platform[0m 	Platform name to set environment for. Default is All (winuwp,win32)
ECHO.
ECHO		[93m-cpu[0m 	Cpu name to set environment for. Default is All (arm,x86,x64)
ECHO.
CALL bin\batchTerminator.bat

GOTO:EOF

REM Based on input arguments determine targeted platforms (Win32/WinUWP)
:identifyPlatform
SET validInput=0
SET messageText=

IF /I "%platform%"=="all" (
	SET platform_winuwp=1
	SET platform_win32=1
	SET validInput=1
	SET messageText=Preparing WebRTC development environment for WinUWP and win32 platforms ...
) ELSE (
	IF /I "%platform%"=="winuwp" (
		SET platform_winuwp=1
		SET validInput=1
	)
	
	IF /I "%platform%"=="win32" (
		SET platform_win32=1
		SET validInput=1
	)
	
	IF !validInput!==1 (
		SET messageText=Preparing WebRTC development environment for %platform% platform ...
	)
)

:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidPlatform%
)
GOTO:EOF

REM Based on input arguments determine targeted cpu (arm/x86,x64)
:identifyCpu
SET validInput=0
SET messageText=

IF /I "%cpu%"=="all" (
	SET cpu_arm=1
	SET cpu_x86=1
	SET cpu_x64=1
	SET validInput=1
	SET messageText=Preparing WebRTC development environment for arm, x86, x64 cpus ...
) ELSE (
	IF /I "%cpu%"=="arm" (
		IF /I "%platform%"=="win32" (
			CALL:print %warning% "Win32 ARM is not a valid target thus assuming an x86 cpu ..."
			SET cpu_x86=1
			SET validInput=1
		) ELSE (
			SET cpu_arm=1
			SET validInput=1
		)
	)
	
	IF /I "%cpu%"=="x86" (
		SET cpu_x86=1
		SET validInput=1
	)
	
	IF /I "%cpu%"=="x64" (
		SET cpu_x64=1
		SET validInput=1
	)
	
	IF !validInput!==1 (
		SET messageText=Preparing WebRTC development environment for %cpu% cpu ...
	)
)

:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidCpu%
)
GOTO:EOF


REM Based on input arguments determine targeted cpu (debug/release)
:identifyConfig
SET validInput=0
SET messageText=

IF /I "%config%"=="all" (
	SET CONFIG_debug=1
	SET CONFIG_release=1
	SET validInput=1
	SET messageText=Preparing WebRTC development environment for debug and release configurations ...
) ELSE (

	IF /I "%config%"=="debug" (
		SET CONFIG_debug=1
		SET validInput=1
	)
	
	IF /I "%config%"=="release" (
		SET CONFIG_release=1
		SET validInput=1
	)
	
	IF !validInput!==1 (
		SET messageText=Preparing WebRTC development environment for %config% configuration ...
	)
)

:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidConfig%
)
GOTO:EOF

:prepareWebRTC
CALL:print %trace% "Executing prepareWebRTC function"

IF NOT EXIST %baseWebRTCPath% CALL:error 1 "%folderStructureError:"=% %baseWebRTCPath% does not exist!"



PUSHD %baseWebRTCPath% > NUL
CALL:print %trace% "Pushed %baseWebRTCPath% path"

CALL:generateChromiumFolders

CALL:makeJunctionLinks

CALL:updateFolders

IF %platform_win32% EQU 1 (
	IF %cpu_x64% EQU 1 (
    CALL:updateClang
  )
)

CALL:setupDepotTools

CALL:fixLastChange

CALL:downloadGnBinaries
::POPD
::CALL:updateSDKVersion
::PUSHD %baseWebRTCPath% > NUL

::CALL:gflagsPatchBuild
CALL:generateProjects

POPD
CALL:print %trace% "Popped %baseWebRTCPath% path"

rem CALL:copyTemplates %webRTCTemplatePath% %webRTCDestinationPath%

CALL:done

GOTO:EOF

:generateChromiumFolders
CALL:print %trace% "Executing generateChromiumFolders function"

CALL:makeDirectory chromium\src
CALL:makeDirectory chromium\src\tools
CALL:makeDirectory chromium\src\third_party
CALL:makeDirectory chromium\src\third_party\winsdk_samples
CALL:makeDirectory chromium\src\third_party\libjingle\source\talk\media\testdata\
CALL:makeDirectory third_party
CALL:makeDirectory tools

GOTO:EOF

:makeJunctionLinks
CALL:print %trace% "Executing makeJunctionLinks function"

CALL:makeLink . buildtools ..\buildtools
CALL:makeLink . build ..\chromium\build
CALL:makeLink . chromium\src\third_party\abseil-cpp ..\chromium\third_party\abseil-cpp
CALL:makeLink . chromium\src\third_party\jsoncpp ..\chromium\third_party\jsoncpp
CALL:makeLink . chromium\src\third_party\jsoncpp\source ..\jsoncpp
CALL:makeLink . chromium\src\tools\protoc_wrapper ..\chromium\tools\protoc_wrapper
CALL:makeLink . chromium\src\third_party\protobuf ..\chromium\third_party\protobuf
CALL:makeLink . chromium\src\third_party\yasm ..\chromium\third_party\yasm
CALL:makeLink . chromium\src\third_party\opus ..\chromium\third_party\opus
CALL:makeLink . chromium\src\third_party\boringssl ..\chromium\third_party\boringssl
CALL:makeLink . chromium\src\third_party\usrsctp ..\chromium\third_party\usrsctp
CALL:makeLink . chromium\src\third_party\libvpx ..\chromium\third_party\libvpx
CALL:makeLink . chromium\src\third_party\libvpx\source\libvpx ..\libvpx
CALL:makeLink . chromium\src\third_party\rnnoise ..\chromium\third_party\rnnoise
CALL:makeLink . chromium\src\testing ..\chromium\testing
CALL:makeLink . testing chromium\src\testing
CALL:makeLink . base ..\chromium\base
CALL:makeLink . tools\protoc_wrapper chromium\src\tools\protoc_wrapper
CALL:makeLink . third_party\yasm chromium\src\third_party\yasm
CALL:makeLink . third_party\yasm\binaries ..\yasm\binaries
CALL:makeLink . third_party\yasm\source\patched-yasm ..\yasm\patched-yasm
CALL:makeLink . third_party\opus chromium\src\third_party\opus
CALL:makeLink . third_party\opus\src ..\opus
CALL:makeLink . third_party\boringssl chromium\src\third_party\boringssl
CALL:makeLink . third_party\boringssl\src ..\boringssl
CALL:makeLink . third_party\usrsctp chromium\src\third_party\usrsctp
CALL:makeLink . third_party\usrsctp\usrsctplib ..\usrsctp
CALL:makeLink . third_party\protobuf chromium\src\third_party\protobuf
CALL:makeLink . chromium\src\third_party\expat ..\chromium\third_party\expat
CALL:makeLink . third_party\expat chromium\src\third_party\expat
CALL:makeLink . chromium\src\third_party\googletest ..\chromium\third_party\googletest
CALL:makeLink . third_party\googletest chromium\src\third_party\googletest
CALL:makeLink . third_party\googletest\src ..\googletest
CALL:makeLink . third_party\libsrtp ..\libsrtp
CALL:makeLink . third_party\libvpx .\chromium\src\third_party\libvpx
CALL:makeLink . third_party\libyuv ..\libyuv
CALL:makeLink . third_party\openmax_dl ..\openmax
CALL:makeLink . third_party\libjpeg_turbo ..\libjpeg_turbo
CALL:makeLink . third_party\abseil-cpp chromium\src\third_party\abseil-cpp
CALL:makeLink . third_party\rnnoise chromium\src\third_party\rnnoise
CALL:makeLink . third_party\jsoncpp chromium\src\third_party\jsoncpp
CALL:makeLink . third_party\winuwp_compat ..\..\windows\third_party\winuwp_compat
CALL:makeLink . third_party\winuwp_h264 ..\..\windows\third_party\winuwp_h264
CALL:makeLink . third_party\gflags ..\gflags-build
CALL:makeLink . third_party\gflags\src ..\gflags
CALL:makeLink . third_party\winsdk_samples ..\winsdk_samples_v71
CALL:makeLink . tools\gyp ..\gyp
CALL:makeLink . tools\clang ..\chromium\tools\clang
CALL:makeLink . third_party\harfbuzz-ng ..\chromium\third_party\harfbuzz-ng
CALL:makeLink . third_party\freetype ..\chromium\third_party\freetype
CALL:makeLink . third_party\zlib ..\chromium\third_party\zlib
CALL:makeLink . third_party\libpng ..\chromium\third_party\libpng
CALL:makeLink . third_party\icu ..\icu

REM wrapper generation dependency libraries

CALL:makeDirectory third_party\idl

CALL:makeLink . third_party\idl\cryptopp ..\cryptopp
CALL:makeLink . third_party\idl\zsLib ..\zsLib
CALL:makeLink . third_party\idl\zsLib-eventing ..\zsLib-eventing
CALL:makeLink . sdk\windows ..\webrtc-apis\windows
CALL:makeLink . sdk\idl ..\webrtc-apis\idl

IF /I "%target%"=="ortc" (
	CALL:makeDirectory third_party\ortc
	CALL:makeLink . third_party\ortc\udns ..\..\..\ortc\xplatform\udns
  CALL:makeLink . third_party\ortc\idnkit ..\..\..\ortc\xplatform\idnkit
	CALL:makeLink . third_party\ortc\ortclib ..\..\..\ortc\xplatform\ortclib-cpp
	CALL:makeLink . third_party\ortc\ortclib-services ..\..\..\ortc\xplatform\ortclib-services-cpp
)

GOTO:EOF


:updateFolders

::XCopy  /S /I /Y ..\gflags-build third_party\gflags > NUL
::IF !errorlevel! NEQ 0 CALL:error 1 "Missing gn files for gflags"

COPY /Y ..\chromium\third_party\*.gn third_party\*.gn 
COPY /Y ..\chromium\third_party\*.gni third_party\*.gni
COPY /Y ..\chromium\third_party\DEPS third_party\DEPS 
COPY /Y ..\chromium\third_party\OWNERS third_party\OWNERS 
COPY /Y ..\chromium\third_party\*.py third_party\*.py 
GOTO:EOF

:setupDepotTools

PUSHD ..\depot_tools > NUL
set DepotToolsPath=%cd%
POPD > NUL

set CHECKSEMIPATH=%path:~-1%

WHERE gn.bat > NUL 2>&1
IF !ERRORLEVEL! EQU 1 (
    IF "%CHECKSEMIPATH%"==";" (
		set "PATH=%PATH%%DepotToolsPath%"
    ) ELSE (
		set "PATH=%PATH%;%DepotToolsPath%"
    )
)

GOTO:EOF

:fixLastChange

IF NOT EXIST %lastChangeScriptPath%\NUL CALL:error 1 "Last change script path does not exist: %lastChangeScriptPath%"
IF NOT EXIST %lastChangeScriptPath%\lastchange.py CALL:error 1 "Last change script does not exist: %lastChangeScriptPath%\lastchange.py"

PUSHD %lastChangeScriptPath% > NUL
IF !errorlevel! NEQ 0 CALL:error 1 "Failed change to last change path: %lastChangeScriptPath%"

CALL python lastchange.py -o LASTCHANGE
IF !errorlevel! NEQ 0 CALL:error 1 "Failed in call to lastchange.py: %lastChangeScriptPath%\lastchange.py"

POPD > NUL

GOTO:EOF

:downloadGnBinaries

IF NOT EXIST gn.exe CALL python %DepotToolsPath%\download_from_google_storage.py -b chromium-gn -s buildtools\win\gn.exe.sha1
IF !errorlevel! NEQ 0 CALL:error 1 "Failed downloading gn.exe"

IF NOT EXIST clang-format.exe CALL python %DepotToolsPath%\download_from_google_storage.py -b chromium-clang-format -s buildtools\win\clang-format.exe.sha1
IF !errorlevel! NEQ 0 CALL:error 1 "Failed downloading clang-format.exe"
GOTO:EOF

:gflagsPatchBuild

echo PATCHING GFLAGS...

set gflagsWindowsFolder=..\..\windows\third_party\winuwp_compat\gflags
set gflagsIgnore=.gitignore
set gflagsPatchFileName=patch_892576179b45861b53e04a112996a738309cf364.diff
set gflagsPatchFileNameApplied=%gflagsPatchFileName%.applied

IF NOT EXIST third_party\gflags\%gflagsIgnore% COPY %gflagsWindowsFolder%\%gflagsIgnore% third_party\gflags
IF NOT EXIST third_party\gflags\%gflagsPatchFileName% COPY %gflagsWindowsFolder%\%gflagsPatchFileName% third_party\gflags

IF NOT EXIST ..\gflags-build\%gflagsPatchFileNameApplied% (
	PUSHD ..\gflags-build > NUL
	git apply %gflagsPatchFileName%
	IF !ERRORLEVEL! NEQ 0 (
		set FailureGitApply=1
    )
	POPD > NUL
    IF !FailureGitApply! EQU 1 (
    	CALL:error 1 "Could not generate apply patch to webrtc\third_party\gflags using %gflagsWindowsFolder%\%gflagsPatchFileName%"
    )
)
IF NOT EXIST third_party\gflags\%gflagsPatchFileNameApplied% COPY %gflagsWindowsFolder%\%gflagsPatchFileName% third_party\gflags\%gflagsPatchFileNameApplied%

GOTO:EOF

:generateProjectsForPlatform

set IsDebugTarget=true
IF "%~3"=="release" (
	set IsDebugTarget=false
)
IF "%~3"=="debug" (
	set IsDebugTarget=true
)

SET outputPath=out\%~1_%~2_%~3
SET webRTCGnArgsDestinationPath=!outputPath!\args.gn
CALL:makeDirectory !outputPath!
CALL:copyTemplates %webRTCGnArgsTemplatePath% !webRTCGnArgsDestinationPath!

%powershell_path% -ExecutionPolicy ByPass -File ..\..\..\bin\TextReplaceInFile.ps1 !webRTCGnArgsDestinationPath! "-target_os-" "%~1" !webRTCGnArgsDestinationPath!
IF ERRORLEVEL 1 CALL:error 1 "Failed updating gn arguments for platform %~1"

%powershell_path% -ExecutionPolicy ByPass -File ..\..\..\bin\TextReplaceInFile.ps1 !webRTCGnArgsDestinationPath! "-target_cpu-" "%2" !webRTCGnArgsDestinationPath!
IF ERRORLEVEL 1 CALL:error 1 "Failed updating gn arguments for CPU %~2"

%powershell_path% -ExecutionPolicy ByPass -File ..\..\..\bin\TextReplaceInFile.ps1 !webRTCGnArgsDestinationPath! "-is_debug-" "%IsDebugTarget%" !webRTCGnArgsDestinationPath!
IF ERRORLEVEL 1 CALL:error 1 "Failed updating gn arguments for debug/release %IsDebugTarget%"

IF %logLevel% GEQ %trace% (
	CALL GN gen !outputPath! --ide="vs2017"
) ELSE (
	CALL GN gen !outputPath! --ide="vs2017" >NUL
)
IF !errorlevel! NEQ 0 CALL:error 1 "Could not generate WebRTC projects for %1 platform, %2 CPU"

%powershell_path% -ExecutionPolicy ByPass -File ..\..\..\bin\RecurseReplaceInFiles.ps1 !outputPath! *.vcxproj "call ninja.exe" "call %DepotToolsPath%\ninja.exe"

IF EXIST ..\..\..\%webRtcLibsTemplatePath%\WebRtc.%~2.sln CALL:copyTemplates ..\..\..\%webRtcLibsTemplatePath%\WebRtc.%~2.sln !outputPath!\WebRtc.sln
GOTO:EOF


:generateProjects
CALL:print %trace% "Executing generateProjects function"

SET DEPOT_TOOLS_WIN_TOOLCHAIN=0

IF %cpu_x86% EQU 1 (
	IF %platform_winuwp% EQU 1 (
		CALL:print %warning% "Generating WebRTC WinUWP projects for x86 cpu ..."
		SET platform_winuwp_cpu_x86_prepared=1
		IF %CONFIG_debug% EQU 1 (
			CALL:generateProjectsForPlatform winuwp x86 debug
		)
		IF %CONFIG_release% EQU 1 (
			CALL:generateProjectsForPlatform winuwp x86 release
		)
		SET platform_winuwp_cpu_x86_prepared=2
	)
	IF %platform_win32% EQU 1 (
		CALL:print %warning% "Generating WebRTC Win32 projects for x86 cpu ..."
		SET platform_win32_cpu_x86_prepared=1
		IF %CONFIG_debug% EQU 1 (
			CALL:generateProjectsForPlatform win x86 debug
		)
		IF %CONFIG_release% EQU 1 (
			CALL:generateProjectsForPlatform win x86 release
		)
		SET platform_win32_cpu_x86_prepared=2
	)
)

IF %cpu_x64% EQU 1 (
	IF %platform_winuwp% EQU 1 (
		CALL:print %warning% "Generating WebRTC WinUWP projects for x64 cpu ..."
		SET platform_winuwp_cpu_x64_prepared=1
		IF %CONFIG_debug% EQU 1 (
			CALL:generateProjectsForPlatform winuwp x64 debug
		)
		IF %CONFIG_release% EQU 1 (
			CALL:generateProjectsForPlatform winuwp x64 release
		)
		SET platform_winuwp_cpu_x64_prepared=2
	)
	IF %platform_win32% EQU 1 (
		CALL:print %warning% "Generating WebRTC Win32 projects for x64 cpu ..."
		SET platform_win32_cpu_x64_prepared=1
		IF %CONFIG_debug% EQU 1 (
			CALL:generateProjectsForPlatform win x64 debug
		)
		IF %CONFIG_release% EQU 1 (
			CALL:generateProjectsForPlatform win x64 release
		)
		SET platform_win32_cpu_x64_prepared=2
	)
)

IF %cpu_arm% EQU 1 (
	IF %platform_winuwp% EQU 1 (
		CALL:print %warning% "Generating WebRTC WinUWP projects for arm cpu ..."
		SET platform_winuwp_cpu_arm_prepared=1
		IF %CONFIG_debug% EQU 1 (
			CALL:generateProjectsForPlatform winuwp arm debug
		)
		IF %CONFIG_release% EQU 1 (
			CALL:generateProjectsForPlatform winuwp arm release
		)
		SET platform_winuwp_cpu_arm_prepared=2
	)
)

GOTO:EOF

:makeDirectory
IF NOT EXIST %~1\NUL (
	MKDIR %~1
	CALL:print %trace% "Created folder %~1"
) ELSE (
	CALL:print %trace% "%~1 folder already exists"
)
GOTO:EOF

:updateClang
CALL:print %trace% "Running clang update ..."

IF EXIST third_party\llvm-build\Release+Asserts\bin\clang-cl.exe GOTO:clangalreadyexists

:: TODO Need to find workaround solution for pop-up window "Git Credential Manager for Windows". In the meanwhile, just click "Cancel" button in case pop-up window appears.
CALL:print %warning% "In case pop-up window 'Git Credential Manager for Windows' appears after clang download, just click 'Cancel' button."

CALL python tools\clang\scripts\update.py %*

CALL:makeDirectory third_party\llvm

CALL:makeLink . third_party\llvm chromium\src\third_party\llvm
CALL:makeLink . third_party\llvm-build chromium\src\third_party\llvm-build

:clangalreadyexists
CALL:print %trace% "Clang already exists, skipping clang update..."

GOTO:EOF

:makeLink
IF NOT EXIST %~1\NUL CALL:error 1 "%folderStructureError:"=% %~1 does not exist!"

PUSHD %~1
IF EXIST .\%~2\NUL GOTO:alreadyexists
IF NOT EXIST %~3\NUL CALL:error 1 "%folderStructureError:"=% %~3 does not exist!"

CALL:print %trace% "In path %~1 creating symbolic link for %~2 to %~3"

IF %logLevel% GEQ %trace% (
	MKLINK /J %~2 %~3
) ELSE (
	MKLINK /J %~2 %~3  >NUL
)

IF %ERRORLEVEL% NEQ 0 CALL:ERROR 1 "COULD NOT CREATE SYMBOLIC LINK TO %~2 FROM %~3"

:alreadyexists
CALL:print %trace% "Path "%~2" already exists"
POPD

GOTO:EOF

:determineWindowsSDK
SET windowsSDKPath="Program Files (x86)\Windows Kits\10\Lib\"
SET windowsSDKFullPath=C:\!windowsSDKPath!

IF DEFINED USE_WIN_SDK_FULL_PATH SET windowsSDKFullPath=!USE_WIN_SDK_FULL_PATH! && GOTO parseSDKPath
IF DEFINED USE_WIN_SDK SET windowsSDKVersion=!USE_WIN_SDK! && GOTO setVersion
FOR %%p IN (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO (
	IF EXIST %%p:\!windowsSDKPath! (
		SET windowsSDKFullPath=%%p:\!windowsSDKPath!
		GOTO determineVersion
	)
)

:parseSDKPath
IF EXIST !windowsSDKFullPath! (
	FOR %%A IN ("!windowsSDKFullPath!") DO (
		SET windowsSDKVersion=%%~nxA
	)
) ELSE (
	CALL:ERROR 1 "Invalid Windows SDK path"
)
GOTO setVersion

:determineVersion
IF EXIST !windowsSDKFullPath! (
	PUSHD !windowsSDKFullPath!
	FOR /F "delims=" %%a in ('dir /ad /b /on') do (
		IF NOT %%a==10.0.15063.0 SET windowsSDKVersion=%%a
	)
	POPD
) ELSE (
	CALL:ERROR 1 "Invalid Windows SDK path"
)

:setVersion
IF NOT "!windowsSDKVersion!"=="" (
	FOR /f "tokens=1-3 delims=[.] " %%i IN ("!windowsSDKVersion!") DO (SET v=%%i.%%j.%%k)
) ELSE (
	CALL:ERROR 1 "Supported Windows SDK is not present. Latest supported Win SDK is 10.0.14393.0"
)

IF NOT EXIST !windowsSDKFullPath!..\Debuggers\x64\cdb.exe CALL:ERROR 1 %errorMessageMissingDebuggerTools%
IF NOT EXIST !windowsSDKFullPath!..\Debuggers\x86\cdb.exe CALL:ERROR 1 %errorMessageMissingDebuggerTools%
GOTO:EOF

:makeFileLink
IF NOT EXIST %~1 CALL:error 1 "%folderStructureError:"=% %~1 does not exist!"

echo %cd%
PUSHD %~1
IF EXIST .\%~2 GOTO:alreadyexists
IF NOT EXIST %~3 CALL:error 1 "%folderStructureError:"=% %~3 does not exist!"

IF %logLevel% GEQ %trace% (
	MKLINK /J %~2 %~3
) ELSE (
	MKLINK /J %~2 %~3  >NUL
)

CALL:print %trace% In path "%~1" creating symbolic link for "%~2" to "%~3"

IF %ERRORLEVEL% NEQ 0 CALL:ERROR 1 "COULD NOT CREATE SYMBOLIC LINK TO %~2 FROM %~3"

:alreadyexists
POPD

GOTO:EOF

:updateSDKVersion

CALL:determineWindowsSDK

IF NOT "!v!"=="" (
	CALL:print %warning% "!v! SDK version will be used"
	SET SDKVersionString=%stringToUpdateWithSDKVersion:10.0.10240=!v!%
	%powershell_path% -ExecutionPolicy ByPass -File bin\TextReplaceInFile.ps1 %pythonFilePathToUpdateSDKVersion% "%stringToUpdateWithSDKVersion%" "!SDKVersionString!" %pythonFilePathToUpdateSDKVersion%
	IF ERRORLEVEL 1 CALL:error 0 "Failed to set newer SDK version"
)
GOTO:EOF

:resetSDKVersion
IF NOT "!SDKVersionString!"=="" (
	%powershell_path% -ExecutionPolicy ByPass -File bin\TextReplaceInFile.ps1 %pythonFilePathToUpdateSDKVersion% "!SDKVersionString!" "%stringToUpdateWithSDKVersion%" %pythonFilePathToUpdateSDKVersion%
	IF ERRORLEVEL 1 CALL:error 0 "Failed to reset newer SDK version"
)
GOTO:EOF

:summary
SET logLevel=%trace%
CALL:print %trace% "=======   WebRTC prepare script summary   ======="
CALL:print %trace% "=======   platform   =========   cpu   =========   result   ======="

IF %platform_winuwp_cpu_arm_prepared% EQU 2 (
	CALL:print %info% "          winuwp                 arm               prepared"
) ELSE (
	IF %platform_winuwp_cpu_arm_prepared% EQU 1 (
		CALL:print %error% "          winuwp                 arm               failed"
	) ELSE (
		CALL:print %warning% "          winuwp                 arm               not run"
	)
)

IF %platform_winuwp_cpu_x86_prepared% EQU 2 (
	CALL:print %info% "          winuwp                 x86               prepared"
) ELSE (
	IF %platform_winuwp_cpu_x86_prepared% EQU 1 (
		CALL:print %error% "          winuwp                 x86               failed"
	) ELSE (
		CALL:print %warning% "          winuwp                 x86               not run"
	)
)

IF %platform_winuwp_cpu_x64_prepared% EQU 2 (
	CALL:print %info% "          winuwp                 x64               prepared"
) ELSE (
	IF %platform_winuwp_cpu_x64_prepared% EQU 1 (
		CALL:print %error% "          winuwp                 x64               failed"
	) ELSE (
		CALL:print %warning% "          winuwp                 x64               not run"
	)
)

IF %platform_win32_cpu_x86_prepared% EQU 2 (
	CALL:print %info% "          win32                  x86               prepared"
) ELSE (
	IF %platform_win32_cpu_x86_prepared% EQU 1 (
		CALL:print %error% "          win32                  x86               failed"
	) ELSE (
		CALL:print %warning% "          win32                  x86               not run"
	)
)

IF %platform_win32_cpu_x64_prepared% EQU 2 (
	CALL:print %info% "          win32                  x64               prepared"
) ELSE (
	IF %platform_win32_cpu_x64_prepared% EQU 1 (
		CALL:print %error% "          win32                  x64               failed"
	) ELSE (
		CALL:print %warning% "          win32                  x64               not run"
	)
)

CALL:print %trace% "==================================================================="
ECHO.
GOTO:EOF

REM Copy all ORTC template required to set developer environment
:copyTemplates

IF NOT EXIST %~1 CALL:error 1 "%folderStructureError:"=% %~1 does not exist!"

COPY %~1 %~2 >NUL

CALL:print %trace% Copied file %~1 to %~2

IF %ERRORLEVEL% NEQ 0 CALL:error 1 "%folderStructureError:"=% Unable to copy WebRTC template solution file"

GOTO:EOF

:print
SET logType=%1
SET logMessage=%~2

if %logLevel% GEQ  %logType% (
	if %logType%==0 ECHO [91m%logMessage%[0m
	if %logType%==1 ECHO [92m%logMessage%[0m
	if %logType%==2 ECHO [93m%logMessage%[0m
	if %logType%==3 ECHO [95m%logMessage%[0m
	if %logType%==4 ECHO %logMessage%
)

GOTO:EOF

:error
SET criticalError=%~1
SET errorMessage=%~2

IF %criticalError%==0 (
	ECHO.
	CALL:print %warning% "WARNING: %errorMessage%"
	ECHO.
) ELSE (
	ECHO.
	CALL:print %error% "CRITICAL ERROR: %errorMessage%"
	ECHO.
	CALL:print %error% "FAILURE:Preparing WebRTC development environment has failed.	"
	POPD
	CALL:resetSDKVersion
	CALL:summary
	::terminate batch execution
	CALL bin\batchTerminator.bat
)
GOTO:EOF

:done
ECHO.
CALL:print %info% "Success: WebRTC development environment is prepared."
CALL:resetSDKVersion
CALL:summary 
