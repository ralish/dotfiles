Option Explicit

' Multi-selection drop-down with item removal
' https://www.ablebits.com/office-addins-blog/create-multi-select-dropdown-excel/#multi-selection-dropdown-item-removal-code
'
' Code slightly cleaned-up from the original. To use, add the code to each
' sheet containing a drop-down list requiring multi-selection functionality.
Private Sub Worksheet_Change(ByVal Destination As Range)
    On Error GoTo exitError

    If Destination.Count > 1 Then Exit Sub

    Dim rngDropdown As Range
    Dim strOldVal As String
    Dim strNewVal As String
    Dim strDelimVal As String
    Dim iDelimCount As Integer
    Dim idx As Integer
    Dim strArray() As String

    Set rngDropdown = Cells.SpecialCells(xlCellTypeAllValidation)
    If rngDropdown Is Nothing Then GoTo exitError

    strDelimVal = vbCrLf

    ' xlValidateList
    If Destination.Validation.Type = 3 Then
        Application.EnableEvents = False
        Application.ScreenUpdating = False

        strNewVal = Destination.Value
        Application.Undo
        strOldVal = Destination.Value
        Destination.Value = strNewVal

        If strOldVal = "" And strNewVal = "" Then GoTo exitClean

        ' Leave the value if there is only one in the list
        If strOldVal = strNewVal Or strOldVal = strNewVal & Replace(strDelimVal, " ", "") Or strOldVal = strNewVal & strDelimVal Then
            strOldVal = Replace(strOldVal, strDelimVal, "")
            strOldVal = Replace(strOldVal, Replace(strDelimVal, " ", ""), "")
            Destination.Value = strOldVal
        ElseIf InStr(1, strOldVal, strDelimVal & strNewVal) Or InStr(1, strOldVal, strNewVal & strDelimVal) Or InStr(1, strOldVal, strDelimVal & strNewVal & strDelimVal) Then
            strArray = Split(strOldVal, strDelimVal)
            If IsError(Application.Match(strNewVal, strArray, 0)) = 0 Then
                Destination.Value = ""
                For idx = 0 To UBound(strArray)
                    If strArray(idx) <> strNewVal Then
                        Destination.Value = Destination.Value & strArray(idx) & strDelimVal
                    End If
                Next idx
                Destination.Value = Left(Destination.Value, Len(Destination.Value) - Len(strDelimVal))
            Else
                Destination.Value = strOldVal & strDelimVal & strNewVal
            End If
        ElseIf InStr(1, strOldVal, strNewVal & Replace(strDelimVal, " ", "")) Then
            strOldVal = Replace(strOldVal, strNewVal, "")
            Destination.Value = strOldVal
        Else
            Destination.Value = strOldVal & strDelimVal & strNewVal
        End If

        ' Remove extra commas and spaces
        Destination.Value = Replace(Destination.Value, Replace(strDelimVal, " ", "") & Replace(strDelimVal, " ", ""), Replace(strDelimVal, " ", ""))
        Destination.Value = Replace(Destination.Value, strDelimVal & Replace(strDelimVal, " ", ""), Replace(strDelimVal, " ", ""))

        ' Remove any trailing delimiter
        If Destination.Value <> "" Then
            If Right(Destination.Value, 2) = strDelimVal Then
                Destination.Value = Left(Destination.Value, Len(Destination.Value) - 2)
            End If
        End If

        ' Remove any leading delimiter
        If InStr(1, Destination.Value, strDelimVal) = 1 Then
            Destination.Value = Replace(Destination.Value, strDelimVal, "", 1, 1)
        End If

        If InStr(1, Destination.Value, Replace(strDelimVal, " ", "")) = 1 Then
            Destination.Value = Replace(Destination.Value, Replace(strDelimVal, " ", ""), "", 1, 1)
        End If

        iDelimCount = 0
        For idx = 1 To Len(Destination.Value)
            If InStr(idx, Destination.Value, Replace(strDelimVal, " ", "")) Then
                iDelimCount = iDelimCount + 1
            End If
        Next idx

        ' Remove delimiter if last character
        If iDelimCount = 1 Then
            Destination.Value = Replace(Destination.Value, strDelimVal, "")
            Destination.Value = Replace(Destination.Value, Replace(strDelimVal, " ", ""), "")
        End If
    End If

    exitClean:
    Application.EnableEvents = True
    Application.ScreenUpdating = True

    exitError:
End Sub

Private Sub Worksheet_SelectionChange(ByVal Target As Range)
End Sub
