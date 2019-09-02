# PowerShell-Git-Credential-Helper
A 100% PowerShell-based Credential Helper for Git.

## Usage

1. Download the `git-credential-pwsh.ps1` script from this repo and unblock it if on Windows.
   * **Always inspect scripts before downloading/using**
2. Move the script to a location in your PATH.
3. Add the credential helper to your Git config: `git config --global credential.helper 'pwsh.ps1'`
   * Optional: The script defaults to using CliXml as the storage mechanism. If you use PSProfile and would rather use your PSProfile configuration, run the following instead: `git config --global credential.helper 'pwsh.ps1 -Provider PSProfile'`. Both methods use the Data Protection API to encrypt the password stored.
4. Start interacting with Git repos with HTTPS remotes normally. You should see a prompt starting with `[pwsh]` requesting username and password for the first time, similar to the following:

```powershell
PS ~> git push
[pwsh] Enter username for host https://github.com: ******
[pwsh] Enter password for user 'scrthq' on host https://github.com: ****************************************
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 1.83 KiB | 624.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To https://github.com/scrthq/PowerShell-Git-Credential-Helper.git
   f906b3b..08ec17d  master -> master
```

## Important Notes / Caveats

* Since this uses the Data Protection API to encrypt credentials, usage outside of Windows is not recommended due to lack of the underlying API (although this method should technically work overall).
* This only supports username and password. If you are using 2FA for your source control provider, you will need to generate a Personal Access Token and use that in place of your password.
* This only supports HTTP(S) connections. SSH authentication is shelled out from Git to `ssh`, which has its own mechanism for requesting key passphrases when needed.
* PowerShell 6.1 will fall flat on any OS due to lack of silent error handling when any call to the Data Protection API is made. Silent error handling was added back in with PowerShell 6.2+ though, so if you are on PowerShell Core, use 6.2 or greater or, if on Windows, you can use Windows PowerShell (preferred on Windows tbh).
