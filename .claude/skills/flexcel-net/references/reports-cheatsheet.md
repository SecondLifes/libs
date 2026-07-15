# FlexCelReport cheatsheet (.NET)

Template-driven Excel reporting. Namespace: **`FlexCel.Report`** (plus `FlexCel.Core` and `FlexCel.XlsAdapter`). For a gentle intro, see `guides/reports-developer-guide.md` and `guides/reports-designer-guide.md` in the doc source.

## The mental model

1. A **designer** (your user, or you) builds a normal `.xlsx` file that acts as a **template**. Cells contain literal text, formulas, formatting, images — and special **tags** like `<#Customers.Name>`.
2. Repeating rows/columns are declared via **Excel named ranges** with magic names (e.g. `__Customers__`).
3. From code, you register data sources under the same names (`Customers`, `Orders`, …), set scalar values, and call `Run`. FlexCel walks the template, expands bands, substitutes tags, leaves the rest untouched.
4. Output is an `.xlsx` file with no tags. You can also pipe the result directly into `FlexCelPdfExport` to get PDF.

This gives non-programmers (designers, accountants) control of the layout without code changes.

## Minimal code

```csharp
using System;
using System.Collections.Generic;
using FlexCel.Core;
using FlexCel.XlsAdapter;
using FlexCel.Report;

void RunCustomerReport(List<Customer> customers)
{
    using var report = new FlexCelReport(caseInsensitive: true);

    report.AddTable("Customers", customers);
    report.SetValue("ReportDate", DateTime.Now);
    report.SetValue("CompanyName", "Acme Corp");

    report.Run("customer-template.xlsx", "customer-output.xlsx");
}
```

`FlexCelReport` implements `IDisposable` — always wrap in `using`.

Overloads of `Run`:

```csharp
report.Run(string templateFile, string outputFile);
report.Run(string templateFile, XlsFile outputXls);    // in-memory — useful before PDF export
```

## Supplying data

```csharp
// Generic list / IEnumerable<T> — the common case with POCOs
report.AddTable("Customers", customerList);

// ADO.NET DataTable
report.AddTable("Orders", ordersTable);

// A whole DataSet — each DataTable inside is registered by DataTable.TableName
report.AddTable(myDataSet);

// Arrays of objects (less common)
report.AddTable("Rows", rowArray);

// Single-arg: the band name is inferred from the generic type name
report.AddTable(customerList);         // band name = "Customer" or "CustomerList"

// A constant (date, number, bool, string)
report.SetValue("ReportTitle", "Q4 Summary");
report.SetValue("RunAt", DateTime.Now);
```

Table names in code must match the band names in the template (case-insensitive when `caseInsensitive: true`, which is the recommended setting).

`IQueryable<T>` is supported too — you can hand `FlexCelReport` an EF Core query and it will enumerate it at Run time.

## Template tags — overview

All tags are of the form `<#something>` and live inside cell text. You can mix them with literal text: `Hello <#Customers.Name>!`.

### Value tags
```
<#Customers.Name>             field of the current record in band 'Customers'
<#ReportTitle>                scalar set with SetValue
<#db.Customers.Name>          same as first form (db. prefix is optional)
<#Customers.Address.City>     navigate through nested object properties
```

### Aggregate tags
```
<#sum(Orders.Total)>          sum over the band currently expanding
<#avg(Orders.Total)>
<#min(...)> <#max(...)>
<#count(Orders)>              row count in the table
```

Aggregates evaluate over the current enclosing band, which gives you subtotals "for free".

### Formula tags
```
<#formula(=SUM(<#row.first>:<#row.last>))>
<#row.first> / <#row.last> / <#row>    metadata about the current band
```

### Conditional / control flow
```
<#if(Customers.Credit > 1000; "VIP"; "Normal")>
<#ifs(c1; v1; c2; v2; default)>
<#delete row(condition)>      delete this row in output if condition is true
<#delete column(condition)>
<#delete sheet(condition)>
<#evaluate(expr; loop)>
```

### Format tags
```
<#format cell(FormatName)>            apply a named format to this cell
<#format row(FormatName)>             apply to the whole output row
<#format column(FormatName)>
<#format range(A1:B4; FormatName)>
<#merge range(A1:B2)>
```

Named formats live in a **config sheet** (see below). `FormatName` can itself be a report expression — compute formats per row.

### Lookup tags
```
<#lookup(Products; Code; Orders.ProductCode; Name)>
        ^table    ^key ^searchValue        ^fieldToReturn
```

Equivalent to `VLOOKUP`, but evaluated at report time against the provided data — not against Excel cells.

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

For the **full, authoritative tag list** fetch `guides/reports-tag-reference.md` from
`https://raw.githubusercontent.com/tmssoftware/TMS-FlexCel.NET-doc-src/main/guides/reports-tag-reference.md`.

## Band conventions — how repeating sections are declared

A **band** is an Excel **named range** whose name follows a convention. Create named ranges in Excel's Name Manager. The range spans the cells to repeat; the name tells FlexCel what to do with it.

Horizontal bands (rows repeat):

| Range name      | Effect |
|-----------------|--------|
| `__Customers__` | For each row in `Customers`, insert a copy of the range (new rows pushed down). Double underscore = "insert full rows". |
| `_Customers_`   | Same, but only shift cells inside the range — not full rows. Use in compact layouts. |
| `__Customers__FIXED` | Write each record into successive pre-existing rows without inserting. Template must already have enough rows. |
| `__Customers__X` | "Delete one row after" — useful for collapsing totals when there are no details. |

Vertical bands (columns repeat): prefix with `I` — e.g. `II_Months_II`. Less common; for pivot-style wide reports.

**Master-detail = nesting:**

- Define `__Customers__` spanning rows 5–10.
- Inside, define `__Orders__` on rows 7–8.
- FlexCel auto-filters `Orders` by the current `Customers` record **if the relationship is declared**:

```csharp
report.AddRelationship("Customers", "Orders", "CustomerID", "CustomerID");
```

If the relationship is implicit (same-named key field) it is often auto-detected, but the explicit `AddRelationship` call is safer and clearer.

You can nest arbitrarily deep (Customers > Orders > OrderDetails).

## Config sheet

A sheet named `Config` (or one whose cell A1 contains `<#config>`) is removed from the output. Use it to hold named formats, filters, sort orders, and other directives:

| Cell pattern | Use |
|--------------|-----|
| `<#format name("Currency")>` anchor cell, plus an adjacent cell styled `$#,##0.00` | defines a named format usable from `<#format cell(Currency)>` |
| `<#filter(Customers; active = true)>` | filters a table after it is loaded |
| `<#sort(Orders; OrderDate desc)>` | sorts rows before expansion |

Full config syntax is in `guides/reports-designer-guide.md`.

## Events and user functions

```csharp
report.OnLoadTable        += ...;     // intercept / substitute data loading
report.OnGenerate         += ...;     // intercept output after each band iteration
report.OnCustomizeChart   += ...;     // tweak charts per record
report.Progress           += ...;     // show progress UI
report.OnGetInclude       += ...;     // resolve <#include(dynamic)>
report.FlexCelDataConversion += ...;  // custom .NET-to-Excel conversion
```

Custom functions callable from templates:

```csharp
report.SetUserFunction("MyFunc", new MyFuncImpl());
// Template: <#MyFunc(Customers.Code)>
```

Custom formats:

```csharp
report.SetUserFormat("Currency", new MyCurrencyFormat());
```

## Output directly to PDF

```csharp
var outXls = new XlsFile();
report.Run("template.xlsx", outXls);

using var pdf = new FlexCelPdfExport(outXls, true);
pdf.Export("report.pdf");
```

## Native AOT note

If the app uses **.NET 9 Native AOT**, the reporting engine works for common cases but relies on reflection against your POCOs. **Annotate each class passed to `AddTable`:**

```csharp
using System.Diagnostics.CodeAnalysis;

[DynamicallyAccessedMembers(
    DynamicallyAccessedMemberTypes.PublicProperties |
    DynamicallyAccessedMemberTypes.PublicMethods)]
public class Customer
{
    public string FirstName { get; set; }
    public string LastName  { get; set; }
}
```

Without the attribute, trimming silently strips property accessors and the report outputs blank cells (not an exception). See `references/pitfalls.md` for the full story.

## Debugging templates

- `<#debug>` in a cell shows the internal state of the evaluator at that point.
- Unexpanded tag text left in the output is the #1 diagnostic signal — if `<#Customers.name>` appears verbatim in the result, the `Customers` table was never registered (or the tag is misspelled or `caseInsensitive` is false).
- Always use **`caseInsensitive: true`** unless you have a specific reason not to.

## When to fall back to the docs

- Full tag reference with every parameter → `guides/reports-tag-reference.md` from the raw-markdown URL.
- Worked end-to-end examples (invoices, master-detail, subreports) → `guides/reports-developer-guide.md`, or the public demo repo `https://github.com/tmssoftware/TMS-FlexCel.NET-demos`.
- Template design walkthroughs with screenshots → `https://doc.tmssoftware.com/flexcel/net/guides/reports-designer-guide.html`.
