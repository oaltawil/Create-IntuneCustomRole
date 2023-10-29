# Create-IntuneCustomRole
PowerShell script that creates a new custom role in Microsoft Intune
1. Requires a Csv file that contains the allowed resource actions for the new role definition. The Csv file should have the following format:
    ResourceAction,Allowed,Description
    AndroidFota_Assign,No,Assign Android firmware over-the-air (FOTA) deployments to Azure AD security groups.
    ...
2. Defines a Microsoft.Graph.RoleDefinition object and uses the allowed resource actions from the Csv file for the corresponding property of the Role Definition object.
3. Creates a custom role (role definition) using the MS Graph cmdlet New-MgDeviceManagementRoleDefinition. The cmdlet returns an Http response with an Http status code (200: OK - Request succeeded) and the role definition object in the body of the response.

Warning: If a role with the same display name already exists, that role will be deleted and a new one will be created.
