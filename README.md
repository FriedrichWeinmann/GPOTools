# Description

The GPOTools module is designed to handle all things GPO.

As a special focus, it tries to manage migrations, backup & restore.

Compared to the built-in tools, its backup&restore capability also includes:

- WMI Filter
- GP Links & Link Order
- Localized / Renamed builtin accounts & groups mapping
- Customizable identity mapping
- Permissions

# Examples
## Installing the module

```powershell
Install-Module GPOTools
```

## Backup

```powershell
# Backup ALL GPOs
Backup-GptPolicy -Path .

# Backup just the ones you want
Get-GPO -All | Where-Object $condition | Backup-GptPolicy -Path .

# Backup all policies that fit your desired name pattern
Backup-GptPolicy -Path . -Name 'SEC-*'
```

## Restore

```powershell
# Restore everything
Restore-GptPolicy -Path .

# Restore just those policies you care about
Restore-GptPolicy -Path . -Name 'SEC-*', 'Client-*'

# Restore while mapping groups from the source domain to different groups in the destination domain
Restore-GptPolicy -Path . -IdentityMapping @{
	'S-D-FileServerAdmins' = 'SD1-FSAdmins'
}
```
