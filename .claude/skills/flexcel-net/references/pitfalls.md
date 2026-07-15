# Common pitfalls and tips (.NET)

A curated list drawn from the official FlexCel Tips section plus .NET-specific concerns. Each entry is short; fetch the full tip from the doc-source repo when you need detail:
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.NET-doc-src/main/tips/<filename>.md`

## Indexing and measurement

- **1-based everywhere** except XF format indices (0-based). `SetCellValue(1, 1, ...)` is `A1`.
- **Column width**: 1/256 of the width of the `'0'` character in the default font. (Not pixels, not points.)
- **Row height**: 1/20 of a point. `20 pt` = `400`.
- **Font size**: `Font.Size20` is in 1/20 of a point. `11 pt` = `220`.
- **Colors**: xlsx uses true RGB — `TExcelColor.FromArgb(...)` or `FromTheme(...)`. Legacy `.xls` palettes are auto-mapped.
- Tip: `understanding-excel-measurement-units.md`

## Performance

- **Never use `ColCount` inside a read loop.** It scans the entire sheet. Use `ColCountInRow(row)` + `GetCellValueIndexed(row, idx, ref XF)` + `ColFromIndex(row, idx)`.
- Reading just the header row? Use `ColCountInRow(1)`, not `ColCount`. Tip: `reading-first-row.md`.
- For giant files consider **virtual mode** on the `XlsFile` constructor. See `guides/performance-guide.md`.
- **Avoid too many rows.** Excel's hard limit is ~1.05 M rows, but files slow to a crawl well before that. Split across sheets. Tip: `avoiding-too-many-rows.md`.

## Native AOT (.NET 9+)

- `XlsFile`, `FlexCelPdfExport`, `FlexCelHtmlExport`, `FlexCelImgExport` — **fully supported.**
- `FlexCelReport` — **partial.** Reflection-based property access means:
  - Annotate every POCO passed to `AddTable`:
    ```csharp
    [DynamicallyAccessedMembers(
        DynamicallyAccessedMemberTypes.PublicProperties |
        DynamicallyAccessedMemberTypes.PublicMethods)]
    public class Customer { ... }
    ```
  - `DataSet` filtering inside templates may fail (changing across .NET releases).
  - Complex LINQ / sort / filter expressions in templates may fail.
  - If reports are central to the app, consider **running the report in a non-AOT worker process** and producing the PDF/HTML there. The main app can stay AOT.
- Full tip: `tips/native-aot.md`.

## Dates, numbers, text

- Excel stores dates as numbers. `GetCellValue` returns `double` for a date cell. Detect "this is a date" by inspecting the cell's format string, not the value type.
- **Multi-line cells:** use `"\n"` in the string and set `WrapText = true` in the format. Tip: `multi-line-cells.md`.
- **Text rotation** differs between `.xls` and `.xlsx`. Tip: `text-rotation-in-xls-and-xlsx.md`.
- Excel's built-in number formats are identified by numeric IDs internally. Tip: `internal-numeric-formats.md`.

## Fonts and locale

- **Font on Linux / macOS / Docker:** ship fonts with the app or register a font folder via `FlexCelPdfExport.GetFontFolder` event. Without the font files, PDF rendering falls back and layout drifts.
- **Font licensing:** embedding commercial fonts into PDF may require a license. Tip: `font-licensing.md`.
- **Cloud fonts / recent Office fonts** (Aptos, Bahnschrift variants) are not on most systems — install or substitute. Tip: `cloud-fonts.md`.
- **Locale:** FlexCel uses the current thread culture by default. Override per call with `IFormatProvider` overloads where provided, or set `CultureInfo.CurrentCulture` on the thread before calling `Run`/`Export`. Tip: `how-to-change-the-flexcel-locale.md`.
- **Localized month names in formats** use `[$-xxx]` format prefixes. Tip: `localized-month-names.md`.

## Formulas

- **Write formulas with cached values** where possible: `new TFormula("=A1+1", 42)`. Otherwise call `xls.Recalc()` before export, or the PDF shows blanks.
- **Expanding formulas** (ranges like `A1:A3`) are relative to context. Tip: `expanding-formulas.md`.
- **Semi-absolute references** (`A$1`, `$A1`) behave as in Excel. Tip: `semi-absolute-references.md`.
- To analyse existing formulas (tokens, precedents): `using-tokens-to-get-information-from-formulas.md`.

## Conditional formatting and data validation

- **Prefer conditional formats over applying direct formats row-by-row** when the rule is expressible — much smaller files, better performance. Tip: `prefer-conditional-formats.md`.
- References inside conditional formats and data validations are stored differently from cell formulas — don't hand-edit. Tip: `references-in-conditional-formats-and-data-validations.md`.

## Reports

- Tag not expanding? Common causes: (1) table not registered with `AddTable`; (2) name mismatch plus `caseInsensitive: false`; (3) the tag is outside any named range; (4) running under Native AOT without `[DynamicallyAccessedMembers]`.
- **`<#include>` recursion** is fine but sub-templates resolve relative to the main template's folder.
- **Master-detail without a declared relationship** sometimes "works" via implicit field-name matching but is fragile — always call `AddRelationship` explicitly for anything non-trivial.
- **IQueryable + EF Core:** supported. The query is enumerated at Run time; side-effects like database access happen inside `Run`.

## PDF export

- Blank pages → check print area and page setup on the source sheet.
- Huge output → `FontSubset = true`.
- `FlexCelPdfExport` is **not thread-safe** — don't share one instance across ASP.NET requests. Create per request, dispose at end.
- Signing PDFs: `tips/sign-your-pdfs.md`.

## Strict XLSX, XLSM, XLSB

- FlexCel reads and writes the default `.xlsx` dialect. **Strict XLSX** (ISO-conformant) is readable; preserve-on-save behavior is covered in `tips/using-strict-xlsx-files.md`.
- Macro-enabled files (`.xlsm`, `.xlsb`) — FlexCel preserves macros but does not execute them.

## ASP.NET / web specifics

- Return `.xlsx` from ASP.NET Core:
  ```csharp
  using var ms = new MemoryStream();
  xls.Save(ms, TFileFormats.Xlsx);
  return File(ms.ToArray(),
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "report.xlsx");
  ```
- Return PDF:
  ```csharp
  using var ms = new MemoryStream();
  using (var pdf = new FlexCelPdfExport(xls, true))
      pdf.Export(ms);
  return File(ms.ToArray(), "application/pdf", "report.pdf");
  ```
- On **Azure App Service Linux / Docker** containers, install fonts via the Dockerfile (`apt install fonts-liberation fonts-dejavu`) or bundle them in `/app/fonts` and point `GetFontFolder` at that path. Without this, PDFs render with fallback fonts.
- The `FlexCel.AspNet` namespace has helpers for legacy ASP.NET WebForms scenarios — rarely needed in new projects.

## CSV and images

- CSV writing/reading is built into `XlsFile` with options for delimiters/encoding. Tip: `understanding-csv-files.md`.
- **Embedding SVG:** `.xlsx` supports SVG images natively on recent Excel versions. Tip: `svg-files-inside-xlsx-files.md`.
- **Barcodes:** not a native cell type — use fonts or pre-rendered images. Tip: `using-barcodes.md`.

## Miscellaneous

- **`IDisposable` recap:** `FlexCelReport`, `FlexCelPdfExport`, `FlexCelHtmlExport`, `FlexCelImgExport`, `PdfWriter` → wrap in `using`. `XlsFile` → just let GC collect it.
- **Open generated file in Excel:** `tips/automatically-open-generated-excel-files.md` shows the `Process.Start` pattern with a verb.
- **Embed Excel template as an embedded resource** and load from `Assembly.GetManifestResourceStream`: `tips/embedding-excel-files-in-your-application.md`.
- **Replace a font throughout a file**: `tips/replacing-a-font-by-another-in-an-excel-file.md`.
- **Hyperlinks in a cell**: `tips/how-to-get-the-hyperlink-in-a-given-cell.md`.
- **Version string:** `FlxConsts.FlexCelVersion`. Tip: `finding-out-the-flexcel-version.md`.

## Jump to the full tip list

`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.NET-doc-src/main/tips/index.md` — table of contents for every tip. Fetch individual tips on demand via `WebFetch`.
