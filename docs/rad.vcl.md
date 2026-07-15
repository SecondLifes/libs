---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\rad.vcl.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: 228763d7f0a66b81e3ba44ea55bf1df328c7100afd5d255f2734b00d833ce7ff
---

# rad.vcl
Kullanıcı başına kısayol yönetimi. `TRadActionList` kendi action'larını JSON olarak saklar/yükler; `TRadAction` global kısayol için `GlobalKey` taşır.

## Gereksinimler
`Vcl.ActnList`, `mormot.core.json`, `mormot.core.variants`, `mormot.core.unicode`

## TRadAction

| Property | Açıklama |
|---|---|
| `GlobalKey: string` | Boşsa action adı kullanılır; doluysa JSON'da bu key ile saklanır (global kısayol) |

## TRadActionList

### Class Events — uygulama başında bir kez atanır

| Event | İmza | Açıklama |
|---|---|---|
| `OnLoad` | `procedure(const AList: TRadActionList)` | Liste create olunca otomatik tetiklenir |
| `OnSave` | `procedure(const AList: TRadActionList)` | Editör tarafından tetiklenir |

### Instance Metodlar

| Metod | Açıklama |
|---|---|
| `ShortCutDefaultStore` | Designer'daki orijinal kısayolları `FDefaultKeys`'e saklar |
| `ShortCutDefaultRestore` | `FDefaultKeys`'den orijinal kısayolları geri yükler |
| `LoadFromJson(json)` | `{"act_save":16467,...}` formatından action kısayollarını yükler |
| `ToJson` | Tüm action kısayollarını JSON olarak döner |

### JSON Formatı

```json
{
  "act_edit":   161,
  "act_delete": 197,
  "act_save":   16467,
  "FILTER":     113
}
```
`GlobalKey` atanmışsa action adı yerine `GlobalKey` kullanılır.

## Örnek

```pascal
uses rad.vcl;

// Program başında bir kez:
TRadActionList.OnLoad := procedure(const AList: TRadActionList)
begin
  AList.LoadFromJson(DB.GetShortcuts(AList.Name));
end;

// Form açılışında otomatik tetiklenir (Loaded → OnLoad(Self))

// Orijinal kısayolları sakla (form create'da):
MyActionList.ShortCutDefaultStore;

// Kullanıcı çıkışında geri yükle:
MyActionList.ShortCutDefaultRestore;
```
