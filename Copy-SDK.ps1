# TODO: use robocopy instead of Copy-Item for efficiency
function Copy-SDK {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination
    )

    Write-Output "Copying SDK from $Source to $Destination"
    if (-not (Test-Path $Source)) {
        throw "Source path not found: $Source"
    }
    if (-not (Test-Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory
    }
    $capturedErrors = @()
    Copy-Item -Path $Source -Destination $Destination -Recurse -ErrorAction SilentlyContinue -ErrorVariable capturedErrors
    $capturedErrors | ForEach-Object {
        if ($_ -notmatch "already exists") {
            Write-Error "Error: $_"
        }
    }
}