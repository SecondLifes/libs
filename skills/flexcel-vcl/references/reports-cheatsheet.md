# TFlexCelReport cheatsheet

Template-driven Excel reporting. Unit: **`FlexCel.Report`** (plus `FlexCel.Core` and `FlexCel.XlsAdapter`). For a gentle intro, see `guides/reports-developer-guide.md` and `guides/reports-designer-guide.md` in the doc source.

## The mental model

1. A **designer** (your user, or you) builds a normal `.xlsx` file that acts as a **template**. Cells contain literal text, formulas, formatting, images — and special **tags** like `<#Customers.Name>`.
2. Repeating rows/columns are declared via **Excel named ranges** with magic names (e.g. `__Customers__`).
3. From code, you give `TFlexCelReport` the same data names (`Customers`, etc.), then `Run` the template to an output file. FlexCel walks the template, expands bands, substitutes tags, leaves the rest untouched.
4. Output is an `.xlsx` file with no tags. You can also pipe the result into `TFlexCelPdfExport` to get PDF directly.

This gives non-programmers (designers, accountants) control of the layout without code changes.

## Minimal code

```pascal
uses FlexCel.Core, FlexCel.XlsAdapter, FlexCel.Report;

procedure RunCustomerReport(const Customers: TDataSet);
var
  report: TFlexCelReport;
begin
  report := TFlexCelReport.Create(true);     // true = case-insensitive tag matching
  try
    report.AddTable('Customers', Customers, TDisposeMode.DoNotDispose);
    report.SetValue('ReportDate', Now);
    report.SetValue('CompanyName', 'Acme Corp');
    report.Run('customer-template.xlsx', 'customer-output.xlsx');
  finally
    report.Free;
  end;
end;
```

Overloads of `Run`:
```pascal
report.Run(TemplateFilename, OutputFilename: string);
report.Run(TemplateXls, OutputXls: TXlsFile);   // in-memory; useful before PDF export
```

## Supplying data

```pascal
// TDataSet (FireDAC, ClientDataSet, query, any TDataSet descendant)
report.AddTable('Orders', myQuery, TDisposeMode.DoNotDispose);

// Generic list of Delphi objects — use published properties or SetValueExpression
report.AddTable<TCustomer>('Customers', myTList);

// Plain arrays
report.AddTable<TOrder>('Orders', myTArrayOfOrder);

// A whole TDataModule — every TDataSet inside is registered by its component name
report.AddTable(dmCustomers);

// A single scalar (constant, date, string, number, bool)
report.SetValue('ReportTitle', 'Q4 Summary');
report.SetValue('RunAt', Now);
```

Table names you pass in code must match the band names used in the template (case-insensitive when you pass `true` to the constructor).

## Template tags — overview

All tags are of the form `<#something>` and live inside cell text. You can mix them with literal text: `Hello <#Customers.Name>!`.

### Value tags
```
<#Customers.Name>             field of the current record in band 'Customers'
<#ReportTitle>                scalar set with SetValue
<#db.Customers.Name>          same as first form (db. prefix is optional)
<#Customers.Address.City>     navigate through object properties / lookups
```

### Aggregate tags
```
<#sum(Orders.Total)>          sum over the band currently expanding
<#avg(Orders.Total)>
<#min(...)> <#max(...)>
<#count(Orders)>              row count in the table
```

Aggregates evaluate over the current enclosing band, not the whole table — which is what you want for subtotals.

### Formula tags
```
<#formula(=SUM(<#row.first>:<#row.last>))>
<#row.first> / <#row.last> / <#row>    metadata about the current band
```

### Conditional / control flow
```
<#if(Customers.Credit > 1000; "VIP"; "Normal")>
<#ifs(c1; v1; c2; v2; default)>
<#evaluate(expr; loop)>
<#delete row(condition)>      delete this row in output if condition is true
<#delete column(condition)>
<#delete sheet(condition)>
```

### Format tags
```
<#format cell(FormatName)>            apply a named format to this cell
<#format row(FormatName)>             apply to the whole output row
<#format column(FormatName)>
<#format range(A1:B4; FormatName)>
<#merge range(A1:B2)>
```

Named formats are stored in a **config sheet** (see below). `FormatName` can also be a report expression — you can compute formats per row.

### Lookup tags
```
<#lookup(Products; Code; Orders.ProductCode; Name)>
        ^table    ^key ^searchvalue       ^field-to-return
```

Equivalent to `VLOOKUP`, but evaluated at report time and resolved against the provided data, not Excel cells.

### Include tags (subreports)
```
<#include(subtemplate.xlsx)>
<#include(<#Customers.Template>)>          dynamic include per record
```

### Built-in helpers
```
<#row()>  <#col()>  <#sheet()>
<#defined(varname)>                         true if the scalar/table exists
<#defined(varname; default)>                value or fallback
<#year(date)>  <#month(date)>  <#day(date)>
<#upper(s)> <#lower(s)>  <#concat(a; b; c)>
```

For the **full, authoritative tag list** see
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.VCL-doc-src/main/guides/reports-tag-reference.md`.
Fetch that file when you need a tag that's not in this cheatsheet.

## Band conventions — how repeating sections are declared

A **band** is an Excel **named range** whose name follows a convention. You create named ranges in Excel's Name Manager. The range spans the cells to repeat; the name tells FlexCel what to do with it.

Horizontal bands (rows repeat):
| Range name      | Effect |
|-----------------|--------|
| `__Customers__` | For each row in `Customers`, insert a copy of the range (new rows pushed down). Double underscore = "insert full rows". |
| `_Customers_`   | Same, but only shift cells inside the range — not full rows. Use in compact layouts. |
| `__Customers__FIXED` | Write each record into successive pre-existing rows without inserting. The template must already have enough rows. |
| `__Customers__X` | "Delete one row after" — useful for collapsing totals when there are no details. |

Vertical bands (columns repeat): prefix the same names with `I` — e.g. `II_Months_II`. Less commonly used; for pivot-style wide reports.

**Master-detail** = **nesting**:
- Make a range `__Customers__` spanning rows 5–10.
- Inside, make a range `__Orders__` on rows 7–8.
- FlexCel auto-filters `Orders` by the current `Customers` record **if the relationship is declared**:

```pascal
report.AddRelationship('Customers', 'Orders', 'CustomerID', 'CustomerID');
```

If the relationship is implicit (same-named key field), it is often auto-detected, but calling `AddRelationship` is the safe, explicit form.

You can nest arbitrarily deep (Customers > Orders > OrderDetails).

## Config sheet

A sheet named `Config` (or tagged with `<#config>` in cell A1) is removed from the output. Use it to hold named formats, filters, sort orders, and other report directives. Typical contents:

| Cell | Use |
|------|-----|
| `<#format name("Currency")>` anchor cell, then a cell styled as $#,##0.00 | defines a named format usable from `<#format cell(Currency)>` |
| `<#filter(Customers; active = true)>` | filters a table after it's loaded |
| `<#sort(Orders; OrderDate desc)>` | sorts rows before expansion |

Full config syntax is in `guides/reports-designer-guide.md`.

## Events and user functions

```pascal
report.OnLoadTable        : TLoadTableEvent;          // intercept / substitute data loading
report.OnGenerate         : TGenerateEvent;           // intercept output after each band iteration
report.OnCustomizeChart   : TCustomizeChartEvent;     // tweak charts per record
report.OnProgress         : TFlexCelReportProgress;   // show progress UI
report.OnGetInclude       : TGetIncludeEvent;         // resolve <#include(dynamic)>
report.OnFlexCelDataConversion : TFlexCelDataConversionEvent;  // custom Delphi→Excel conversion
```

Custom functions callable from templates:

```pascal
report.SetUserFunction('MyFunc', TMyFuncImpl.Create);
// Template: <#MyFunc(Customers.Code)>
```

Custom formats:

```pascal
report.SetUserFormat('Currency', TMyCurrencyFormat.Create);
```

## Output directly to PDF

```pascal
var out: TXlsFile;
    pdf: TFlexCelPdfExport;
begin
  out := TXlsFile.Create;
  try
    report.Run('template.xlsx', out);
    pdf := TFlexCelPdfExport.Create(out);
    try pdf.Export('report.pdf'); finally pdf.Free end;
  finally
    out.Free;
  end;
end;
```

## Debugging templates

- `<#debug>` in a cell shows the internal state of the evaluator at that point.
- Leave tag text in the output when a tag is misspelled — if you see `<#Customers.name>` in the output PDF, the code probably never registered the `Customers` table (or the tag is misspelled).
- Always write **case-insensitive matching** (`TFlexCelReport.Create(true)`) unless you have a specific reason not to.

## When to fall back to the docs

If you need:
- The exhaustive tag list with every parameter — fetch `guides/reports-tag-reference.md` from the raw-markdown URL.
- Worked end-to-end examples (invoices, master-detail, subreports) — fetch `guides/reports-developer-guide.md`, or browse the public demo repo `https://github.com/tmssoftware/TMS-FlexCel.VCL-demos`.
- Template design walkthroughs with screenshots — rendered docs at `https://doc.tmssoftware.com/flexcel/vcl/guides/reports-designer-guide.html`.
