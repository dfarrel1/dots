#
# Sets chmod permissions for the PEM file to be used with Windows' OpenSSH
# without annoying "WARNING: UNPROTECTED PRIVATE KEY FILE!" message.
#

function Set-SSHPermissions {
  param(
    [string]
    $FilePath
  )

  # Set Key File Variable:
  New-Variable -Name Key -Value $FilePath

  # Remove Inheritance:
  Icacls $Key /c /t /Inheritance:d

  #
  # Set Ownership to Owner:
  #
  # Key's within $env:UserProfile:
  Icacls $Key /c /t /Grant ${env:UserName}:F

  # Key's outside of $env:UserProfile:
  TakeOwn /F $Key
  Icacls $Key /c /t /Grant:r ${env:UserName}:F

  # Remove All Users, except for Owner:
  Icacls $Key /c /t /Remove:g *S-1-1-0 *S-1-5-11 *S-1-5-32-545 *S-1-5-32-544 *S-1-5-18

  # Verify:
  Icacls $Key

  # Remove Variable:
  Remove-Variable -Name Key
}