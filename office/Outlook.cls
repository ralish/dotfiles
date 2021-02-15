' Shortcut or macro for changing font type in Microsoft Outlook
' https://superuser.com/a/757514
Sub SetCodeFont()
    On Error Resume Next

    Dim oItem As Object
    Dim olInspector As Outlook.Inspector
    Dim wdDocument As Word.Document
    Dim wdApplication As Word.Application
    Dim wdSelection As Word.Selection

    Set oItem = Application.ActiveInspector.CurrentItem
    If Not oItem Is Nothing Then
        If oItem.Class = olMail Then
            Set olInspector = oItem.GetInspector
            If olInspector.EditorType = olEditorWord Then
                Set wdDocument = olInspector.WordEditor
                Set wdApplication = wdDocument.Application
                Set wdSelection = wdApplication.Selection
                wdSelection.Font.Name = "Consolas"
            End If
        End If
    End If

    Set wdSelection = Nothing
    Set wdApplication = Nothing
    Set wdDocument = Nothing
    Set olInspector = Nothing
    Set oItem = Nothing
End Sub
