try {
    Test-ModuleAvailable -Name AWSPowerShell.NetCore, AWSPowerShell -Require Any
} catch {
    Write-Verbose -Message '[dotfiles] Skipping import of AWS functions.'
    return
}

Write-Verbose -Message '[dotfiles] Importing AWS functions ...'

#region IAM

# Set AWS credential environment variables from an AWSCredentials object
Function Set-AWSCredentialEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUsePSCredentialType', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Amazon.SecurityToken.Model.Credentials]$Credential
    )

    Set-Item -Path Env:\AWS_ACCESS_KEY_ID -Value $Credential.AccessKeyId
    Set-Item -Path Env:\AWS_SECRET_ACCESS_KEY -Value $Credential.SecretAccessKey
    Set-Item -Path Env:\AWS_SESSION_TOKEN -Value $Credential.SessionToken
}

#endregion
