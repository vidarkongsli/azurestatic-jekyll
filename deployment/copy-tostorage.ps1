<#
.SYNOPSIS
    Copy files to blob storage, setting cache-control information
.DESCRIPTION
    Batch copy files to blob storage, and setting content-type and cache-control information for efficient web consumption
.EXAMPLE
    PS C:\> .\copy-tostorage.ps1 -sourceDirectory dist -storageAccountName theaccountname -purge
    Explanation of what the example does
.INPUTS
.OUTPUTS
.NOTES
    Written by Vidar Kongsli (https://github.com/vidarkongsli)
#>
param(
    [Parameter(Mandatory)]
    $storageAccountName,
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path -Path $_ -PathType Container})]
    $sourceDirectory,
    [switch]$purge,
    $filePatternForLongCaching = '\.(css)|(js)$',
    $normalCacheTimeInSeconds = 600, # 10 minutes
    $extendedCacheTimeInSeconds = 2628000, # A month
    $containerName = '$web'
)
Push-Location $sourceDirectory
$ErrorActionPreference = 'stop'
try {
    $sourceFiles = Get-ChildItem -Recurse -File `
        | Select-Object -ExpandProperty FullName `
        | Resolve-Path -Relative
    $sourceFiles `
        | ForEach-Object {
            $fileName = Split-Path $_ -Leaf
            if ($fileName -match $filePatternForLongCaching) {
                Write-host "Setting $_ to be cached for $extendedCacheTimeInSeconds"
                $cacheTime = $extendedCacheTimeInSeconds
            } else {
                Write-host "Setting $_ to be cached in $normalCacheTimeInSeconds"
                $cacheTime = $normalCacheTimeInSeconds
            }
            az storage blob upload -c $containerName --file $_ --name $_ --account-name $storageAccountName `
                --content-cache-control "public,max-age=$cacheTime"
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed uploading $_"
            }
        }
    
        if ($purge) {
            $destinationData = az storage blob list -c $containerName --account-name $storageAccountName | convertfrom-json
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed fetching file list"
            }
            $destinationData `
                | ForEach-Object { Select-Object -inputobject $_ -expandproperty name } `
                | Where-Object { $sourceFiles -notcontains ".\$($_.Replace('/','\'))" } `
                | ForEach-Object {
                    Write-host "Deleting $_"
                    az storage blob delete -c $containerName --account-name $storageAccountName -n $_
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed deleting $_"
                    }
                }
        } else {
            Write-host "Purging skipped."
        }
} finally {
    Pop-Location
}