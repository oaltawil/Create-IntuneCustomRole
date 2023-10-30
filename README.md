# Create-CustomIntuneRole.ps1

PowerShell script that creates a custom role - role definition - in Microsoft Intune.

1. The script accepts two input file formats - a text file or a Csv file - that contain the list of allowed resource actions specified as resource_action, e.g. ManagedDevices_Read.
    - A simple text file with the list of allowed resource actions:

        AndroidFota_Read

        AndroidSync_Read

    - A Csv file that contains two column headers: ResourceAction and Allowed (Yes/No):

        ResourceAction,Allowed

        AndroidFota_Assign,No

        AndroidFota_Read,Yes

2. Creates a Microsoft.Graph.RoleDefinition object and uses the allowed resource actions from the Csv file for the corresponding property of the Role Definition object: roleDefinition.rolePermissions.resourceActions.allowedResourceActions.
3. Creates a custom role (role definition) using the MS Graph cmdlet New-MgDeviceManagementRoleDefinition. The cmdlet returns an Http response with an Http status code (200: OK - Request succeeded) and the role definition object in the body of the response.

- If a role with the same display name already exists, the script returns an error and exits. Use the -Force parameter to delete the conflicting role and create a new one.
- Usage: .\Create-CustomIntuneRole.ps1 -RoleDefinitionCsvFilePath "$ENV:USERPROFILE\Documents\CustomIntuneRole.csv" -RoleDisplayName "Help Desk L2 Administrator" -RoleDescription "Can view and manage various aspects of Microsoft Intune"
- The included Csv file "CustomIntuneRole.csv" defines the allowed resource actions for the built-in "Help Desk Operator" role.
