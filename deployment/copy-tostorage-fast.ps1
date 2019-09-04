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
    Write-host "Uploading to storage $storageAccountName container $containerName"
    az storage blob upload-batch -d $containerName -s .\ --account-name $storageAccountName `
        --content-cache-control "public,max-age=$normalCacheTimeInSeconds" --no-progress
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed uploading files from $(Get-Location)"
    }

    Write-host "Fetching list of blobs from storage $storageAccountName container $containerName"
    $destinationData = az storage blob list -c $containerName --account-name $storageAccountName | convertfrom-json
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed fetching file list from blob storage"
    }

    $destinationFiles = $destinationData | ForEach-Object { Select-Object -inputobject $_ -expandproperty name }
    $destinationFiles `
        | Where-Object {
            $fileName = Split-Path $_ -Leaf
            $fileName -match $filePatternForLongCaching
        } `
        | ForEach-Object {
            Write-host "Updating cache settings for $_"
            az storage blob update -c $containerName -n $_  `
                --account-name $storageAccountName `
                --content-cache-control "public,max-age=$extendedCacheTimeInSeconds,immutable"
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Error updating cache settings for $_"
            }
        }
    
        if ($purge) {
            $sourceFiles = Get-ChildItem -Recurse -File `
                | Select-Object -ExpandProperty FullName `
                | Resolve-Path -Relative

            $destinationFiles `
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