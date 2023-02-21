<#
    .SYNOPSIS
        This function gets the merged and filtered tenant data for all tenants in specified data paths, for a
        specified region and environment. It then sets a $tenantsJson azure devops variable with the value and
        outputs the json to the console.
    .DESCRIPTION
        The function loops through each tenant, and for each tenant loops through each possible file that could contain tenant data, 
        merging any new data, and applying any override of existing tenant data. If all required data exists for a tenant, the tenant data 
        is filtered for only the required attributes with non-null values, then a custom tenant object is created from the filtered tenant data,
        and the custom tenant object is added to the tenant objects collection. Finally, all tenant objects are returned as a JSON array. 
    .PARAMETER reg
        The region that the tenant data is related to.
    .PARAMETER env
        The environment that the tenant data is related to.
    .PARAMETER tenantsDataPaths
        The data paths containing the tenant data. As they will be processed in the order they are supplied tt is expected that a common path is follwoed by an
        application specific path to allow for application specific overrides to apply correctly.
    .PARAMETER requiredData
        The required data that must exist for a tenant, for that tenant data to be returned. For example, this
        could be the values 'group' and 'ring' for an MT deploy, filtering out any tenants that
        aren't supported for an MT deploy for this region an enviornment
    .OUTPUTS
        A JSON array containing the filtered and merged tenant data for all tenants.
    .EXAMPLE
        GetTenantsData -reg "au1" -env "qa" -tenantsDataPaths @("{path}\Common\Data\Tenants","{path}\Application\Data\Tenants") -requiredData @("group", "ring")
#>    
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $reg,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $env,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] 
    $tenantsDataPaths,
    [Parameter(Mandatory = $false)]
    [string[]] 
    $requiredData
)

# Define allowable file names that can contain tenant data for the supplied region and environment
$tenantDataFileNames = @("tenant.json", "tenant-reg_$reg.json", "tenant-env_$env.json", "tenant-reg_$reg-env_$env.json")
# Get all tenant names using the unique list of directory names in all supplied tenant data paths
$tenantNames = Get-ChildItem -Path $tenantsDataPaths -Directory | Select-Object -ExpandProperty Name | Sort-Object -Unique
# Tenants object collection
$tenantObjs = @()
# Get data for each tenant
foreach ($tenantName in $tenantNames) {
    Write-Host $tenantName
    $tenantData = @()
    foreach ($tenantDataPath in $tenantsDataPaths) {
        foreach ($tenantDataFileName in $tenantDataFileNames) {
            $tenantDefaultsPath = Join-Path $tenantDataPath $tenantDataFileName
            $tenantSpecificPath = Join-Path $tenantDataPath $tenantName $tenantDataFileName
            $filePaths = @($tenantDefaultsPath, $tenantSpecificPath )
            
            foreach ($filePath in $filePaths) {
                if (!(Test-Path $filePath -PathType Leaf)) { continue }
                $fileContent = Get-Content -Path $filePath | Out-String
                $fileObjs = ConvertFrom-Json $fileContent
                foreach ($fileObj in $fileObjs) {
                    $match = $false
                    # override existing tenant data if possible
                    foreach ($tenantDataObj in $tenantData) {                     
                        if ($fileObj.name -eq $tenantDataObj.name) {
                            $tenantDataObj.value = $fileObj.value
                            $match = $true
                            break
                        }                           
                    }
                    # add new tenant data if no match
                    if (-not $match) {
                        $tenantData += [PSCustomObject]@{
                            name  = $fileObj.name
                            value = $fileObj.value
                        }
                    }
                }
            }    
        }
    }   
    # ensure tenant data has any required attributes with non-null values
    $filteredTenantData = $tenantData | Where-Object { $_.name -in $requiredData -and $_.value }
    if (!($filteredTenantData.Count -eq $requiredData.Count) ) { continue }
    # make custom tenant object from validated tenant data 
    $tenantObj = [PSCustomObject]@{name = $tenantName }
    foreach ($tenantDataObj in $tenantData) {
        $tenantObj | Add-Member -NotePropertyName $tenantDataObj.name -NotePropertyValue $tenantDataObj.value
    }
    # add custom tenant object to tenants object collection
    $tenantObjs += $tenantObj
}

# get all tenant data as minified json array from tenants object collection
$tenantsJson = ($tenantObjs.Count -eq 0) ? "[]" : $tenantObjs | ConvertTo-Json -Depth 3 -Compress

# Set the Azure DevOps variable to the output of the GetTenantsData function
Write-Host "##vso[task.setvariable variable=tenantsJson]$tenantsJson"
Write-Host $tenantsJson