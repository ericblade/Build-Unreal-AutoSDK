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

> -OnlyVCTools
Only copy Visual C++ Toolset

> -OnlyWindowsSDK
Only copy Windows SDK

> -OnlyNetFXSDK
Only copy NetFX SDK

> -OnlyDIASDK
Only copy DIA SDK

## Using your new AutoSDK setup
There are at least a few ways you can use AutoSDK:

- If you are using your own custom build system, you can place the AutoSDK root somewhere on a network drive,
and then on each Unreal builder that needs to use the AutoSDK, you can set the environment variable UE_SDKS_ROOT
to the location containing the root AutoSDK file system.
- You can also copy it locally to every build machine, if you'd like to spend the time to do that, which may be
useful, versus network mounting it, depending on your situation.
- You can also submit it to your perforce or other source control system, and have your build scripts ensure that
each machine has a current copy of the AutoSDK.
- If you use Unreal Horde, it uses the latter method -- you can configure an autoSdk property in the Unreal Horde
server's globals.json file, under the "perforceClusters" section, something to the tune of
```json
			"autoSdk": [
				{
					"name": "AutoSDK-Main",
					"properties": [
						"OSFamily=Windows"
					],
					"stream": "//AutoSDK/main"
				}
			]
```
then add ```"useAutoSdk": true``` to each workspaceTypes entry in your project.json.  If you do this, each of your
Horde agents will automatically pull a copy of that perforce stream, and use those SDKs to build with.

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[Apache 2.0](https://choosealicense.com/licenses/apache/)

You are not required to disclose your use of this, include it with any product, or anything else.  Contributions are very much appreciated, open source makes most of the computing world go 'round!
