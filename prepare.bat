:: Name:      prepare.bat
:: Purpose:   Prepare development environment for ORTC and WebRTC
:: Author:    Sergej Jovanovic
:: Email:     sergej@gnedo.com
:: Twitter:   @JovanovicSergej
:: Revision:  August 2017 - ORTC moving to GN build system

@ECHO off

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

SET DEPOT_TOOLS_WIN_TOOLCHAIN=0

::paths
SET powershell_path=%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe
SET curlPath=ortc\xplatform\curl
SET webRTCTemplatePath=webrtc\windows\templates\libs\webrtc\webrtcLib.sln
SET webRTCDestinationPath=webrtc\xplatform\webrtc\webrtcLib.sln
SET ortciOSBinariesDestinationFolder=ortc\apple\libs\
SET ortciOSBinariesDestinationPath=ortc\apple\libs\libOrtc.dylib
SET webrtcGnPath=webrtc\xplatform\webrtc\
SET ortcGnPath=webrtc\xplatform\webrtc\third_party\ortc\
SET webrtcGnBuildPathDestination=webrtc\xplatform\webrtc\BUILD.gn
SET ortcGnBuildPath=ortc\xplatform\templates\gn\ortc_BUILD.gn
SET idlGniToolsBuildPath=webrtc\xplatform\templates\gn\tool_build.gni
SET ortcGnBuildPathDestination=webrtc\xplatform\webrtc\third_party\ortc\BUILD.gn
SET idlGniToolsBuildPathDestination=webrtc\xplatform\webrtc\third_party\idl\tool_build.gni

SET idlGnBuildPath=webrtc\xplatform\templates\gn\idl_BUILD.gn
SET idlGnBuildPathDestination=webrtc\xplatform\webrtc\third_party\idl\BUILD.gn
SET pythonPipPath=C:\Python27\Scripts
SET pywin32VersionFile=C:\Python27\Lib\site-packages\pywin32.version.txt

::downloads
SET pythonVersion=2.7.15
SET pythonDestinationPath=python-%pythonVersion%.msi
SET pythonPipDestinationPath=get-pip.py
SET ortcBinariesDestinationPath=ortc\windows\projects\msvc\OrtcBinding\libOrtc.dylib
 
::urls
SET pythonDownloadUrl=https://www.python.org/ftp/python/%pythonVersion%/python-%pythonVersion%.msi
SET pythonPipUrl=https://bootstrap.pypa.io/get-pip.py
SET binariesGitPath=https://github.com/ortclib/ortc-binaries.git

::helper flags
SET taskFailed=0
SET ortcAvailable=0
SET startTime=%time%
SET endingTime=0
SET defaultProperties=0

::targets
SET prepare_ORTC_Environment=0
SET prepare_WebRTC_Environment=0

::platforms
SET platform_winuwp=0
SET platform_win32=0

SET CPU_arm=0
SET CPU_x86=0
SET CPU_x64=0

SET CONFIG_debug=0
SET CONFIG_release=0

::log levels
SET globalLogLevel=2											
SET error=0														
SET info=1														
SET warning=2													
SET debug=3														
SET trace=4														

::input arguments
SET supportedInputArguments=;platform;cpu;config;target;help;logLevel;diagnostic;gn;server;		
SET target=all
SET platform=all
SET cpu=all
SET config=all
SET help=0
SET logLevel=2
SET diagnostic=0
SET server=0
SET gn=1

::predefined messages
SET errorMessageInvalidArgument="Invalid input argument. For the list of available arguments and usage examples, please run script with -help option."
SET errorMessageInvalidTarget="Invalid target name. For the list of available targets and usage examples, please run script with -help option."
SET errorMessageInvalidPlatform="Invalid platform name. For the list of available targets and usage examples, please run script with -help option."
SET errorMessageInvalidCpu="Invalid cpu name. For the list of available targets and usage examples, please run script with -help option."
SET errorMessageInvalidConfig="Invalid config name. For the list of available targets and usage examples, please run script with -help option."
SET folderStructureError="ORTC invalid folder structure."

CALL:precheck

IF "%1"=="" (
	CALL:print %warning% "Running script with default parameters: "
	CALL:print %warning% "Target: all ^(Ortc and WebRtc^)"
	CALL:print %warning% "Platform: all ^(winuwp, win32^)"
	CALL:print %warning% "Cpu: all ^(x64, x86, arm^)"
	CALL:print %warning% "Log level: %logLevel% ^(warning^)"
	SET defaultProperties=1
)

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

IF /I "%cpu%"=="win32" set cpu=x86

CALL:showHelp

::Run diganostic if script is run in diagnostic mode
IF %diagnostic% EQU 1 CALL:diagnostic

ECHO.
CALL:print %info% "Running prepare script ..."
ECHO.

IF EXIST bin\Config.bat CALL bin\Config.bat

IF %defaultProperties% EQU 0 (
	CALL:print %warning% "Running script parameters:"
	CALL:print %warning% "Target: %target%"
	CALL:print %warning% "Platform: %platform%"
	CALL:print %warning% "Cpu: %cpu%"
	CALL:print %warning% "Log level: %logLevel%"
	SET defaultProperties=1
)

::Check if ORTC is available
CALL:checkOrtcAvailability
 
::Determine targets
CALL:identifyTarget

::Determine targeted platforms
CALL:identifyPlatform

::Determine targeted platforms
CALL:identifyCpu

::Determine targeted platforms
CALL:identifyConfig

::Check is perl installed
CALL:perlCheck

::Check if git installed
CALL:gitCheck

::Check if depot_tools is in PATH environment
CALL:depotToolsPathCheck

::Check if python is installed. If it isn't install it and add in the path
CALL:pythonSetup


IF %gn% EQU 1 (
    CALL:prepareGN
)

::Generate WebRTC VS2015 projects from gn files
CALL:prepareWebRTC


IF %prepare_ORTC_Environment% EQU 1 (
	REM Prepare ORTC development environment
	CALL:prepareORTC

	IF %platform_win32% EQU 1 (
		REM Download curl and build it
		CALL:prepareCurl
	)
	
)

IF %server% EQU 1 (
    CALL:buildPeerCCServer
)
::Finish script execution
CALL:done

GOTO:EOF
::===========================================================================

:precheck
IF NOT "%CD%"=="%CD: =%" CALL:error 1 "Path must not contain folders with spaces in name"
IF EXIST ..\bin\nul (
	CALL:error 1 "Do not run scripts from bin directory!"
	CALL batchTerminator.bat
)
GOTO:EOF

:diagnostic
SET logLevel=3
CALL:print 2 "Diagnostic mode - checking if some required programs are missing"
CALL:print 2  "================================================================================"
ECHO.
WHERE perl > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	CALL:print 0 "Perl				not installed"
) else (
	CALL:print 1 "Perl				    installed"
)

WHERE python > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	CALL:print 0 "Python				not installed"
) else (
	CALL:print 1 "Python				    installed"
)

WHERE git > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	CALL:print 0 "Git   				not installed"
) else (
	CALL:print 1 "Git   				    installed"
)

ECHO.
CALL:print 2  "================================================================================"
ECHO.
CALL:print 1 "Diagnostic finished"
CALL bin\batchTerminator.bat
GOTO:EOF

REM Based on input arguments determine targeted projects (WebRTC or ORTC)
:identifyTarget
SET validInput=0
SET messageText=

IF /I "%target%"=="all" (
	SET prepare_ORTC_Environment=%ortcAvailable%
	SET prepare_WebRTC_Environment=1
	SET validInput=1
	IF !prepare_ORTC_Environment! EQU 1 (
		SET messageText=Preparing webRTC and ORTC development environment ...
	) ELSE (
		SET messageText=Preparing webRTC development environment ...
		)
) ELSE (
	IF /I "%target%"=="webrtc" (
		SET prepare_WebRTC_Environment=1
		SET validInput=1
	)
	IF /I "%target%"=="ortc" (
	IF %ortcAvailable% EQU 0 CALL:ERROR 1 "ORTC is not available!"
		SET prepare_ORTC_Environment=1
		SET validInput=1
	)

	IF !validInput!==1 (
		SET messageText=Preparing %target% development environment ...
	)
)

:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidTarget%
)
GOTO:EOF

REM Based on input arguments determine targeted platforms (winuwp, win32)
:identifyPlatform
SET validInput=0
SET messageText=

IF /I "%platform%"=="all" (
	SET platform_winuwp=1
	SET platform_win32=1
	SET validInput=1
	SET messageText=Preparing development environment for WinUWP and Win32 platforms ...
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
		SET messageText=Preparing development environment for %platform% platform...
	)
)
:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidPlatform%
)
GOTO:EOF


REM Based on input arguments determine targeted cpu (x64, x86 or ARM)
:identifyCpu
SET validInput=0
SET messageText=

IF /I "%cpu%"=="all" (
	SET cpu_arm=1
	SET cpu_x86=1
	SET cpu_x64=1
	SET validInput=1
	SET messageText=Preparing development environment for arm, x86, and x64 cpus ...
) ELSE (
	IF /I "%cpu%"=="arm" (
		IF /I "%platform%"=="win32" (
			CALL:print %warning% "Win32 ARM is not a valid target thus assuming an x86 cpu ..."
			SET cpu=x86
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
		SET cpu_x86=1
		SET validInput=1
	)

	IF !validInput!==1 (
		SET messageText=Preparing development environment for %cpu% cpu...
	)
)
:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidCpu%
)
GOTO:EOF


REM Based on input arguments determine targeted config (debug/release)
:identifyConfig
SET validInput=0
SET messageText=

IF /I "%config%"=="all" (
	SET CONFIG_debug=1
	SET CONFIG_release=1
	SET validInput=1
	SET messageText=Preparing development environment for debug and release configurations ...
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
		SET messageText=Preparing development environment for %config% configuration...
	)
)
:: If input is not valid terminate script execution
IF !validInput!==1 (
	CALL:print %warning% "!messageText!"
) ELSE (
	CALL:error 1 %errorMessageInvalidConfig%
)
GOTO:EOF

REM Check if entered valid input argument
:checkIfArgumentIsValid
IF "!supportedInputArguments:;%~1;=!" neq "%supportedInputArguments%" (
	::it is valid
	SET %2=1
) ELSE (
	::it is not valid
	SET %2=0
)
GOTO:EOF

REM check if perl is installed
:perlCheck
WHERE perl > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	ECHO.
	CALL:print 2  "================================================================================"
	ECHO.
	CALL:print 2  "Warning! Warning! Warning! Warning! Warning! Warning! Warning!"
	ECHO.
	CALL:print 2  "Perl is missing."
	CALL:print 2  "You need to have installed Perl to build projects properly."
	CALL:print 2  "Use the 32-bit perl from Strawberry http://strawberryperl.com/ to avoid possible linking errors and incorrect assember files generation."
	CALL:print 2  "Download URL: http://strawberryperl.com/download/5.22.1.2/strawberry-perl-5.22.1.2-32bit.msi"
	CALL:print 2  "Make sure that the perl path from Strawberry appears at the beginning of all other perl paths in the PATH" 
	ECHO.
	CALL:print 2  "================================================================================"
	ECHO.
	CALL:print 2  "NOTE: Please restart your command shell after installing perl and re-run this script..."	
	ECHO.
	
	CALL:error 1 "Perl has to be installed before running prepare script!"
	ECHO.	
)
GOTO:EOF

REM check if git is installed
:gitCheck
WHERE git > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	ECHO.
	CALL:print 2  "================================================================================"
	ECHO.
	CALL:print 2  "Warning! Warning! Warning! Warning! Warning! Warning! Warning!"
	ECHO.
	CALL:print 2  "Git is missing."
	CALL:print 2  "You need to have installed git to build projects properly."
	ECHO.
	CALL:print 2  "================================================================================"
	ECHO.
	CALL:print 2  "NOTE: Please restart your command shell after installing git and re-run this script..."	
	ECHO.
	
	CALL:error 1 "git has to be installed before running prepare script!"
	ECHO.	
)
GOTO:EOF

:pythonDownloadAndInstall
	CALL:print %debug%  "Installing Python ..."
	CALL:download %pythonDownloadUrl% %pythonDestinationPath%
	IF !taskFailed!==1 (
		CALL:error 1  "Downloading python installer has failed. Script execution will be terminated. Please, run script once more, if python doesn't get installed again, please do it manually."
	) ELSE (
		START "Python install" /wait msiexec /a %pythonDestinationPath% /quiet
		IF !ERRORLEVEL! NEQ 0 (
			CALL:error 1  "Python installation has failed. Script execution will be terminated. Please, run script once more, if python doesn't get installed again, please do it manually."
		) ELSE (
			CALL:print %debug% "Python is successfully installed"
		)
		CALL:print %trace%  "Deleting downloaded file."
		DEL %pythonDestinationPath%
		IF !ERRORLEVEL! NEQ 0 (
			CALL:error 0  "Deleting python installer from /bin folder has failed. You can delete it manually."
		)
	)
	
	IF EXIST C:\Python27\nul CALL:set_path "C:\Python27"
	IF EXIST D:\Python27\nul CALL:set_path "D:\Python27"
	
	WHERE python > NUL 2>&1
	IF !ERRORLEVEL! EQU 1 (
		CALL:error 0  "Python is not added to the path."
	) else (
		CALL:print %debug%  "Python is added to the path."
	)
GOTO:EOF
	
:pythonSetup
WHERE python > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	CALL:print %warning%  "NOTE: Installing Python and continuing build..."
    CALL:pythonDownloadAndInstall
) ELSE (
	CALL:print %trace%  "Python is present."
	
	:: check version that is installed
    python -V > NUL 2> tmpPyVerFile.txt
    set /p pyVer= < tmpPyVerFile.txt 
    del tmpPyVerFile.txt 
    CALL:print %trace% "!pyVer!"

    for /f "tokens=2" %%a in ("!pyVer!") do (set verFound=%%a)
    CALL:print %trace% "Currently installed Python version: !verFound!"

    IF "!verFound!" GEQ "3.0" (
        CALL:error 1 "Please install python 2.7, and in the PATH place it in front of python !verFound!"
   )    
   
	for /f "tokens=3 delims=." %%a in ("!verFound!") do (set /a ver27Found=%%a)
	CALL:print %trace% "Currently installed Python 2.7 subversion: !ver27Found!"
   
    IF !ver27Found! LSS 15 (
		CALL:print %trace% "Installing the latest Python 2.7 version"
        :: rename old Python, random is used to prevent error on renaming
	    IF EXIST C:\Python27\nul (
		    REN C:\Python27 Python27_VERSION_!verFound!_RANDOM_SUFFIX_%RANDOM%
		) 
	    IF EXIST D:\Python27\nul (
		    REN D:\Python27 Python27_VERSION_!verFound!_RANDOM_SUFFIX_%RANDOM%		
		)
        :: install the latest Python 2.7 version
	    CALL:pythonDownloadAndInstall
   )      
)

CALL:print %warning%  "Pip and pywin32 setup..."
::echo %PATH%
CALL bin\addPathToEnvPATH.bat %pythonPipPath% 
::echo %PATH%

WHERE pip > NUL 2>&1
IF %ERRORLEVEL% EQU 1 (
	CALL:print %debug%  "Installing Python Pip..."
	CALL:download %pythonPipUrl% %pythonPipDestinationPath%
    python %pythonPipDestinationPath%
) ELSE (
	CALL:print %trace%  "Pip is present."   
)

IF NOT EXIST %pywin32VersionFile% (
	CALL:print %trace% "Updating pip ..."
    python.exe -m pip install --upgrade pip
    IF !ERRORLEVEL! NEQ 0 (
		CALL:error 1  "Unable to update Python pip tool."
    )
    CALL:print %trace% "Installing pywin32..."
	pip install pywin32
    IF !ERRORLEVEL! NEQ 0 (
		CALL:error 1  "Unable to install pywin32 module."
    )
) ELSE (
	CALL:print %trace% "pywin32 already exists"
)

IF EXIST get-pip.py DEL /f /q get-pip.py

GOTO:EOF


:prepareORTC

GOTO:EOF

::Generate WebRTC projects
:prepareWebRTC

IF %prepare_ORTC_Environment% EQU 1 (
  CALL bin\prepareWebRtc.bat -platform %platform% -cpu %cpu% -config %config% -logLevel %logLevel% -target ortc
) ELSE (
  CALL bin\prepareWebRtc.bat -platform %platform% -cpu %cpu% -config %config% -logLevel %logLevel%
)

GOTO:EOF

REM Download and build curl
:prepareCurl
CALL:print %debug% "Preparing curl ..."

IF NOT EXIST %curlPath% CALL:error 1 "%folderStructureError:"=% %curlPath% does not exist!"

PUSHD %curlPath% > NUL
CALL:print %trace% "Pushed %curlPath% path"

CALL prepareCurl.bat -logLevel %globalLogLevel%

::IF %logLevel% GEQ %trace% (
::	CALL prepare.bat curl 
::) ELSE (
::	CALL prepare.bat curl  >NUL
::)

IF !ERRORLEVEL! EQU 1 CALL:error 1 "Curl preparation has failed."

POPD > NUL

GOTO:EOF

:prepareGN

CALL:cleanup

CALL:makeDirectory %ortcGNPath%
CALL:makeDirectory webrtc\xplatform\webrtc\third_party\idl

IF NOT EXIST %webrtcGnPath%originalBuild.gn COPY %webrtcGnPath%BUILD.gn %webrtcGnPath%originalBuild.gn
IF !ERRORLEVEL! EQU 1 CALL:error 1 "Failed renamed original webrtc build.gn file" 

IF %prepare_ORTC_Environment% EQU 1 (
	%powershell_path% -ExecutionPolicy ByPass -File bin\TextReplaceInFile.ps1 !webrtcGnBuildPathDestination! """":webrtc"","" """":webrtc"",""""//third_party/ortc:ortc"""","" !webrtcGnBuildPathDestination!
	IF ERRORLEVEL 1 CALL:error 1 "Failed updating gn to include ORTC target"
)

%powershell_path% -ExecutionPolicy ByPass -File bin\TextReplaceInFile.ps1 !webrtcGnBuildPathDestination! """"pc"","" """"pc"",""""//third_party/idl:idl"""","" !webrtcGnBuildPathDestination!
IF ERRORLEVEL 1 CALL:error 1 "Failed updating gn to include IDL target"

IF %prepare_ORTC_Environment% EQU 1 (
	CALL:copyTemplates %ortcGnBuildPath% %ortcGnBuildPathDestination%
)
CALL:copyTemplates %idlGnBuildPath% %idlGnBuildPathDestination%

CALL:copyTemplates %idlGniToolsBuildPath% %idlGniToolsBuildPathDestination%

IF %prepare_ORTC_Environment% EQU 1 (
	IF !platform_win32! EQU 1 (
	    CALL:makeLink . webrtc\xplatform\webrtc\third_party\ortc\curl ortc\xplatform\curl
	)
)

GOTO:EOF

:buildPeerCCServer
  IF NOT "%platform%"=="all" (
    IF NOT "%platform%"=="win32" CALL bin\prepareWebRtc.bat -platform win32 -cpu x86 -config release -logLevel %logLevel%
  )

  CALL:print %info% "Building PeerConnection server"
  CALL bin\buildWebRtc.bat Release win32 x86 webrtc/examples:peerconnection_server
  IF !ERRORLEVEL! EQU 0 (
    CALL:copyTemplates webrtc\xplatform\webrtc\out\win_x86_release\peerconnection_server.exe .\bin\
  )
GOTO:EOF

:downloadBinariesFromRepo
ECHO.
CALL:print %info% "Donwloading binaries from repo !BINARIES_DOWNLOAD_REPO_URL!"
IF EXIST ..\ortc-binaries\NUL RMDIR /q /s ..\ortc-binaries\
	
PUSHD ..\
CALL git clone !BINARIES_DOWNLOAD_REPO_URL! -b !BINARIES_DOWNLOAD_REPO_BRANCH! > NUL
IF !ERRORLEVEL! EQU 1 CALL:error 1 "Failed cloning binaries."
POPD
	
CALL:makeDirectory %ortciOSBinariesDestinationFolder%
CALL:copyTemplates ..\ortc-binaries\Release\libOrtc.dylib %ortciOSBinariesDestinationPath%
	
IF EXIST ..\ortc-binaries\NUL RMDIR /q /s ..\ortc-binaries\
GOTO:EOF

:downloadBinariesFromURL
ECHO.
CALL:print %info% "Donwloading binaries from URL !BINARIES_DOWNLOAD_URL!"

CALL:makeDirectory %ortciOSBinariesDestinationFolder%
CALL:download !BINARIES_DOWNLOAD_URL! %ortciOSBinariesDestinationPath%
IF !taskFailed! EQU 1 CALL:ERROR 1 "Failed downloading binaries from !BINARIES_DOWNLOAD_URL!"

GOTO:EOF


REM Download file (first argument) to desired destination (second argument)
:download
IF EXIST %~2 GOTO:EOF
::%powershell_path% "Start-BitsTransfer %~1 -Destination %~2"
%powershell_path% -Command [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;(new-object System.Net.WebClient).DownloadFile('%~1','%~2')

IF %ERRORLEVEL% EQU 1 SET taskFailed=1

GOTO:EOF

REM Add path to the user variables
:set_path
IF "%~1"=="" EXIT /b 2
IF NOT DEFINED PATH EXIT /b 2
::
:: Determine if function was called while delayed expansion was enabled
SETLOCAL
SET "NotDelayed=!"
::
:: Prepare to safely parse PATH into individual paths
SETLOCAL DisableDelayedExpansion
SET "var=%path:"=""%"
SET "var=%var:^=^^%"
SET "var=%var:&=^&%"
SET "var=%var:|=^|%"
SET "var=%var:<=^<%"
SET "var=%var:>=^>%"
SET "var=%var:;=^;^;%"
SET var=%var:""="%
SET "var=%var:"=""Q%"
SET "var=%var:;;="S"S%"
SET "var=%var:^;^;=;%"
SET "var=%var:""="%"
SETLOCAL EnableDelayedExpansion
SET "var=!var:"Q=!"
SET "var=!var:"S"S=";"!"
::
:: Remove quotes from pathVar and abort if it becomes empty
rem set "new=!%~1:"^=!"
SET new=%~1

IF NOT DEFINED new EXIT /b 2
::
:: Determine if pathVar is fully qualified
ECHO("!new!"|FINDSTR /i /r /c:^"^^\"[a-zA-Z]:[\\/][^\\/]" ^
                           /c:^"^^\"[\\][\\]" >NUL ^
  && SET "abs=1" || SET "abs=0"
::
:: For each path in PATH, check if path is fully qualified and then
:: do proper comparison with pathVar. Exit if a match is found.
:: Delayed expansion must be disabled when expanding FOR variables
:: just in case the value contains !
FOR %%A IN ("!new!\") DO FOR %%B IN ("!var!") DO (
  IF "!!"=="" SETLOCAL disableDelayedExpansion
  FOR %%C IN ("%%~B\") DO (
    ECHO(%%B|FINDSTR /i /r /c:^"^^\"[a-zA-Z]:[\\/][^\\/]" ^
                           /c:^"^^\"[\\][\\]" >NUL ^
      && (IF %abs%==1 IF /i "%%~sA"=="%%~sC" EXIT /b 0) ^
      || (IF %abs%==0 IF /i %%A==%%C EXIT /b 0)
  )
)
::
:: Build the modified PATH, enclosing the added path in quotes
:: only if it contains ;
SETLOCAL enableDelayedExpansion
IF "!new:;=!" NEQ "!new!" SET new="!new!"
IF /i "%~2"=="/B" (SET "rtn=!new!;!path!") ELSE SET "rtn=!path!;!new!"
::
:: rtn now contains the modified PATH. We need to safely pass the
:: value accross the ENDLOCAL barrier
::
:: Make rtn safe for assignment using normal expansion by replacing
:: % and " with not yet defined FOR variables
SET "rtn=!rtn:%%=%%A!"
SET "rtn=!rtn:"=%%B!"
::
:: Escape ^ and ! if function was called while delayed expansion was enabled.
:: The trailing ! in the second assignment is critical and must not be removed.
IF NOT DEFINED NotDelayed SET "rtn=!rtn:^=^^^^!"
IF NOT DEFINED NotDelayed SET "rtn=%rtn:!=^^^!%" !
::
:: Pass the rtn value accross the ENDLOCAL barrier using FOR variables to
:: restore the % and " characters. Again the trailing ! is critical.
FOR /f "usebackq tokens=1,2" %%A IN ('%%^ ^"') DO (
  ENDLOCAL & ENDLOCAL & ENDLOCAL & ENDLOCAL & ENDLOCAL
  SET "path=%rtn%" !
)
%powershell_path% -NoProfile -ExecutionPolicy Bypass -command "[Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::User)"

GOTO:EOF

REM Create a folder
:makeDirectory
IF NOT EXIST %~1\NUL (
	MKDIR %~1
	CALL:print %trace% "Created folder %~1"
) ELSE (
	CALL:print %trace% "%~1 folder already exists"
)
GOTO:EOF

REM Create symbolic link (first argument), that will point to desired file (second argument)
:makeLinkToFile

IF EXIST %~1 GOTO:filelinkalreadyexists
IF NOT EXIST %~2 CALL:error 1 "%folderStructureError:"=% %~2 does not exist!"

CALL:print %trace% Creating symbolic link "%~1" for the file "%~2"

::Make hard link to ortc-lib-sdk-win.vs20151.sln

IF %logLevel% GEQ %trace% (
	MKLINK /H %~1 %~2
) ELSE (
	MKLINK /H %~1 %~2  >NUL
)
IF %ERRORLEVEL% NEQ 0 CALL:ERROR 1 "COULD NOT CREATE SYMBOLIC LINK TO %~2"

:filelinkalreadyexists

GOTO:EOF
:makeLink
IF NOT EXIST %~1\NUL CALL:error 1 "%folderStructureError:"=% %~1 does not exist!"

::PUSHD %~1
IF EXIST .\%~2\NUL GOTO:alreadyexists
IF NOT EXIST %~3\NUL CALL:error 1 "%folderStructureError:"=% %~3 does not exist!"

CALL:print %trace% In path "%~1" creating symbolic link for "%~2" to "%~3"

IF %logLevel% GEQ %trace% (
	MKLINK /J %~2 %~3
) ELSE (
	MKLINK /J %~2 %~3  >NUL
)

IF %ERRORLEVEL% NEQ 0 CALL:ERROR 1 "COULD NOT CREATE SYMBOLIC LINK TO %~2 FROM %~3"

:alreadyexists
::  POPD

GOTO:EOF

REM Copy all ORTC template required to set developer environment
:copyTemplates

IF NOT EXIST %~1 CALL:error 1 "%folderStructureError:"=% %~1 does not exist!"

echo COPY %~1 %~2
COPY %~1 %~2 >NUL

CALL:print %trace% Copied file %~1 to %~2

IF %ERRORLEVEL% NEQ 0 CALL:error 1 "%folderStructureError:"=% Unable to copy WebRTC template solution file"

GOTO:EOF

:checkOrtcAvailability
IF EXIST ortc\NUL SET ortcAvailable=1
GOTO:EOF


:unzipfile 
SET vbs="%temp%\_.vbs"
IF EXIST %vbs% DEL /f /q %vbs%
>%vbs%  ECHO Set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% ECHO If NOT fso.FolderExists(%1) Then
>>%vbs% ECHO fso.CreateFolder(%1)
>>%vbs% ECHO End If
>>%vbs% ECHO set objShell = CreateObject("Shell.Application")
>>%vbs% ECHO set FilesInZip=objShell.NameSpace(%2).items
>>%vbs% ECHO objShell.NameSpace(%1).CopyHere(FilesInZip)
>>%vbs% ECHO Set fso = Nothing
>>%vbs% ECHO Set objShell = Nothing
CSCRIPT //nologo %vbs%
IF EXIST %vbs% DEL /f /q %vbs%
DEL /f /q %2
GOTO:EOF


:depotToolsPathCheck
CALL:print %trace% "depotToolsPathCheck entered..."

SET numberOfRemoved=0
SET oldPath=%PATH%
rem echo Old path: !oldPath!

FOR %%A IN ("%path:;=";"%") DO (
rem    echo %%~A
    SET aux3=%%~A\depot-tools-auth
rem    echo !aux3! 
    
    IF EXIST "!aux3!" (
rem     echo Before modification !PATH! 
        echo Remove %%~A from path       
        CALL SET PATH=%%PATH:;%%~A=%%
        CALL SET PATH=%%PATH:%%~A;=%%
rem     echo Modified path: !PATH!

        SET /A numberOfRemoved=numberOfRemoved+1
        CALL:print %trace% "numberOfRemoved: !numberOfRemoved!"        
    ) 
)
GOTO:EOF


:restorePathEnv
CALL:print %trace% "restorePathEnv entered..."
CALL:print %trace% "Number of paths temporarily removed from environment PATH: !numberOfRemoved!"

IF %numberOfRemoved% GTR 0  (     
    set PATH=!oldPath!
)
rem echo Restored PATH = !PATH!
GOTO:EOF


:cleanup
IF EXIST %webrtcGnPath%originalBuild.gn (
    DEL %webrtcGnPath%BUILD.gn
    REN %webrtcGnPath%originalBuild.gn BUILD.gn
)
GOTO:EOF

:showHelp
IF %help% EQU 0 GOTO:EOF

ECHO.
ECHO    [92mAvailable parameters:[0m
ECHO.
ECHO  	[93m-diagnostic[0m 		Flag for runing check if system is ready for webrtc development.
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
ECHO		[93m-config[0m 	Config name to set environment for. Default is All (debug,release)
ECHO.
CALL bin\batchTerminator.bat

GOTO:EOF

REM Print logger message. First argument is log level, and second one is the message
:print
SET logType=%1
SET logMessage=%~2

if %logLevel% GEQ  %logType% (
	if %logType%==0 ECHO [91m%logMessage%[0m
	if %logType%==1 ECHO [92m%logMessage%[0m
	if %logType%==2 ECHO [93m%logMessage%[0m
	if %logType%==3 ECHO %logMessage%
	if %logType%==4 ECHO %logMessage%
)

GOTO:EOF

REM Print the error message and terminate further execution if error is critical.Firt argument is critical error flag (1 for critical). Second is error message
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
	ECHO.
	CALL:print %error% "FAILURE:Preparing environment has failed!"
	ECHO.
    CALL:cleanup
	SET endTime=%time%
	CALL:showTime
	::terminate batch execution
	CALL bin\batchTerminator.bat
)
GOTO:EOF

:showTime

SET options="tokens=1-4 delims=:.,"
FOR /f %options% %%a in ("%startTime%") do SET start_h=%%a&SET /a start_m=100%%b %% 100&SET /a start_s=100%%c %% 100&SET /a start_ms=100%%d %% 100
FOR /f %options% %%a in ("%endTime%") do SET end_h=%%a&SET /a end_m=100%%b %% 100&SET /a end_s=100%%c %% 100&SET /a end_ms=100%%d %% 100

SET /a hours=%end_h%-%start_h%
SET /a mins=%end_m%-%start_m%
SET /a secs=%end_s%-%start_s%
SET /a ms=%end_ms%-%start_ms%
IF %ms% lss 0 SET /a secs = %secs% - 1 & SET /a ms = 100%ms%
IF %secs% lss 0 SET /a mins = %mins% - 1 & SET /a secs = 60%secs%
IF %mins% lss 0 SET /a hours = %hours% - 1 & SET /a mins = 60%mins%
IF %hours% lss 0 SET /a hours = 24%hours%

SET /a totalsecs = %hours%*3600 + %mins%*60 + %secs% 

IF 1%ms% lss 100 SET ms=0%ms%
IF %secs% lss 10 SET secs=0%secs%
IF %mins% lss 10 SET mins=0%mins%
IF %hours% lss 10 SET hours=0%hours%

:: mission accomplished
ECHO [93mTotal execution time: %hours%:%mins%:%secs% (%totalsecs%s total)[0m

GOTO:EOF

:done
ECHO.
CALL:print %info% "Success: Development environment is set."
CALL:cleanup
CALL:restorePathEnv
SET endTime=%time%
CALL:showTime
ECHO. 
