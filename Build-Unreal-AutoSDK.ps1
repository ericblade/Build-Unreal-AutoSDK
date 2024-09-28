# Copy the Unreal Windows SDK and tools to the specified AutoSDK directory, HostWin64\Win64 into subdirectories for each Visual Studio version.
# Initial version only does Win64 host and Win64 target.  Support for additional hosts and targets will be necessary.
# TODO: we should probably use RoboCopy instead of Copy-Item for better performance...
# TODO: support -WhatIf switch

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Path = "h:\Unreal\AutoSDK",

    [Parameter()]
    [switch]
    $Clean,

    [Parameter()]
    [switch]
    $SkipVCTools,

    [Parameter()]
    [switch]
    $SkipWindowsSDK,

    [Parameter()]
    [switch]
    $SkipNetFXSDK,

    [Parameter()]
    [switch]
    $SkipDIASDK
)

. ".\Get-AutoSDK-PlatformPath.ps1"

$AutoSDKRoot = Get-Item -Path $Path -ErrorAction SilentlyContinue
if (-not $AutoSDKRoot) {
    Write-Output "AutoSDK path not found: $Path"
    New-Item -Path $Path -ItemType Directory
    $AutoSDKRoot = Get-Item -Path $Path
}

# Gather up all the things the Windows AutoSDK needs - VC++ Tools, Windows 10 SDK Kit, NetFX SDK, DIA SDK
# As each one is found, copy it to the AutoSDKPlatformPath directory.

Write-Output "AutoSDK path: $AutoSDKRoot"
$AutoSDKPlatformPath = Get-AutoSDK-PlatformPath -Root $AutoSDKRoot -HostPlatform Win64 -TargetPlatform Win64
Write-Output "AutoSDK platform path: $AutoSDKPlatformPath"

if ($Clean) {
    Write-Output "Cleaning AutoSDK platform path: $AutoSDKPlatformPath"
    Remove-Item -Path $AutoSDKPlatformPath -Recurse -Force
}
$pf = [Environment]::GetFolderPath("ProgramFilesx86")
Write-Output "Program Files: $pf"
# TODO: if powershell 7 use Join-Path enhancements instead of [IO.Path]::Combine?
# $vsWhere = Join-Path $pf "Microsoft Visual Studio" "Installer" "vswhere.exe"
$vsWhere = [IO.Path]::Combine($pf, "Microsoft Visual Studio", "Installer", "vswhere.exe")
Write-Output "vsWhere path: $vsWhere"
if (-not (Test-Path $vsWhere)) {
    Write-Error "vsWhere not found -- are you sure you are running on a machine with Visual Studio 2017 or better installed?"
    Exit -1
}
$VSInstalls = (& "$vsWhere" -format json -all -requires Microsoft.Component.MSBuild | ConvertFrom-Json) #-all -products * -requires Microsoft.VisualStudio.Product.BuildTools -property installationPath | ConvertFrom-Json
Write-Information "Visual Studio installs: $($VSInstalls.Count)"
if ($VSInstalls.Count -eq 0) {
    Write-Error "No Visual Studio installs found"
    Exit -1
}
Write-Verbose "Visual Studio install 1: $($VSInstalls[0])"
$VSInstalls | ForEach-Object {
    $vsPath = $_.installationPath
    $vsVersion = $_.buildVersion
    Write-Output "Visual Studio $vsVersion path: $vsPath"
    $vcToolsPath = [IO.Path]::Combine($vsPath, "VC", "Tools", "MSVC")
    Write-Output "VC Tools path: $vcToolsPath"
    Get-ChildItem -Path $vcToolsPath | ForEach-Object {
        $vcToolsVersion = $_.Name
        Write-Output "VC Tools version: $vcToolsVersion"
        $outDir = ""
        switch -regex ($vcToolsVersion) {
            # https://gist.github.com/RDCH106/40fe61f447df58c1b9c83a1781374bcd
            "14.1[0-9]" {
                $outDir = "VS2017"
                Write-Output "VS 2017"
            }
            "14.2[0-9]" {
                $outDir = "VS2019"
                Write-Output "VS 2019"
            }
            "14.3[0-9]" {
                $outDir = "VS2022"
                Write-Output "VS 2022"
            }
            "14.4[0-9]" {
                $outDir = "VS2022"
                Write-Output "VS 2022 17.10+" # https://devblogs.microsoft.com/cppblog/msvc-toolset-minor-version-number-14-40-in-vs-2022-v17-10/
            }
        }
        if (-not $SkipVCTools) {
            # TODO: need to reflow this some to be able to put the SKipVCTools switch earlier since some other code below is probably dependent on a variable set above here.
            # I may be wrong about that, though.
            if (-not [string]::IsNullOrEmpty($outDir)) {
                $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, $outDir)
                Write-Output "Output directory: $outDir"
                if (-not (Test-Path $outDir)) {
                    Write-Output "Creating directory: $outDir"
                    New-Item -Path $outDir -ItemType Directory
                }
                $inToolsPath = [IO.Path]::Combine($vcToolsPath, $vcToolsVersion)
                Write-Output "Copying files from: $inToolsPath"
                $capturedErrors = @()
                Copy-Item -Path $inToolsPath -Destination $outDir -Recurse -ErrorVariable capturedErrors -ErrorAction SilentlyContinue
                $capturedErrors | ForEach-Object {
                    if ($_ -notmatch "already exists") {
                        Write-Error "Error: $_"
                    }
                }
            }
            else {
                Write-Output "Unknown VC Tools version: $vcToolsVersion update the Build-Unreal-AutoSDK.ps1 script"
            }
        }
    }
}

$windowsSDKDir = ""
# This method which calls the official Microsoft script to find the Windows SDK works when called from an interactive shell,
# but does not when called from inside a PowerShell script.  I do not know why.  I would prefer to call the official Microsoft tool,
# so that if the method changes, the script will still work.  However, for now, I will use the method contained inside that official
# command, but in PowerShell form.
#$winSDKFinderPath = [IO.Path]::Combine($VSInstalls[0].installationPath, "Common7", "Tools", "vsdevcmd", "core", "vsdevcmd_start.bat")
# Run $winSDKFinderPath and get the environment variable for WIndowsSdkDir
#$windowsSDKDir = (& cmd /c .\GetSDKPath.cmd $winSDKFinderPath)

# TODO: we *could* have the user invoke this script from inside a Visual Studio Developer Command Prompt, in which case we could just use the environment variable.
# I'd rather find out what's wrong with trying to call the official Microsoft script from inside a PowerShell script, though.

# Instead, search HKLM:\SOFTWARE\Wow6432Node, HKCU:\SOFTWARE\Wow6432Node, HKLM:\SOFTWARE, HKCU:\SOFTWARE for the Microsoft\Microsoft SDKs\Windows\v10.0 key
# Epic does not suport Windows 8.1 and lower, so let's just grab for v10.  Windows 11 does not have a separate kit at this time.
$keyPath = "\Microsoft\Microsoft SDKs\Windows\v10.0"
$regPathsToSearch = @(
    "HKLM:\SOFTWARE"
    "HKCU:\SOFTWARE"
    "HKLM:\SOFTWARE\Wow6432Node"
    "HKCU:\SOFTWARE\Wow6432Node"
)
$regPathsToSearch | ForEach-Object {
    $regPath = $_ + $keyPath
    Write-Verbose "Searching $regPath"
    if (Test-Path $regPath) {
        Write-Verbose "Found $regPath"
        $windowsSDKDir = (Get-ItemProperty -Path $regPath -Name "InstallationFolder").InstallationFolder
    }
}
$windowsSDKDir = Get-Item -Path $windowsSDKDir | Select-Object -ExpandProperty Parent | Select-Object -ExpandProperty FullName
Write-Output "Windows SDK Dir: $windowsSDKDir"

$win10SDKDirPath = [IO.Path]::Combine($windowsSDKDir, "10")
if (-not $SkipWindowsSDK) {
    # Copy the Windows SDK to $AutoSDKPlatformPath\Windows Kits\10
    # TODO: For reasons I completely don't understand, if I specify "Windows Kits", "10" as the destination, I get "Windows Kits\10\10" as the destination.
    $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "Windows Kits")
    if (-not (Test-Path $outDir)) {
        Write-Output "Creating directory: $outDir"
        New-Item -Path $outDir -ItemType Directory
    }
    Write-Output "Copying files from: $win10SDKDirPath"
    Write-Output "Output directory: $outDir"

    $capturedErrors = @()
    Copy-Item -Path $win10SDKDirPath -Destination $outDir -Recurse -ErrorVariable capturedErrors -ErrorAction SilentlyContinue
    $capturedErrors | ForEach-Object {
        if ($_ -notmatch "already exists") {
            Write-Error "Error: $_"
        }
    }
}

# Handle NetFX SDK and DIA SDK - Theoretically, you could have a NetFX SDK for different Kit installs, and a different DIA SDK for each Visual Studio install
# but I don't think there's any good reason to actually try to handle that, since Epic doesn't seem to handle it.

# NetFX SDK is one level above the SDK directory
if (-not $SkipNetFXSDK) {
    $parentPath = Get-Item -Path $windowsSDKDir | Select-Object -ExpandProperty FullName
    $netFXSDKDir = [IO.Path]::Combine($parentPath, "NETFXSDK")
    Write-Output "NetFX SDK Dir: $netFXSDKDir"

    # Copy the NetFX SDK to $AutoSDKPlatformPath\NETFXSDK
    # NetFX SDK is installed with the Windows SDK Kit
    #$outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "NETFXSDK")
    $outDir = $AutoSDKPlatformPath
    Write-Output "Output directory: $outDir"
    if (-not (Test-Path $outDir)) {
        Write-Output "Creating directory: $outDir"
        New-Item -Path $outDir -ItemType Directory
    }
    Write-Output "Copying files from: $netFXSDKDir"
    $capturedErrors = @()
    Copy-Item -Path $netFXSDKDir -Destination $outDir -Recurse -ErrorVariable capturedErrors -ErrorAction SilentlyContinue
    $capturedErrors | ForEach-Object {
        if ($_ -notmatch "already exists") {
            Write-Error "Error: $_"
        }
    }
}

if (-not $SkipDIASDK) {
    $DIASDKDir = [IO.Path]::Combine($vsPath, "DIA SDK")
    Write-Output "DIA SDK Dir: $DIASDKDir"

    # Copy the DIA SDK to $AutoSDKPlatformPath\DIA SDK
    # DIA SDK is installed with the Visual Studio install.
    #$outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "DIA SDK")
    $outDir = $AutoSDKPlatformPath
    Write-Output "Output directory: $outDir"
    if (-not (Test-Path $outDir)) {
        Write-Output "Creating directory: $outDir"
        New-Item -Path $outDir -ItemType Directory
    }
    Write-Output "Copying files from: $DIASDKDir"
    $capturedErrors = @()
    Copy-Item -Path $DIASDKDir -Destination $outDir -Recurse -ErrorVariable capturedErrors -ErrorAction SilentlyContinue
    $capturedErrors | ForEach-Object {
        if ($_ -notmatch "already exists") {
            Write-Error "Error: $_"
        }
    }
}

# TODO: print some final output summarizing what we did
Write-Output "Done"
