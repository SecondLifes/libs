# XlsFile / ExcelFile API cheatsheet (.NET)

Deeper reference for the `XlsFile` class (namespace `FlexCel.XlsAdapter`). Most methods are actually declared on its abstract base `ExcelFile` (namespace `FlexCel.Core`) — `XlsFile` is the only public concrete descendant, so in practice you always instantiate `XlsFile` and call `ExcelFile`'s methods on it.

For anything not covered here, use **APIMate** (ships with FlexCel — available for Windows, macOS, and Linux). Build the file in Excel, open in APIMate, and copy the generated C# code. It is the authoritative source for Excel-feature-to-FlexCel-code mapping.

## Constructors

```csharp
new XlsFile();                                                // empty, no sheets
new XlsFile(int sheetCount);                                  // N blank sheets
new XlsFile(int sheetCount, TExcelFileFormat fmt, bool allowOverwrite);
new XlsFile(string filename);                                 // open
new XlsFile(string filename, bool virtualMode);               // streaming read
new XlsFile(Stream stream, TExcelFileFormat format);
```

`TExcelFileFormat` has values `v2019`, `v2016`, `v2013`, `v2010`, `v2007`, `v2003`, etc. For most new files use `v2019`.

`XlsFile` does **not** implement `IDisposable`. Don't wrap in `using`.

## Save

```csharp
xls.Save(filename);                               // format inferred from extension
xls.Save(filename, TFileFormats.Xlsx);            // explicit
xls.Save(stream, TFileFormats.Xlsx);
```

## Sheets

```csharp
xls.SheetCount                         // int, 1-based range
xls.ActiveSheet                        // 1..SheetCount (read/write int)
xls.ActiveSheetByName = "Sheet1";      // setter only
xls.SheetName                          // name of the active sheet (read/write string)
xls.InsertAndCopySheets(copyFrom, insertBefore, sheetCount);
xls.DeleteSheet(index, count);
xls.AddSheet("NewName");               // appends
```

Set `xls.ActiveSheet` first, then all cell / format / column / row methods below act on that sheet.

## Reading cells

Two APIs — use the indexed one for performance when scanning:

```csharp
// Dense: accepts any row/col; slow on sparse sheets.
object cell = xls.GetCellValue(row, col);                 // value only
object cell = xls.GetCellValue(row, col, out int XF);     // plus XF index

// Sparse-aware: only visits cells that exist. Much faster for reading.
for (int row = 1; row <= xls.RowCount; row++)
{
    for (int idx = 1; idx <= xls.ColCountInRow(row); idx++)
    {
        int XF = -1;
        object value = xls.GetCellValueIndexed(row, idx, ref XF);
        int realCol = xls.ColFromIndex(row, idx);
        // ...
    }
}
```

Type dispatch on the returned `object`:

| Runtime type | Meaning |
|--------------|---------|
| `null` | cell is empty (never allocated) |
| `string` | plain text |
| `TRichString` | rich-formatted text (mixed fonts/colors within a cell) |
| `double` | number — **includes dates**, check the format |
| `bool` | boolean |
| `TFlxFormulaErrorValue` | Excel error (`#DIV/0!`, `#N/A`, …) |
| `TFormula` | formula — has `.Text`, `.Result` |

## Writing cells

```csharp
xls.SetCellValue(row, col, "string");                    // text
xls.SetCellValue(row, col, 42);                          // int → stored as double
xls.SetCellValue(row, col, 3.14);                        // double
xls.SetCellValue(row, col, true);                        // bool
xls.SetCellValue(row, col, new TFormula("=Sum(A1:A3)")); // formula
xls.SetCellValue(row, col, new TFormula("=A1*2", 42));   // formula with cached result
xls.SetCellValue(row, col, null);                        // clear
xls.SetCellValue(row, col, value, XF);                   // value + format
```

**Writing dates.** Use the workbook's helper to convert `DateTime` to Excel's serial number and apply a date format:

```csharp
double serial = FlxDateTime.ToOADate(DateTime.Now, xls.OptionsDates1904);
int dateXF = xls.AddFormat(new TFlxFormat { Format = "yyyy-mm-dd" });
xls.SetCellValue(r, c, serial, dateXF);
```

## Formatting

Formats live in the workbook's format table and are referenced by an **XF index (0-based — exception to the 1-based rule)**.

```csharp
TFlxFormat fmt = xls.GetDefaultFormat;               // fresh default
fmt.Font.Name = "Calibri";
fmt.Font.Size20 = 11 * 20;                           // size is in 1/20 of a point
fmt.Font.Style = TFlxFontStyles.Bold;
fmt.Font.Color = TExcelColor.FromArgb(0xFF, 0xFF, 0, 0);  // red
fmt.FillPattern.Pattern = TFlxPatternStyle.Solid;
fmt.FillPattern.FgColor = TExcelColor.FromTheme(TThemeColor.Accent1);
fmt.Format = "#,##0.00";
fmt.HAlignment = THFlxAlignment.Center;
fmt.VAlignment = TVFlxAlignment.Center;
fmt.WrapText = true;

int xf = xls.AddFormat(fmt);                          // de-dupes automatically
xls.SetCellFormat(row, col, xf);
```

Read a cell's format:

```csharp
int xf = xls.GetCellFormat(row, col);
TFlxFormat fmt = xls.GetFormat(xf);
```

Apply to an entire row/column:

```csharp
xls.SetRowFormat(row, xf);
xls.SetColFormat(col, xf);
```

## Row / column sizing

```csharp
// Widths are in 1/256 of the width of the '0' character in the default font.
xls.SetColWidth(col, 20 * 256);      // ~20 chars wide

// Heights are in 1/20 of a point.
xls.SetRowHeight(row, 30 * 20);      // 30 pt tall

// Autofit (requires FlexCel.Render in using — the autofit path renders text internally).
xls.AutofitCol(colStart, colEnd, keepIfLarger, adjustmentFactor);
xls.AutofitRow(rowStart, rowEnd, keepIfLarger, adjustmentFactor);
```

## Merging, comments, hyperlinks

```csharp
xls.MergeCells(r1, c1, r2, c2);
xls.SetComment(row, col, new TRichString("Note text"));
xls.SetHyperlink(row, col, new THyperLink("https://...", "Display text"));
```

## Images and charts

Many-parametered — use **APIMate** to generate the call. Typical entry points:

```csharp
xls.AddImage(anchor, properties, imageBytes);
xls.AddChart(anchor, chartDefinition);
```

## Named ranges

```csharp
xls.SetNamedRange(new TXlsNamedRange("MyName", sheetIndex, rangeRef));
var range = xls.GetNamedRange(byName, -1);    // -1 = workbook-scoped
```

Named ranges also declare report bands — see `reports-cheatsheet.md`.

## InsertAndCopyRange / DeleteRange / MoveRange

The *manipulation* methods — APIMate can't generate these because they're not captured by a static file state. Use them for inserting rows/columns, copying templates around, or moving data between sheets.

```csharp
// Insert copy of source range at (destRow, destCol), pushing cells down.
xls.InsertAndCopyRange(
    sourceRange: TXlsCellRange.FromAddresses("A1", "D10"),
    destRow: 20, destCol: 1,
    copyCount: 1,
    insertMode: TFlxInsertMode.ShiftRangeDown,
    copyMode: TRangeCopyMode.All,
    sourceWorkbook: xls);               // may be a different XlsFile

// Delete cells — shifts things up/left.
xls.DeleteRange(rangeToDelete, TFlxInsertMode.ShiftRangeUp);

// Move cells in place.
xls.MoveRange(sourceRange, destRow, destCol, TFlxInsertMode.NoneUp);
```

All support cross-workbook copying via the `sourceWorkbook` parameter — pass a different `XlsFile` to copy from it.

## Protection

```csharp
xls.Protection.SetWorkbookPassword("pwd");
xls.Protection.SetSheetProtection("pwd",
    TSheetProtection.AutoFilter | TSheetProtection.Sort);
xls.SetEncryption(...);     // see TEncryptionType — encrypts the whole file
```

## Recalculation

```csharp
xls.RecalcMode = TRecalcMode.Forced;   // recompute on open
xls.Recalc();                           // compute formula results now
```

Call `Recalc()` before export if you wrote many formulas — otherwise consumers that don't themselves recalculate (some viewers, or your PDF export) see blank cells until values are cached.

## Virtual / streaming mode

For multi-gigabyte files, create the workbook with `virtualMode: true` and stream rows via events. See `guides/performance-guide.md` in the doc source.

## Common patterns

**Dump a `DataTable` into a sheet without using reports:**

```csharp
int row = 1;
for (int i = 0; i < dt.Columns.Count; i++)
    xls.SetCellValue(row, i + 1, dt.Columns[i].ColumnName);
row++;

foreach (DataRow r in dt.Rows)
{
    for (int i = 0; i < dt.Columns.Count; i++)
    {
        object v = r[i];
        if (v == DBNull.Value) continue;
        xls.SetCellValue(row, i + 1, v);   // overloads handle string/number/bool/DateTime
    }
    row++;
}
```

For field-type-correct conversions (dates, booleans, null formatting) see the "Dumping a dataset" tip:
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.NET-doc-src/main/tips/dumping-a-dataset.md`

**Load from / save to a `MemoryStream`** (common in ASP.NET):

```csharp
byte[] Render()
{
    var xls = new XlsFile(1, TExcelFileFormat.v2019, true);
    xls.SetCellValue(1, 1, "hello");
    using var ms = new MemoryStream();
    xls.Save(ms, TFileFormats.Xlsx);
    return ms.ToArray();
}
```

In ASP.NET Core return `File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "report.xlsx")`.
