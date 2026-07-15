# PDF and HTML export

Render `.xlsx` / `.xls` files to PDF, HTML, SVG, or bitmap images using the FlexCel rendering engine. Unit: **`FlexCel.Render`**. The platform-support unit (`FlexCel.VCLSupport`, `FlexCel.FMXSupport`, `FlexCel.LCLSupport`, `FlexCel.SKIASupport`) **must be in the main `.dpr`** — the renderer depends on it for font measurement and glyph rasterization.

## PDF export — `TFlexCelPdfExport`

### Minimum

```pascal
uses FlexCel.Core, FlexCel.XlsAdapter, FlexCel.Render;

procedure ToPdf(const src, dst: string);
var xls: TXlsFile; pdf: TFlexCelPdfExport;
begin
  xls := TXlsFile.Create(src);
  try
    pdf := TFlexCelPdfExport.Create(xls);
    try
      pdf.Export(dst);
    finally pdf.Free end;
  finally xls.Free end;
end;
```

`Export(filename)` writes a PDF covering **all visible sheets** honoring each sheet's page-setup (orientation, margins, headers/footers, print area, print titles). To override page setup, change `xls.PrintOptions`, `xls.PrintMargins`, etc. *before* exporting — or use APIMate on a sample file.

### Selective export

```pascal
pdf.BeginExport(fileName);         // or (stream)
try
  pdf.ExportSheet('Summary');
  pdf.ExportSheet('Details');
  // skip 'Notes' sheet
finally
  pdf.EndExport;
end;
```

Or export all visible sheets but control bookmarks / hidden sheets:
```pascal
pdf.ExportAllVisibleSheets(includeHidden := false, outlineText := 'Report');
```

### PDF/A, signing, embedding — common options

```pascal
pdf.PdfType := TPdfType.PdfA3;               // or PdfA1, PdfA2, Standard
pdf.FontEmbed := TFontEmbed.Embed;           // Embed / NotEmbed / EmbedNonStandard
pdf.FontSubset := true;                      // embed only used glyphs (smaller files)
pdf.CompressionLevel := 9;
pdf.Author := 'My App';
pdf.Title := 'Quarterly Report';
pdf.FallbackFonts := 'Arial Unicode MS;Noto Sans';
pdf.HeuristicFontOverrides := TPdfFontOverrides.Enabled;   // help on missing fonts
```

For **digital signatures**:

```pascal
uses FlexCel.Pdf;  // for TPdfSignature

pdf.Signature := TPdfSignature.Create;
pdf.Signature.Certificate := TPdfCertificate.FromFile('cert.pfx', 'pwd');
pdf.Signature.Reason := 'Approved';
pdf.Signature.Location := 'Madrid';
pdf.Export('signed.pdf');
```

See the "Sign your PDFs" tip for the full story:
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.VCL-doc-src/main/tips/sign-your-pdfs.md`

### Fonts on non-Windows / Docker

PDF rendering needs access to the font files used in the workbook. On Windows they're found automatically in `C:\Windows\Fonts`. On Linux / macOS / Docker containers you may have to either:

- Install the fonts (e.g. `ttf-mscorefonts-installer` on Debian), or
- Point FlexCel at a font folder:
  ```pascal
  TFontEvents.GetFontFolder := function: string begin Result := '/app/fonts'; end;
  ```
- Or provide font data per lookup:
  ```pascal
  TFontEvents.GetFontData := MyGetFontDataProc;
  ```

Relevant tips:
- `tips/cloud-fonts.md`
- `tips/finding-the-actual-fonts-used-when-exporting-to-pdf.md`
- `tips/running-flexcel-inside-docker-containers.md`
- `tips/font-licensing.md`

### Counting / pre-flighting pages

```pascal
pdf.BeginExport('out.pdf');
try
  pages := pdf.TotalPages;                   // before anything is written
  ...
  pdf.ExportAllVisibleSheets(...);
finally
  pdf.EndExport;
end;
```

See `tips/finding-out-how-many-pages-will-be-exported.md`.

## HTML export — `TFlexCelHtmlExport`

```pascal
uses FlexCel.Core, FlexCel.XlsAdapter, FlexCel.Render;

procedure ToHtml(const src, dst: string);
var xls: TXlsFile; html: TFlexCelHtmlExport;
begin
  xls := TXlsFile.Create(src);
  try
    html := TFlexCelHtmlExport.Create(xls);
    try
      html.HtmlVersion := THtmlVersion.Html_5;
      html.EmbedImages := THtmlImageEmbed.All;     // single-file output
      html.Export(dst);
    finally html.Free end;
  finally xls.Free end;
end;
```

Key properties:

| Property | Use |
|----------|-----|
| `HtmlVersion` | `Html_4` (table-based) or `Html_5` (div-based, cleaner) |
| `EmbedImages` | `None` (external files), `Pictures`, or `All` (inline base64) |
| `SavedImagesFormat` | `Png`, `Jpg`, `Svg` for embedded charts/images |
| `BaseUrl` | prefix for relative hyperlinks in the output |
| `HtmlFileFormat` | full page vs. embeddable HTML fragment |
| `ExportCss` | inline vs. external `.css` file |

Export multi-sheet files with tabs:
```pascal
html.ExportAllVisibleSheets('report.html', OutlineText := 'Q4');
```

See `guides/html-exporting-guide.md` for layout tuning — particularly how Excel cell rendering maps to HTML tables/divs and what isn't supported (rotated text is rasterized, certain conditional formats degrade, etc.).

## Image / SVG export — `TFlexCelImgExport`

Lower-level — render a range or sheet to a VCL/FMX bitmap or an SVG stream. Useful for preview panes and thumbnail generation. Check `api/FlexCel.Render/TFlexCelImgExport/` in the doc source. Common pattern:

```pascal
img := TFlexCelImgExport.Create(xls);
try
  img.PageSize := TPaperSize.A4;
  img.Resolution := 150;
  bmp := TBitmap.Create;
  try
    img.ExportNext(bmp.Canvas, pageWidth, pageHeight);
    bmp.SaveToFile('preview.bmp');
  finally bmp.Free end;
finally img.Free end;
```

## Common pitfalls

1. **Forgetting the platform-support unit.** Missing `FlexCel.VCLSupport` (or FMX/LCL/SKIA) in the `.dpr` → runtime exception the first time you create a `TFlexCelPdfExport`.
2. **Empty PDF pages.** Usually means the sheet's *print area* is unset or too small. Render in Excel's Print Preview to verify. FlexCel respects sheet print settings exactly.
3. **Blank formula cells in PDF.** Formulas with no cached result appear empty. Call `xls.Recalc` before export.
4. **Wrong fonts substituted on Linux.** Install the fonts or provide them via `TFontEvents.GetFontData`. See the font-related tips listed above.
5. **PDF file huge.** Enable `FontSubset := true`. If images are oversized, downsample them before inserting (`pdf.ImageResample := ...`).
