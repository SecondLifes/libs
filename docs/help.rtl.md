---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\help.rtl.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: fda5f627eae1c1c1febc6e8398dbcae8de671a156a457735596415616cdba4fa
---

# help.rtl
`TStrings` için silme, trim, sıralama, filtreleme ve dönüştürme helper'ları.

## Gereksinimler
`Classes`, `mormot.core.text` (TTextWriter), `mormot.core.unicode`

## TStringsHelper — Metodlar

| Metod | Açıklama |
|---|---|
| `DeleteEmpty` | Boş ve whitespace-only satırları siler |
| `TrimAll` | Her satırı trim eder; boş kalanları siler |
| `Deduplicate([caseInsensitive])` | Tekrar eden satırları kaldırır |
| `DeleteWhere(predicate)` | Predicate True dönen satırları siler |
| `Contains(value, [caseInsensitive])` | Değer var mı? |
| `CountEmpty` | Boş satır sayısını döner |
| `IsEmpty` | Count = 0 mu? |
| `ToArray` | `TArray<string>` döner |
| `Join([delimiter])` | Satırları ayraçla birleştirir (varsayılan `,`) — mORMot2 TTextWriter ile sıfır-allocation |
| `AddUnique(value, [caseInsensitive])` | Yoksa ekler |
| `AddRange(array[])` | Dizi ekler |
| `AddRange(source)` | Başka TStrings'ten kopyalar |
| `Filter(predicate)` | Predicate True olanları yeni TStringList döner (caller free eder) |
| `SortAlpha([caseInsensitive])` | Alfabetik sıralar |

## Örnek

```pascal
uses help.rtl;

var SL := TStringList.Create;
try
  SL.Add('  Ahmet  ');
  SL.Add('');
  SL.Add('Veli');
  SL.Add('Ahmet');

  SL.TrimAll;          // boşlukları kırp + boşları sil
  SL.Deduplicate;      // tekrarları kaldır
  SL.SortAlpha;

  ShowMessage(SL.Join(' | ')); // 'Ahmet | Veli'
finally
  SL.Free;
end;
```
