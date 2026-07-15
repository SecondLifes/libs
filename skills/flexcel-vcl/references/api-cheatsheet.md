# TXlsFile API cheatsheet

Deeper reference for the `TXlsFile` class (unit `FlexCel.XlsAdapter`). For the high-level workflow see `../SKILL.md`. For anything not covered here, use **APIMate** (ships with FlexCel) — build the file in Excel, open in APIMate, and copy the generated Delphi code. It is the authoritative source for Excel-feature-to-FlexCel-code mapping.

## Constructors

```pascal
TXlsFile.Create;                                                    // empty, no sheets
TXlsFile.Create(sheetCount: integer; format: TExcelFileFormat; defaultFormats: boolean);
TXlsFile.Create(const filename: string);                            // opens file
TXlsFile.Create(const filename: string; virtualMode: boolean);      // streaming read
TXlsFile.Create(stream: TStream; format: TExcelFileFormat);
```

`TExcelFileFormat` values include `v2019`, `v2016`, `v2013`, `v2010`, `v2007`, `v2003`, etc. For most new files use `v2019`.

## Save

```pascal
xls.Save(filename);                                    // format inferred from extension
xls.Save(filename, TFileFormats.Xlsx);                 // explicit
xls.Save(stream, TFileFormats.Xlsx);
```

## Sheets

```pascal
xls.SheetCount                        // integer, 1-based range
xls.ActiveSheet                       // 1..SheetCount
xls.ActiveSheetByName := 'Sheet1';    // setter only; to read name use xls.SheetName
xls.SheetName                         // name of the active sheet (read/write)
xls.InsertAndCopySheets(CopyFrom, InsertBefore, SheetCount);
xls.DeleteSheet(index, count);
xls.AddSheet('NewName');              // appends
```

When working sheet-by-sheet, set `xls.ActiveSheet` first, then all the cell / format / column / row methods below act on that sheet.

## Reading cells

Two APIs — use the indexed one for performance when scanning:

```pascal
// Dense: accepts any row/col, slow in sparse sheets.
cell := xls.GetCellValue(row, col);                  // TCellValue
cell := xls.GetCellValue(row, col, XF);              // also returns the XF index

// Sparse-aware: only visits cells that exist. Much faster for reading.
for row := 1 to xls.RowCount do
  for colIdx := 1 to xls.ColCountInRow(row) do
  begin
    XF := -1;
    cell := xls.GetCellValueIndexed(row, colIdx, XF);
    realCol := xls.ColFromIndex(row, colIdx);
    ...
  end;
```

`TCellValue` is a record with these tests and accessors:

| Test | Accessor |
|------|----------|
| `cell.IsEmpty` | — |
| `cell.IsString` | `cell.ToString` |
| `cell.IsNumber` | `cell.AsNumber` (Double) |
| `cell.IsBoolean` | `cell.AsBoolean` |
| `cell.IsError` | `cell.ToString` gives the error text |
| `cell.IsFormula` | `cell.AsFormula` → `TFormula` with `.Text`, `.Result` |

Excel stores **dates as numbers**. To detect a date, look at the XF's number-format string (see "Formatting" below) or call helper `TFlxNumberFormat.HasDate(format.Format)`.

## Writing cells

```pascal
xls.SetCellValue(row, col, 'string');              // text
xls.SetCellValue(row, col, 42);                    // integer (stored as double)
xls.SetCellValue(row, col, 3.14);                  // double
xls.SetCellValue(row, col, true);                  // boolean
xls.SetCellValue(row, col, TFormula.Create('=Sum(A1:A3)'));      // formula
xls.SetCellValue(row, col, TFormula.Create('=A1*2', 42));        // formula + cached result
xls.SetCellValue(row, col, TCellValue.Empty);                    // clear
xls.SetCellValue(row, col, value, XF);                           // value + format
```

Dates: write a `TDateTime` by converting with the workbook's base date — e.g., `xls.SetCellValue(r, c, dt - xls.OptionsDates1904 ? TFlxDateTime.DateTimeToSerial(dt, true) : TFlxDateTime.DateTimeToSerial(dt, false))`. Simpler: use `TFlxNumberFormat` to build the format and write the `TDateTime` directly via the number APIs in newer versions — in practice APIMate will generate the correct call for you.

## Formatting

Formats live in the workbook's format table and are referenced by an **XF index (0-based)**.

```pascal
var fmt: TFlxFormat;
var xf: integer;
begin
  fmt := xls.GetDefaultFormat;           // a fresh default format record
  fmt.Font.Name := 'Calibri';
  fmt.Font.Size20 := 11 * 20;            // size is in 1/20 of a point
  fmt.Font.Style := [TFlxFontStyles.Bold];
  fmt.Font.Color := TExcelColor.FromColor(TColors.Red);
  fmt.FillPattern.Pattern := TFlxPatternStyle.Solid;
  fmt.FillPattern.FgColor := TExcelColor.FromTheme(TThemeColor.Accent1);
  fmt.Format := '#,##0.00';              // number-format string
  fmt.HAlignment := THFlxAlignment.Center;
  fmt.VAlignment := TVFlxAlignment.Center;
  fmt.WrapText := true;

  xf := xls.AddFormat(fmt);              // dedupes automatically
  xls.SetCellFormat(row, col, xf);
end;
```

To read a cell's format:

```pascal
xf := xls.GetCellFormat(row, col);
fmt := xls.GetFormat(xf);
```

To apply a format to an entire row/column without touching existing cells:

```pascal
xls.SetRowFormat(row, xf);
xls.SetColFormat(col, xf);
```

## Row / column sizing

```pascal
// Widths are in 1/256 of the width of the '0' character in the default font.
xls.SetColWidth(col, 20 * 256);          // ~20 chars wide

// Heights are in 1/20 of a point.
xls.SetRowHeight(row, 30 * 20);          // 30 pt tall

// Autofit (requires FlexCel.Render in uses, plus the platform support unit).
xls.AutofitCol(colStart, colEnd, keepIfLarger, adjustmentFactor);
xls.AutofitRow(rowStart, rowEnd, keepIfLarger, adjustmentFactor);
```

## Merging, comments, hyperlinks

```pascal
xls.MergeCells(r1, c1, r2, c2);
xls.SetComment(row, col, TRichString.Create('Note text'));
xls.SetHyperlink(row, col, THyperLink.Create('https://...', 'Display text'));
```

## Images & charts

Images and charts are many-parametered — use **APIMate** to generate the code. Typical entry points:

```pascal
xls.AddImage(anchor, properties, imageBytes);
xls.AddChart(anchor, chartDefinition);
```

## Named ranges

```pascal
xls.SetNamedRange(TXlsNamedRange.Create('MyName', sheetIndex, rangeRef));
range := xls.GetNamedRange(byName, -1);    // -1 = workbook-scoped
```

Named ranges are also how report bands are declared — see `reports-cheatsheet.md`.

## Protection

```pascal
xls.Protection.SetWorkbookPassword('pwd');
xls.Protection.SetSheetProtection('pwd', [TSheetProtection.AutoFilter, ...]);
xls.SetEncryption(...)   // see TEncryptionType — encrypts the whole file
```

## Recalculation

```pascal
xls.RecalcMode := TRecalcMode.Forced;       // recompute on open
xls.Recalc;                                  // compute formula results now
```

Recalc is needed when you write many formulas and want cached values saved — otherwise consumers that don't recalculate (some viewers, or your own PDF export) will see blank cells until values are cached.

## Virtual / streaming mode

For multi-gigabyte files, create the workbook with `VirtualMode := true` and stream rows in/out via events. See the performance guide in the doc source.

## Common patterns

**Dump a TDataSet into a sheet without using reports:**

```pascal
row := 1;
for i := 0 to ds.FieldCount - 1 do
  xls.SetCellValue(row, i + 1, ds.Fields[i].DisplayLabel);
Inc(row);
ds.First;
while not ds.Eof do
begin
  for i := 0 to ds.FieldCount - 1 do
    xls.SetCellValue(row, i + 1, ds.Fields[i].AsVariant);  // simplified
  Inc(row);
  ds.Next;
end;
```

For field-type-correct conversions (dates, booleans, nulls) see the "Dumping a dataset" tip at
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.VCL-doc-src/main/tips/dumping-a-dataset.md`.

**Copy a range between files:**

```pascal
xls.InsertAndCopyRange(sourceRange, destRow, destCol, 1,
  TFlxInsertMode.NoneDown, sourceXlsFile);
```
