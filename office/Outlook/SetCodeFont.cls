Option Explicit

' Change font for selected text to Consolas
' https://superuser.com/a/757514
Sub SetCodeFont()
    On Error Resume Next

    Dim oItem As Object
    Dim olInspector As Outlook.Inspector
    Dim wdDocument As Word.Document
    Dim wdApplication As Word.Application
    Dim wdSelection As Word.Selection

    Set oItem = Application.ActiveInspector.CurrentItem
    If oItem Is Nothing Or oItem.Class <> olMail Then
        ' No object or it's not a mail item
        Exit Sub
    End If

    Set olInspector = oItem.GetInspector
    If olInspector.EditorType <> olEditorWord Then
        ' Mail item editor is not Micosoft Word
        Exit Sub
    End If

    Set wdDocument = olInspector.WordEditor
    Set wdApplication = wdDocument.Application
    Set wdSelection = wdApplication.Selection
    wdSelection.Font.Name = "Consolas"
End Sub
