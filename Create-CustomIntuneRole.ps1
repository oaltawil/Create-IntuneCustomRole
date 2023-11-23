<#
.NOTES
This sample script is not supported under any Microsoft standard support program or service. The sample script is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample script remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the script be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample script, even if Microsoft has been advised of the possibility of such damages.

.SYNOPSIS
This script creates a new custom role - more specifically, a new custom role definition - in Microsoft Intune based on a list of resource actions described in a text file.

.DESCRIPTION
1. The script requires a Csv file that contains two column headers: ResourceAction and Allowed (Yes/No). The resource actions must be formatted as resource_action, e.g. ManagedDevices_Read.
    ResourceAction,Allowed
    AndroidFota_Read,Yes
    AndroidSync_Read,Yes
2. Creates a Microsoft.Graph.RoleDefinition object and uses the allowed resource actions from the input file for the corresponding property of the Role Definition object: roleDefinition.rolePermissions.resourceActions.allowedResourceActions.
3. Creates a custom role (role definition) using the MS Graph cmdlet New-MgDeviceManagementRoleDefinition. The cmdlet returns an Http response with an Http status code (200: OK - Request succeeded) and the role definition object in the body of the response.

If a role with the same display name already exists, the script returns an error and exits. Use the -Force parameter to delete the conflicting role and create a new one.

.PARAMETER RoleDefinitionFilePath
The full path to a .csv (comma-separated value) file with two column headers: "ResourceAction" and "Allowed". Additional columns, e.g. Description, will be ignored. Example:
  ResourceAction,Allowed
  DeviceCompliancePolices_Create,No
  DeviceCompliancePolices_Read,Yes
  DeviceCompliancePolices_ViewReports,Yes

.PARAMETER RoleDisplayName
Display name of the custom role.

.PARAMETER RoleDescription
Description of the custom role.

.PARAMETER Force
Deletes a conflicting role definition that has the same display name.

.EXAMPLE
.\Create-CustomIntuneRole.ps1 -RoleDefinitionFilePath "$ENV:USERPROFILE\Documents\CustomIntuneRole.csv" -RoleDisplayName "Help Desk L2 Administrator" -RoleDescription "Can view and manage various aspects of Microsoft Intune"

#>

#Requires -Modules Microsoft.Graph.DeviceManagement.Administration, Microsoft.Graph.Authentication

param (
  [String]
  [Parameter(Mandatory, Position=0)]
  [ValidateNotNullOrEmpty()]
  $RoleDefinitionFilePath,
  [String]
  [Parameter(Mandatory, Position=1)]
  [ValidateNotNullOrEmpty()]
  $RoleDisplayName,
  [String]
  [Parameter(Mandatory, Position=2)]
  [ValidateNotNullOrEmpty()]
  $RoleDescription,
  [Switch]
  $Force
)

# Stop script execution if any error occurs
$ErrorActionPreference = 'Stop'

<#

1. Import the Csv file.

#>

# Verify that the input file exists
$RoleDefinitionFile = Get-Item -Path $RoleDefinitionFilePath

if ($RoleDefinitionFile.Extension -eq ".csv") {

  # Import the Csv file to a collection (array) of PSCustomObject objects
  $ResourceActionCollection = Import-Csv -Path $RoleDefinitionFilePath

  # Verify that at least one record was returned
  if (-not $ResourceActionCollection.count) {
    
    Write-Error "The Csv file does not contain any records."

  }

  # Retrieve the properties of the PSCustomObject class
  $PSCustomObjectProperties = $ResourceActionCollection | Get-Member -MemberType NoteProperty | ForEach-Object {$_.Name}

  # Verify that the PSCustomObject class has two properties called "ResourceAction" and "Allowed"
  if (("ResourceAction" -notin $PSCustomObjectProperties) -or ("Allowed" -notin $PSCustomObjectProperties)) {

    Write-Error "The Csv file does not have the correct schema: ResourceAction and Allowed."

  }

  # Retrieve the allowed resource actions. Prepend the provider name "Microsoft.Intune_" to the resource action name
  $AllowedResourceActions = $ResourceActionCollection | Where-Object Allowed -eq "Yes" | ForEach-Object {"Microsoft.Intune_$($_.ResourceAction)"}

}
else {

  Write-Error "Unsupported file extension: $($RoleDefinitionFile.Extension). The script expects requires a .csv file extension."

}

<#

2. Create the MS Graph Role Definition object

  - Define a Microsoft.Graph.RoleDefinition object using a hashtable
  - Use the allowed resource actions (from the Csv file) for the corresponding property of the MS Graph Role Definition object

#>

Import-Module Microsoft.Graph.DeviceManagement.Administration

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

#>

# Connect to Microsoft Graph and request the "RBAC Read/Write" scope
Connect-MgGraph -Scopes DeviceManagementRBAC.ReadWrite.All

# Verify whether a conflicting role with the same display name already exists
$ExistingRoleDefinition = Get-MgDeviceManagementRoleDefinition | Where-Object DisplayName -like $RoleDisplayName

# If an existing role has the same display name, return an error and exit. Use the -Force parameter to delete the conflicting role.
if ($ExistingRoleDefinition) {

  if ($Force) {

    Write-Warning "The role $RoleDisplayName already exists and will be deleted."

    Remove-MgDeviceManagementRoleDefinition -RoleDefinitionId $ExistingRoleDefinition.Id -Confirm:$false

  }

  else {

    Write-Error "A conflicting role with the same display name already exists. Use the -Force parameter to delete the conflicting role."

  }
}

# Create the custom Intune role by passing the Microsoft.Graph.roleDefinition object to the BodyParameter parameter of the New-MgDeviceManagementRoleDefinition cmdlet
New-MgDeviceManagementRoleDefinition -BodyParameter $params -Debug -Confirm:$false
