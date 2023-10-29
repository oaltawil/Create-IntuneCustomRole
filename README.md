# Create-CustomIntuneRole.ps1

PowerShell script that creates a custom role - role definition - in Microsoft Intune.

1. Requires a Csv file that contains the allowed resource actions for the new role definition. The Csv file should have two columns named "ResourceAction" and "Allowed". For example: "AndroidFota_Assign, Yes".

2. Creates a "Microsoft.Graph.RoleDefinition" object and uses the allowed resource actions from the Csv file for the corresponding property of the object.

3. Creates a custom role using the MS Graph cmdlet New-MgDeviceManagementRoleDefinition. The cmdlet returns an Http response with an Http status code, e.g. 200: OK, and the role definition object in the body of the response.

- If a role with the same display name already exists, the script returns an error and exits. Use the -Force parameter to delete the conflicting role and create a new one.

- Usage: .\Create-CustomIntuneRole.ps1 -RoleDefinitionCsvFilePath "$ENV:USERPROFILE\Documents\CustomIntuneRole.csv" -RoleDisplayName "Help Desk L2 Administrator" -RoleDescription "Can view and manage various aspects of Microsoft Intune"

- The included Csv file "CustomIntuneRole.csv" defines the allowed resource actions for the built-in "Help Desk Operator" role.
