<#
.SYNOPSIS
This script creates a new custom role - more specifically, a new custom role definition - in Microsoft Intune based on a list of resource actions described in a text file.

.DESCRIPTION
1. The script accepts two input file formats - a text file or a Csv file - that contain the list of allowed resource actions specified as resource_action, e.g. ManagedDevices_Read.
  1.1 A simple text file with the list of allowed resource actions:
  AndroidFota_Read
  AndroidSync_Read
  ...

  1.2 A Csv file that contains two column headers: ResourceAction and Allowed (Yes/No):
    ResourceAction,Allowed
    AndroidFota_Assign,No
    ...
    AndroidFota_Read,Yes
    ...
2. Creates a Microsoft.Graph.RoleDefinition object and uses the allowed resource actions from the Csv file for the corresponding property of the Role Definition object: roleDefinition.rolePermissions.resourceActions.allowedResourceActions.
3. Creates a custom role (role definition) using the MS Graph cmdlet New-MgDeviceManagementRoleDefinition. The cmdlet returns an Http response with an Http status code (200: OK - Request succeeded) and the role definition object in the body of the response.

If a role with the same display name already exists, the script returns an error and exits. Use the -Force parameter to delete the conflicting role and create a new one.

.PARAMETER RoleDefinitionFilePath
Full path to a .txt (Text) file that contains the list of allowed resource actions. Example:
  CloudAttach_Collections
  ManagedDevices_Read
Alternatively, the full path to a .csv (comma-separated value) file with two column headers: "ResourceAction" and "Allowed". Additional columns, e.g. Description, will be ignored. Example:
  ResourceAction,Allowed
  ManagedDevices_Read,Yes
  ManagedDevices_Delete,No

.PARAMETER RoleDisplayName
Display name of the custom role.

.PARAMETER RoleDescription
Description of the custom role.

.PARAMETER Force
Deletes a conflicting role definition that has the same display name.

.EXAMPLE
.\Create-CustomIntuneRole.ps1 -RoleDefinitionFilePath "$ENV:USERPROFILE\Documents\CustomIntuneRole.csv" -RoleDisplayName "Help Desk L2 Administrator" -RoleDescription "Can view and manage various aspects of Microsoft Intune"

.EXAMPLE
.\Create-CustomIntuneRole.ps1 "$ENV:USERPROFILE\Documents\CustomIntuneRole.txt" "Help Desk L2 Administrator" "Can view and manage various aspects of Microsoft Intune" -Force

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

1. Import the Txt or Csv file.

#>

# Verify that the input file exists
$RoleDefinitionFile = Get-Item -Path $RoleDefinitionFilePath

if ($RoleDefinitionFile.Extension -eq ".txt")
{

  # Read the contents of the input file
  $RoleDefinitionFileContent = Get-Content -Path $RoleDefinitionFilePath

  # Verify that the input file is not empty
  if (-not $RoleDefinitionFileContent) {

    Write-Error "The input text file $RoleDefinitionFilePath is empty."

  }

  # Prepend the provider name "Microsoft.Intune_" to the resource action value expressed as "resource_action"
  # Example: Microsoft.Intune_ManagedDevices_Read
  $AllowedResourceActions = $RoleDefinitionFileContent | ForEach-Object {"Microsoft.Intune_$($_)"}

}
elseif ($RoleDefinitionFile.Extension -eq ".csv") {

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

  Write-Error "Unsupported file extension: $($RoleDefinitionFile.Extension). The script expects either a .txt or .csv file extension."

}

<#

2. Create the MS Graph Role Definition object

  - Define a Microsoft.Graph.RoleDefinition object using a hashtable
  - Use the allowed resource actions (from the Txt file or Csv file) for the corresponding property of the MS Graph Role Definition object

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

# Create the Custom Intune (Role Definition) by passing the Microsoft.Graph.roleDefinition object
New-MgDeviceManagementRoleDefinition -BodyParameter $params -Debug -Confirm:$false
