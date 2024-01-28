Option Explicit

' Set reply address to the primary account
Sub SetReplyAddress()
    On Error Resume Next

    Dim oItem As Object
    Dim olMailItem As Outlook.MailItem
    Dim olCurrentUser As Outlook.Recipient
    Dim olExchangeUser As Outlook.ExchangeUser

    Set oItem = Application.ActiveInspector.CurrentItem
    If oItem Is Nothing Or oItem.Class <> olMail Then
        ' No object or it's not a mail item
        Exit Sub
    End If

    Set olMailItem = oItem
    If olMailItem.Sent Then
        ' Can't operate on a sent mail item
        Exit Sub
    End If

    ' Retrieve the primary SMTP address of the primary account
    Set olCurrentUser = Application.Session.CurrentUser
    Set olExchangeUser = olCurrentUser.AddressEntry.GetExchangeUser()

    With olMailItem
        ' Remove existing reply recipients
        Do While .ReplyRecipients.Count > 0
            .ReplyRecipients.Remove 1
        Loop

        ' Set the reply recipient to our address
        .ReplyRecipients.Add olExchangeUser.PrimarySmtpAddress
    End With
End Sub
