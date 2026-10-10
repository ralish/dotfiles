Option Explicit

' Trims leading and trailing whitespace and newlines from all cells in the
' active worksheet.
Public Sub TrimCells()
    Dim cell As Range, cellValOrig As String, cellValTrim As String
    Dim prevEvents As Boolean, prevScreen As Boolean, prevCalc As XlCalculation

    prevEvents = Application.EnableEvents
    prevScreen = Application.ScreenUpdating
    prevCalc = Application.Calculation

    On Error GoTo Cleanup
    Application.EnableEvents = False
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual

    For Each cell In ActiveSheet.UsedRange
        If VarType(cell.Value) = vbString And Not cell.HasFormula Then
            cellValOrig = cell.Value
            cellValTrim = TrimAll(cellValOrig)

            If cellValTrim <> cellValOrig Then
                If cellValTrim = vbNullString Then
                    cell.ClearContents
                Else
                    cell.Value = cellValTrim
                End If
            End If
        End If
    Next

Cleanup:
    Application.Calculation = prevCalc
    Application.ScreenUpdating = prevScreen
    Application.EnableEvents = prevEvents
    If Err.Number <> 0 Then Err.Raise Err.Number, Err.Source, Err.Description
End Sub

' Trims leading and trailing whitespace and newlines from a string
Private Function TrimAll(ByVal str As String) As String
    Dim strLeadIdx As Long, strTrailIdx As Long

    strLeadIdx = 1
    strTrailIdx = Len(str)

    ' Trim leading whitespace and newlines
    Do While strLeadIdx <= strTrailIdx
        If Not IsTrimChar(Mid$(str, strLeadIdx, 1)) Then Exit Do
        strLeadIdx = strLeadIdx + 1
    Loop

    ' Trim trailing whitespace and newlines
    Do While strTrailIdx >= strLeadIdx
        If Not IsTrimChar(Mid$(str, strTrailIdx, 1)) Then Exit Do
        strTrailIdx = strTrailIdx - 1
    Loop

    ' Return the trimmed string or the empty string if no characters remain
    If strTrailIdx < strLeadIdx Then
        TrimAll = vbNullString
    Else
        TrimAll = Mid$(str, strLeadIdx, strTrailIdx - strLeadIdx + 1)
    End If
End Function

' Checks if a character should be trimmed
'
' Matches against:
' - Space
' - Tab
' - Carriage return (`CR`)
' - Line feed (`LF`)
' - Non-breaking space (`NBSP`)
Private Function IsTrimChar(ByVal ch As String) As Boolean
    Select Case ch
        Case " ", vbTab, vbCr, vbLf, Chr$(160)
            IsTrimChar = True
        Case Else
            IsTrimChar = False
    End Select
End Function
