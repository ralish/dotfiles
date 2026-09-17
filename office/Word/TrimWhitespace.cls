Option Explicit

' Trims leading and trailing whitespace from all paragraphs and table cells
Public Sub TrimWhitespace()
    Dim doc As Document, pg As Paragraph
    Dim prevScreen As Boolean, prevTrack As Boolean
    Dim undoRecord As UndoRecord

    Set doc = ActiveDocument
    prevScreen = Application.ScreenUpdating
    prevTrack = doc.TrackRevisions

    Set undoRecord = Application.UndoRecord
    undoRecord.StartCustomRecord "Trim whitespace"

    On Error GoTo Cleanup
    Application.ScreenUpdating = False
    doc.TrackRevisions = False

    For Each pg In doc.Paragraphs
        TrimParagraph pg
    Next

    TrimTables doc.Tables

Cleanup:
    doc.TrackRevisions = prevTrack
    Application.ScreenUpdating = prevScreen
    undoRecord.EndCustomRecord
    If Err.Number <> 0 Then Err.Raise Err.Number, Err.Source, Err.Description
End Sub

' Trims leading and trailing whitespace from a paragraph
Private Sub TrimParagraph(ByVal pg As Paragraph)
    Dim doc As Document, startPos As Long, markPos As Long, pos As Long

    Set doc = pg.Range.Document
    startPos = pg.Range.Start
    markPos = pg.Range.End - 1

    ' Trim leading whitespace
    pos = startPos
    Do While pos < markPos
        If Not IsTrimChar(doc.Range(pos, pos + 1).Text) Then Exit Do
        pos = pos + 1
    Loop

    If pos > startPos Then
        doc.Range(startPos, pos).Delete
        markPos = pg.Range.End - 1
    End If

    ' Trim trailing whitespace
    Do While pos > startPos
        If Not IsTrimChar(doc.Range(pos - 1, pos).Text) Then Exit Do
        pos = pos - 1
    Loop

    If pos < markPos Then doc.Range(pos, markPos).Delete
End Sub

' Trims each cell in a table and recursively processes nested tables
Private Sub TrimTables(ByVal tables As Tables)
    Dim table As Table, cell As Cell

    For Each table In tables
        For Each cell In table.Range.Cells
            TrimCell cell
        Next

        ' Handles nested tables
        TrimTables table.Tables
    Next
End Sub

' Trims leading and trailing whitespace and empty paragraphs from a cell
Private Sub TrimCell(ByVal cell As Cell)
    Dim doc As Document, cellStart As Long, cellMark As Long, pos As Long

    Set doc = cell.Range.Document
    cellStart = cell.Range.Start
    ' Never delete the end-of-cell mark
    cellMark = cell.Range.End - 1

    ' Trim leading whitespace and empty paragraphs
    pos = cellStart
    Do While pos < cellMark
        If Not IsCellTrimChar(doc.Range(pos, pos + 1).Text) Then Exit Do
        pos = pos + 1
    Loop

    If pos > cellStart Then
        doc.Range(cellStart, pos).Delete
        cellMark = cell.Range.End - 1
    End If

    ' Trim trailing whitespace and empty paragraphs
    pos = cellMark
    Do While pos > cellStart
        If Not IsCellTrimChar(doc.Range(pos - 1, pos).Text) Then Exit Do
        pos = pos - 1
    Loop

    If pos < cellMark Then doc.Range(pos, cellMark).Delete
End Sub

' Checks if a character should be trimmed
'
' Matches against:
' - Space
' - Tab
' - Non-breaking space (NBSP)
' - Vertical tabulation (VT)
Private Function IsTrimChar(ByVal ch As String) As Boolean
    Select Case ch
        Case " ", vbTab, Chr$(160), Chr$(11)
            IsTrimChar = True
        Case Else
            IsTrimChar = False
    End Select
End Function

' Checks if a character in a cell should be trimmed
'
' Tests using `IsTrimChar()` and additionally matches carriage return (CR).
Private Function IsCellTrimChar(ByVal ch As String) As Boolean
    IsCellTrimChar = IsTrimChar(ch) Or (ch = vbCr)
End Function
