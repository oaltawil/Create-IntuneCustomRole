# Create-CustomIntuneRole.ps1

PowerShell script that creates a custom role - role definition - in Microsoft Intune.

1. The script requires a Csv file with two column headers: ResourceAction and Allowed (Yes/No). The list of allowed resource actions must be specified as resource_action, e.g. ManagedDevices_Read.

        ResourceAction,Allowed

        AndroidFota_Assign,No

        AndroidFota_Read,Yes

2. Creates a Microsoft.Graph.RoleDefinition object and uses the allowed resource actions from the Csv file for the corresponding property of the Role Definition object: roleDefinition.rolePermissions.resourceActions.allowedResourceActions.
3. Creates a custom role (role definition) using the Microsoft Graph Device Management cmdlet New-MgDeviceManagementRoleDefinition.
    -The cmdlet displays the headers and bodies of the Http request and response messages. The bodies of both messages include the complete definition of the custom role. The Http response includes an Http status code, e.g. 200: OK.
    - If a role with the same display name already exists, the script returns an error and exits. Use the -Force parameter to delete the conflicting role and create a new one.
4. The CustomIntuneRole.csv has been generated from the built-in "Help Desk Operator" role and defines the allowed resource actions for that role.
