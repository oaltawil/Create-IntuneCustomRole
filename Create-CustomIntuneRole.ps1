<#
.SYNOPSIS
This script creates a new custom role, more specifically, a new role definition, in Microsoft Intune based on a list of resource actions described in a Csv file.

.DESCRIPTION
1. The script reads a Csv file that contains the allowed resource actions for the new role definition. The Csv file should have the following format:
    ResourceAction,Allowed,Description
    AndroidFota_Assign,No,Assign Android firmware over-the-air (FOTA) deployments to Azure AD security groups.
    ...
2. Defines a Microsoft.Graph.RoleDefinition object and uses the allowed resource actions from the Csv file for the corresponding property of the Role Definition object: rolePermissions -> resourceActions -> allowedResourceActions.
3. Creates a custom role (role definition) using the MS Graph cmdlet New-MgDeviceManagementRoleDefinition. The cmdlet returns an Http response with an Http status code (200: OK - Request succeeded) and the role definition object in the body of the response.
  
- Warning: If a role with the same display name already exists, that role will be deleted and a new one will be created.

.PARAMETER RoleDefinitionCsvFilePath
Full path to a Csv file with the following schema (column headers): "ResourceAction", "Allowed", and "Description".

.PARAMETER RoleDisplayName
Display name of the custom role.

.PARAMETER RoleDescription
Description of the custom role.

.EXAMPLE
.\Create-CustomIntuneRole.ps1 -RoleDefinitionCsvFilePath "$ENV:USERPROFILE\Documents\CustomIntuneRole.csv" -RoleDisplayName "Help Desk L2 Administrator" -RoleDescription "Can view and manage various aspects of Microsoft Intune"

.EXAMPLE
.\Create-CustomIntuneRole.ps1 "$ENV:USERPROFILE\Documents\CustomIntuneRole.csv" "Help Desk L2 Administrator" "Can view and manage various aspects of Microsoft Intune"

#>

#Requires -Modules Microsoft.Graph.DeviceManagement.Administration, Microsoft.Graph.Authentication

param (
  [String]
  [Parameter(Mandatory, Position=0)]
  [ValidateNotNullOrEmpty()]
  $RoleDefinitionCsvFilePath,
  [String]
  [Parameter(Mandatory, Position=1)]
  [ValidateNotNullOrEmpty()]
  $RoleDisplayName,
  [String]
  [Parameter(Mandatory, Position=2)]
  [ValidateNotNullOrEmpty()]
  $RoleDescription
)

<#
1. Import the Csv file.

  -Column Headers:
    ResourceAction,Allowed,Description

  - Sample:
    AndroidFota_Assign,No,Assign Android firmware over-the-air (FOTA) deployments to Azure AD security groups.
#>

# Import the Csv file to a collection (array) of PSCustomObject objects
$ResourceActionCollection = Import-Csv -Path $RoleDefinitionCsvFilePath -ErrorAction Stop

# Verify that at least one record was returned
if (-not $ResourceActionCollection.count) {
  
  Write-Error "The Csv file did not contain any records."

}

$CsvColumnHeaders = @("ResourceAction", "Allowed", "Description")

# Verify that the PSCustomObject objects have the same properties as the Csv column headers
$ResourceActionCollection | Get-Member -MemberType NoteProperty | ForEach-Object {
    
    if ($_.Name -notin $CsvColumnHeaders) {

    Write-Error "The Csv file does not have the correct schema: ResourceAction, Allowed, and Description."

  }
}

# Retrieve the allowed resource actions. Prepend the provider name "Microsoft.Intune_" to the resource action name
$AllowedResourceActions = $ResourceActionCollection | Where-Object Allowed -eq "Yes" | ForEach-Object {"Microsoft.Intune_$($_.ResourceAction)"}

<#
2. Create the MS Graph Role Definition object

  - Define a Microsoft.Graph.RoleDefinition object using a hashtable
  - Use the allowed resource actions (from the Csv file) for the corresponding property of the MS Graph Role Definition object
#>

Import-Module Microsoft.Graph.DeviceManagement.Administration -ErrorAction Stop

# Define the Microsoft.Graph.RoleDefinition Json object using a hashtable
$params = @{
  "@odata.type" = "#microsoft.graph.roleDefinition"
  displayName = $RoleDisplayName
  description = $RoleDescription
  rolePermissions = @(
    @{
      "@odata.type" = "microsoft.graph.rolePermission"
      resourceActions = @(
        @{
          "@odata.type" = "microsoft.graph.resourceAction"
          allowedResourceActions = $AllowedResourceActions
          notAllowedResourceActions = @()
        }
      )
    }
  )
  isBuiltIn = $false
}

<#
3. Connect to MS Graph and create the Role Definition

  - Delete any existing role that has the same display name
#>

# Connect to Microsoft Graph and request the "RBAC Read/Write" scope
Connect-MgGraph -UseDeviceAuthentication -Scopes DeviceManagementRBAC.ReadWrite.All

$ExistingRoleDefinition = Get-MgDeviceManagementRoleDefinition | Where-Object DisplayName -like $RoleDisplayName

if ($ExistingRoleDefinition) {

  Write-Host "`n"

  Write-Warning "The role $RoleDisplayName already exists and will be deleted.`n"

  Remove-MgDeviceManagementRoleDefinition -RoleDefinitionId $ExistingRoleDefinition.Id -Confirm:$false

}

# Create the Custom Intune (Role Definition)
New-MgDeviceManagementRoleDefinition -BodyParameter $params -Debug -Confirm:$false
