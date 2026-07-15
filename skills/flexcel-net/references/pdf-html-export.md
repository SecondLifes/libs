# PDF, HTML, and image export (.NET)

Render `.xlsx` / `.xls` files to PDF, HTML, SVG, or bitmap images. Namespace: **`FlexCel.Render`**. For low-level PDF access (standalone PDF creation, advanced signing), also `FlexCel.Pdf`. All render classes are fully managed and cross-platform — **no platform-support assembly required on .NET** (unlike the VCL edition).

## PDF export — `FlexCelPdfExport`

### Minimum

```csharp
using FlexCel.Core;
using FlexCel.XlsAdapter;
using FlexCel.Render;

void ToPdf(string src, string dst)
{
    var xls = new XlsFile(src);
    using var pdf = new FlexCelPdfExport(xls, allowOverwritingFiles: true);
    pdf.Export(dst);
}
```

`Export(filename)` writes a single PDF covering **all visible sheets**, honoring each sheet's page-setup (orientation, margins, headers/footers, print area, print titles). To override page setup, change `xls.PrintOptions`, `xls.PrintPaperSize`, `xls.PrintHCentered`, margins, etc. *before* exporting — or use APIMate on a sample Excel file to generate the correct property assignments.

### Selective export / multiple workbooks in one PDF

```csharp
using var pdf = new FlexCelPdfExport();
pdf.AllowOverwritingFiles = true;

using var stream = new FileStream("combined.pdf", FileMode.Create);
pdf.BeginExport(stream);

pdf.Workbook = xls1;
pdf.ExportAllVisibleSheets(includeHidden: false, outlineText: "Report 1");

pdf.Workbook = xls2;
pdf.ExportAllVisibleSheets(false, "Report 2");

pdf.EndExport();
```

Or export only specific sheets:

```csharp
pdf.BeginExport("out.pdf");
pdf.ExportSheet("Summary");
pdf.ExportSheet("Details");
pdf.EndExport();
```

### PDF/A, embedding, compression

```csharp
pdf.PdfType          = TPdfType.PdfA3;       // or PdfA1, PdfA2, Standard
pdf.FontMapping      = TFontMapping.EmbedAllFonts; // or ReplaceAll / EmbedAllAvailable
pdf.FontSubset       = true;                  // embed only glyphs used — smaller files
pdf.CompressionLevel = 9;
pdf.Author           = "My App";
pdf.Title            = "Quarterly Report";
pdf.FallbackFonts    = "Arial Unicode MS;Noto Sans";
pdf.HeuristicFontOverrides = TPdfFontOverrides.Enabled;
pdf.Kerning          = true;
```

### Digital signing

```csharp
using FlexCel.Pdf;

var sig = new TPdfSignature();
sig.Certificate = TPdfCertificate.FromFile("cert.pfx", "password");
sig.Reason      = "Approved";
sig.Location    = "Madrid";
sig.ContactInfo = "ops@example.com";

pdf.Signature = sig;
pdf.Export("signed.pdf");
```

See the "Sign your PDFs" tip for the full story:
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.NET-doc-src/main/tips/sign-your-pdfs.md`

### Fonts on Linux / macOS / Docker

PDF rendering needs access to the font files used in the workbook. On Windows they're found automatically in `C:\Windows\Fonts`. Elsewhere you'll typically either:

- Install the fonts in the OS (`apt install fonts-liberation fonts-dejavu`, or `ttf-mscorefonts-installer` for Microsoft fonts), or
- Point FlexCel at a font folder at runtime:
  ```csharp
  pdf.GetFontFolder += (sender, e) => { e.FontFolder = "/app/fonts"; };
  ```
- Or provide font data per lookup (fonts in embedded resources, a blob store, etc.):
  ```csharp
  pdf.GetFontData += (sender, e) =>
  {
      e.FontData = MyFontStore.GetTtfBytes(e.FontRequest);
  };
  ```

Relevant tips (fetch the raw markdown for details):
- `tips/cloud-fonts.md`
- `tips/finding-the-actual-fonts-used-when-exporting-to-pdf.md`
- `tips/running-flexcel-inside-docker-containers.md`
- `tips/font-licensing.md`

### Counting / pre-flighting pages

```csharp
pdf.BeginExport("out.pdf");
int pages = pdf.TotalPages;          // known before anything is drawn
pdf.ExportAllVisibleSheets(false);
pdf.EndExport();
```

See `tips/finding-out-how-many-pages-will-be-exported.md`.

### Events for per-page customisation

```csharp
pdf.BeforeGeneratePage += (s, e) => { /* draw watermark, adjust layout */ };
pdf.AfterGeneratePage  += (s, e) => { /* post-process this page */ };
```

These expose the underlying `PdfWriter` (namespace `FlexCel.Pdf`) so you can draw raw PDF content.

## HTML export — `FlexCelHtmlExport`

```csharp
using FlexCel.Core;
using FlexCel.XlsAdapter;
using FlexCel.Render;

void ToHtml(string src, string dst)
{
    var xls = new XlsFile(src);
    using var html = new FlexCelHtmlExport(xls, allowOverwritingFiles: true);
    html.HtmlVersion  = THtmlVersion.Html_5;
    html.EmbedImages  = THtmlImageEmbed.All;  // inline base64 → single-file output
    html.Export(dst);
}
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

Export all sheets as tabs in a single HTML document:

```csharp
html.ExportAllVisibleSheets("report.html", outlineText: "Q4");
```

See `guides/html-exporting-guide.md` for layout-fidelity tuning — which Excel features map cleanly to HTML (most cell styles, merged cells, conditional formats), which become rasterized (rotated text, complex charts), and which are lossy (certain print-layout features).

## Image / SVG export — `FlexCelImgExport`

Lower-level — render a range or sheet to a `System.Drawing.Bitmap`, `SKBitmap` (via SkiaSharp on non-Windows), or an SVG stream. Useful for preview panes and thumbnail generation in WinForms / WPF / MAUI / Blazor.

```csharp
using var img = new FlexCelImgExport(xls);
img.PageSize   = TPaperSize.A4;
img.Resolution = 150;

using var bmp = new System.Drawing.Bitmap((int)pageWidth, (int)pageHeight);
using (var g = System.Drawing.Graphics.FromImage(bmp))
{
    img.ExportNext(g, pageWidth, pageHeight);
}
bmp.Save("preview.png");
```

For SVG:

```csharp
img.ExportNextSVG(outputStream, pageWidth, pageHeight);
```

Check `api/FlexCel.Render/FlexCelImgExport/` in the doc source for the full surface.

## PdfWriter — low-level PDF

`FlexCel.Pdf.PdfWriter` can create PDFs from scratch (without an Excel file). It is not the intended primary use — most apps use `FlexCelPdfExport`. Use `PdfWriter` when you need to:

- Draw custom PDF content in a `BeforeGeneratePage` / `AfterGeneratePage` handler.
- Build a cover page or appendix that isn't an Excel file and merge it with `FlexCelPdfExport` output.
- Sign / encrypt PDFs produced from other sources.

See `api/FlexCel.Pdf/PdfWriter/` in the doc source.

## Common pitfalls

1. **Empty PDF pages.** Usually the sheet's print area is unset or too small. Open in Excel's Print Preview to verify — FlexCel respects sheet print settings exactly.
2. **Blank formula cells in PDF.** Formulas with no cached result are rendered empty. Call `xls.Recalc()` before export.
3. **Wrong fonts substituted on Linux.** Install the fonts or wire `GetFontFolder` / `GetFontData`. See font tips above.
4. **PDF file huge.** Enable `FontSubset = true`. For oversized images pre-downsample before inserting.
5. **Native AOT:** PDF / HTML / image export are fully supported. No annotations needed.
6. **ASP.NET Core thread contention** when exporting many files concurrently: `FlexCelPdfExport` is not thread-safe — don't share one instance across requests. Create it per request.
