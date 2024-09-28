function Get-VisualStudio-Installs {
    $pf = [Environment]::GetFolderPath('ProgramFilesx86') # couldn't figure out the correct syntax to do this from string interpolation
    $vsWhere = [IO.Path]::Combine($pf, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe')
    if (-not (Test-Path $vsWhere)) {
        throw "Could not find vswhere.exe at $vsWhere - are you sure Visual Studio 2017+ is installed?"
    }

    $vsWhereArgs = @(
        '-format'
        'json'
        '-all'
        '-latest'
        '-requires'
        'Microsoft.Component.MSBuild'
    )
    & $vsWhere @vsWhereArgs | ConvertFrom-Json
}