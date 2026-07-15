# Common pitfalls and tips

A curated list of gotchas drawn from the official FlexCel Tips section. Each entry is short; fetch the full tip from the doc-source repo when you need detail:
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.VCL-doc-src/main/tips/<filename>.md`

## Indexing and measurement

- **1-based everywhere** except XF format indices (0-based). `SetCellValue(1,1,...)` is `A1`.
- **Column width**: 1/256 of the width of the `'0'` character in the default font. (Not pixels, not points.)
- **Row height**: 1/20 of a point. `20 pt` = `400`.
- **Font size**: `Font.Size20` is in 1/20 of a point. `11 pt` = `220`.
- **Colors**: xlsx uses true RGB; `TExcelColor.FromColor(TColors.Red)`. Legacy `.xls` palettes are auto-mapped.
- Tip: `understanding-excel-measurement-units.md`

## Performance

- **Never use `ColCount` inside a read loop.** It scans the entire sheet. Use `ColCountInRow(row)` + `GetCellValueIndexed` + `ColFromIndex`.
- Reading the **first row** to determine a header? Use `ColCountInRow(1)`, not `ColCount`. Tip: `reading-first-row.md`.
- For giant files, consider **virtual mode** on `TXlsFile.Create`. See `guides/performance-guide.md`.
- **Avoid too many rows.** Excel's hard limit is ~1.05 M rows, but files slow to a crawl well before that. Split datasets across sheets. Tip: `avoiding-too-many-rows.md`.

## Dates, numbers, text

- Excel stores dates as numbers. `GetCellValue` returns the serial number. Detect "this is a date" by inspecting the cell's number-format string, not the value type.
- **Multi-line cells**: use `#10` (LF) inside the string and set `WrapText := true` in the format. Tip: `multi-line-cells.md`.
- **Text rotation** differs between `.xls` and `.xlsx`. Tip: `text-rotation-in-xls-and-xlsx.md`.
- Excel's built-in number formats are identified by **numeric IDs** internally. Tip: `internal-numeric-formats.md`.

## Fonts and locale

- **Font on Linux/Docker**: ship fonts with the app or point at a folder via `TFontEvents.GetFontFolder`. Without the font files, PDF rendering falls back and layout drifts.
- **Font licensing**: embedding commercial fonts into PDF may require a license. Tip: `font-licensing.md`.
- **Cloud fonts / Office fonts**: recent `.xlsx` files often reference cloud-only fonts (Aptos, Bahnschrift variants). Install or substitute. Tip: `cloud-fonts.md`.
- **Locale**: FlexCel uses the current OS locale by default. Override via `TFlxConsts.SetLocale(...)`. Tip: `how-to-change-the-flexcel-locale.md`.
- **Localized month names in formats**: use `[$-xxx]` format prefixes. Tip: `localized-month-names.md`.

## Formulas

- **Write formulas with cached values** when possible: `TFormula.Create('=A1+1', 42)`. Otherwise call `xls.Recalc` before export or the PDF will show blanks.
- **Expanding formulas**: ranges like `A1:A3` are relative to context. Tip: `expanding-formulas.md`.
- **Semi-absolute references** (`A$1`, `$A1`) behave as in Excel. Tip: `semi-absolute-references.md`.
- To analyze existing formulas (tokens, precedents), see `using-tokens-to-get-information-from-formulas.md`.

## Conditional formatting and data validation

- **Prefer conditional formats over applying direct formats row-by-row** when the rule is expressible — much smaller files, better performance. Tip: `prefer-conditional-formats.md`.
- References inside conditional formats and data validations are stored differently from cell formulas — don't hand-edit. Tip: `references-in-conditional-formats-and-data-validations.md`.

## Reports

- Tag not expanding? Likely causes: (1) table not registered with `AddTable`; (2) name mismatch and you created the report with `caseSensitive = true`; (3) the tag is outside any named range, so there's no band to iterate.
- **`<#include>` recursion** is fine but be aware sub-templates resolve relative to the main template's folder.
- **Master-detail without a declared relationship** will sometimes "work" via implicit field name matching but is fragile — always call `AddRelationship` explicitly for anything non-trivial.

## PDF export

- Blank pages → check print area and page setup on the source sheet.
- Huge output → enable `FontSubset`.
- `TFlexCelPdfExport` needs the **platform-support unit** (`FlexCel.VCLSupport` etc.) in the `.dpr` — otherwise you get a "no graphics engine" error at runtime.
- Signing PDFs: `tips/sign-your-pdfs.md`.

## Strict XLSX, XLSM, XLSB

- FlexCel reads and writes the default `.xlsx` dialect. **Strict XLSX** (ISO-conformant) is readable; preserve-on-save behavior is covered in `tips/using-strict-xlsx-files.md`.
- Macro-enabled files (`.xlsm`, `.xlsb`) — FlexCel preserves macros but does not execute them.

## CSV and images

- CSV writing/reading is in `TXlsFile` with options for delimiters/encoding. Tip: `understanding-csv-files.md`.
- **Embedding SVG**: `.xlsx` supports SVG images natively on recent Excel versions. Tip: `svg-files-inside-xlsx-files.md`.
- **Barcodes**: not a native cell type; use fonts or pre-rendered images. Tip: `using-barcodes.md`.
- **Scalable images in docs**: `tips/scalable-images-in-your-documentation.md`.

## Miscellaneous

- **FlexCel.Core vs FlexCel.VCLSupport**: Core is the engine; VCLSupport (and siblings) only hook the graphics system. Include VCLSupport once in the `.dpr`. Tip: `vcl-flexcel-core-vs-flexcel-vclsupport.md`.
- **Open generated file in Excel**: `tips/automatically-open-generated-excel-files.md` shows the shell-execute pattern.
- **Embed Excel template as a resource**: `tips/embedding-excel-files-in-your-application.md`.
- **Replace a font throughout a file**: `tips/replacing-a-font-by-another-in-an-excel-file.md`.
- **Hyperlinks in a cell**: `tips/how-to-get-the-hyperlink-in-a-given-cell.md`.
- **Version string**: `TFlxConsts.FlexCelVersion`. Tip: `finding-out-the-flexcel-version.md`.

## Jump to the full tip list

`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.VCL-doc-src/main/tips/index.md` — table of contents for every tip. Fetch individual tips on demand.
