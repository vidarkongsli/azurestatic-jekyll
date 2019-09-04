param(
    [Parameter(Mandatory)]
    $storageAccountName,
    [Parameter(Mandatory=$false)]
    [string]$errorDocument = 'error.html',
    [Parameter(Mandatory=$false)]
    [string]$indexDocument = 'index.html' 
)

az storage blob service-properties update --account-name $storageAccountName `
    --static-website --404-document $errorDocument --index-document $indexDocument