# Copy the Unreal Windows SDK and tools to the specified AutoSDK directory, HostWin64\Win64 into subdirectories for each Visual Studio version.
# Initial version only does Win64 host and Win64 target.  Support for additional hosts and targets will be necessary.
# TODO: support -WhatIf switch
# TODO: add Host and Target platform selection, support Android targets, Linux targets and hosts, etc.

param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
    [Parameter()] [switch] $Clean,
    [Parameter()] [switch] $SkipVCTools,
    [Parameter()] [switch] $SkipWindowsSDK,
    [Parameter()] [switch] $SkipNetFXSDK,
    [Parameter()] [switch] $SkipDIASDK,
    [Parameter()] [switch] $SkipAndroid,
    [Parameter()] [switch] $OnlyVCTools, # TODO: make it so only one of these Only params can be used at once, PowerShell should be able to enforce that, I think
    [Parameter()] [switch] $OnlyWindowsSDK,
    [Parameter()] [switch] $OnlyNetFXSDK,
    [Parameter()] [switch] $OnlyDIASDK,
    [Parameter()] [switch] $OnlyAndroid,
    [Parameter()] [string] $UnrealRoot # Provide an UnrealRoot to determine what SDK versions are supported by it's provided AutoSDK section
)

. ".\Get-AutoSDK-PlatformPath.ps1"
. ".\Get-VisualStudio-Installs.ps1"
. ".\Get-WindowsSDK-Path.ps1"
. ".\Copy-SDK.ps1"
. ".\Get-VS-Version-By-Tool-Version.ps1"
. ".\Get-Android-SDKs.ps1"

if ($OnlyVCTools) {
    $SkipWindowsSDK = $true
    $SkipNetFXSDK = $true
    $SkipDIASDK = $true
    $SkipAndroid = $true
}
if ($OnlyWindowsSDK) {
    $SkipVCTools = $true
    $SkipNetFXSDK = $true
    $SkipDIASDK = $true
    $SkipAndroid = $true
}
if ($OnlyNetFXSDK) {
    $SkipVCTools = $true
    $SkipWindowsSDK = $true
    $SkipDIASDK = $true
    $SkipAndroid = $true
}
if ($OnlyDIASDK) {
    $SkipVCTools = $true
    $SkipWindowsSDK = $true
    $SkipNetFXSDK = $true
    $SkipAndroid = $true
}
if ($OnlyAndroid) {
    $SkipVCTools = $true
    $SkipWindowsSDK = $true
    $SkipNetFXSDK = $true
    $SkipDIASDK = $true
}

if ($UnrealRoot) {
    $UnrealAutoSDKBasePath = [IO.Path]::Combine($UnrealRoot, "Engine", "Extras", "AutoSDK")
    if (-not (Test-Path -Path $UnrealAutoSDKBasePath)) {
        Write-Error "UnrealRoot provided, but AutoSDK path not found: $UnrealAutoSDKBasePath"
        Exit -1
    }
    Write-Output "Using Unreal Root Path to determine AutoSDK path: $UnrealAutoSDKBasePath"
    # Get list of directories in the UnrealAutoSDKBasePath, that is the list of hosts supported.
    $Hosts = Get-ChildItem -Path $UnrealAutoSDKBasePath | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
    Write-Output "Hosts: $($Hosts -join ', ')"
    $SupportedSDKs = @()
    # Enumerate the Hosts directories, to get the lists of targets supported.
    $Hosts | ForEach-Object {
        $HostPath = [IO.Path]::Combine($UnrealAutoSDKBasePath, $_)
        $Targets = Get-ChildItem -Path $HostPath | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
        # Enumerate the HostPath directories, to get the SDK Versions supported.
        $BuildHost = $_
        $Targets | ForEach-Object {
            $TargetPath = [IO.Path]::Combine($HostPath, $_)
            $SDKVersions = Get-ChildItem -Path $TargetPath | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
            # if hostpath is HostWin64 and target is anything other than LLVM, then skip
            if ($BuildHost -eq "HostWin64" -and $_ -eq "Win64") {
                # ignore DIASDK, VS, Windows Kits, as Unreal autodetects their presence and there are no useful scripts included in their AutoSDK
                $SDKVersions = $SDKVersions | Where-Object { @("DIA SDK", "VS2017", "VS2019", "VS2022", "Windows Kits") -notcontains $_ }
            }

            $SupportedSDKs += @{
                Host = $BuildHost
                Target = $_
                Versions = $SDKVersions
            }
        }
    }
    # Write a list of supported SDKs in a tabular format
    Write-Output "Supported SDKs for UnrealRoot: $UnrealRoot"
    $SupportedSDKs | ForEach-Object {
        Write-Output "Host: $($_.Host) Target: $($_.Target) SDK Versions: $($_.Versions -join ', ')"
    }
}

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

$VSInstalls = Get-VisualStudio-Installs
Write-Output "Visual Studio installs: $($VSInstalls.Count)"
if ($VSInstalls.Count -eq 0) {
    Write-Error "No Visual Studio installs found"
    Exit -1
}
Write-Verbose "Visual Studio install 1: $($VSInstalls[0])"

if (-not $SkipVCTools) {
    $VSInstalls | ForEach-Object {
        $vsPath = $_.installationPath
        $vsVersion = $_.buildVersion
        Write-Output "Visual Studio $vsVersion path: $vsPath"
        $vcToolsPath = [IO.Path]::Combine($vsPath, "VC", "Tools", "MSVC")
        Write-Output "VC Tools path: $vcToolsPath"
        Get-ChildItem -Path $vcToolsPath | ForEach-Object {
            $vcToolsVersion = $_.Name
            $outDir = Get-VS-Version-By-Tool-Version -ToolVersion $vcToolsVersion
            Write-Output "VC Tools version: $vcToolsVersion $outDir"
            if (-not [string]::IsNullOrEmpty($outDir)) {
                $inToolsPath = [IO.Path]::Combine($vcToolsPath, $vcToolsVersion)
                Write-Output "Copying VC Tools from $inToolsPath to $outDir"
                Copy-SDK -Source $inToolsPath -Destination ([IO.Path]::Combine($AutoSDKPlatformPath, $outDir))
            }
            else {
                Write-Output "Unknown VC Tools version: $vcToolsVersion update the Build-Unreal-AutoSDK.ps1 script"
            }
        }
    }
}

$windowsSDKDir = Get-WindowsSDK-Path
Write-Output "Windows SDK Dir: $windowsSDKDir"

if (-not $SkipWindowsSDK) {
    # Copy the Windows SDK to $AutoSDKPlatformPath\Windows Kits
    $win10SDKDirPath = [IO.Path]::Combine($windowsSDKDir, "10")
    $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "Windows Kits")
    Copy-SDK -Source $win10SDKDirPath -Destination $outDir
}

# Handle NetFX SDK and DIA SDK - Theoretically, you could have a NetFX SDK for different Kit installs, and a different DIA SDK for each Visual Studio install
# but I don't think there's any good reason to actually try to handle that, since Epic doesn't seem to handle it.

# NetFX SDK is one level above the SDK directory
if (-not $SkipNetFXSDK) {
    $parentPath = Get-Item -Path $windowsSDKDir | Select-Object -ExpandProperty FullName
    $netFXSDKDir = [IO.Path]::Combine($parentPath, "NETFXSDK")
    # check if preferredVersion is available
    $versions = @(Get-ChildItem -Path $netFXSDKDir | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name)
    $preferredVersion = @('4.6.2', '4.6.1', '4.6')
    $shouldUseVersion = $versions | Where-Object { $preferredVersion -contains $_ } | Select-Object -First 1
    if ($shouldUseVersion) {
        $netFXSDKDir = [IO.Path]::Combine($netFXSDKDir, $shouldUseVersion)
        $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "Windows Kits", "NETFXSDK") # why don't i need to put the version on here?
    }
    else {
        $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "Windows Kits", "NETFXSDK")
        Write-Warning "Unreal may not support using AutoSDK with NETFXSDK versions other than 4.6 - 4.6.2. Versions found: $($versions -join ', ')"
        Write-Warning "If your version is not supported, compiling Lightmass will fail with a message to install .Net 4.6 or better."
        Write-Warning "A bug has been filed with Epic to support other versions, as the regular compiler step does."
        Write-Warning "You may install .Net 4.6.2 locally and re-run this script to get the correct SDK, or manually put it into your AutoSDK."
        Write-Warning "We are going to copy the versions found, but Unreal may not use them until this bug is fixed."
        Write-Warning "This bug was found in the 5.6 development tree."
    }

    Copy-SDK -Source $netFXSDKDir -Destination $outDir
}

# DIA SDK is installed with the Visual Studio install.
if (-not $SkipDIASDK) {
    $DIASDKDir = [IO.Path]::Combine($VSInstalls[0].installationPath, "DIA SDK")
    $outDir = $AutoSDKPlatformPath

    Copy-SDK -Source $DIASDKDir -Destination $outDir
}

if (-not $SkipAndroid) {
    Write-Output "Warning: only enumerating Android SDKs, copying functionality to be implemented, as soon as I figure out how it is supposed to be laid out."
    Get-Android-SDKs
}

# TODO: print some final output summarizing what we did
Write-Output "Done"
