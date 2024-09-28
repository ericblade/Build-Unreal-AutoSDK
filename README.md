# Build-Unreal-AutoSDK

Build-Unreal-AutoSDK is a collection of PowerShell scripts that you run on a machine that is completely setup for Unreal SDK development, and it will copy all of the SDKs to a new location that matches Unreal's expected "AutoSDK" spec, so that you may use it with other builder machines without having to manually set them all up.  See the Epic documentation for further details.

## Installation

```bash
git clone https://github.com/ericblade/Build-Unreal-AutoSDK
```

## Usage

From a Windows command prompt
```bash
VsDevCmd
powershell -ExecutionPolicy bypass c:\path\to\Build-Unreal-AutoSDK\Build-Unreal-AutoSDK.ps1 -Path c:\path\to\AutoSDKroot\
```

Additional command line options:

> -Clean
Remove all things in the AutoSDK root path before copying.

> -SkipVCTools
Do not copy over Visual C++ Toolset

> -SkipWindowsSDK
Do not copy over the Windows Kit

> -SkipNetFXSDK
Do not copy over the NetFX SDK

> -SkipDIASDK
Do not copy over the DIA SDK

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[Apache 2.0](https://choosealicense.com/licenses/apache/)

You are not required to disclose your use of this, include it with any product, or anything else.  Contributions are very much appreciated, open source makes most of the computing world go 'round!
