---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\help.db.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: 34f1776e34eebdb05b18538d114635c512b8d868f5679aa4fc25360dc8348a72
---

# help.db
TDataSet, TField ve TSQLTimeStamp için fluent-API helper'ları; mORMot2 tabanlı JSON serializasyon ve RTTI tabanlı field mapping.

## Gereksinimler
`Data.DB`, `SqlTimSt`, `mormot.core.text`, `mormot.core.json`, `mormot.core.datetime`, `mormot.core.variants`, `mormot.core.buffers`, `mormot.core.unicode`

## TDataSetHelper — Metodlar

| Metod | Açıklama |
|---|---|
| `_Open / _Close` | Dataset'i açar/kapatır, `Self` döner (fluent) |
| `_Insert / _Append / _Edit / _Post` | State geçişleri, fluent |
| `_DisableControls / _EnableControls` | UI bağlantısını keser/açar, fluent |
| `_Bookmark(AProc, AGoto)` | Konumu koruyarak proc çalıştırır; AGoto=True ise geri döner |
| `_DoEof(AProc, [Cancel], [SavePos])` | Tüm kayıtları iterasyonla işler; DisableControls dahil |
| `_DoEofAndClose(AProc)` | Open → iterasyon → Close |
| `_EofField(AProc, [ADisable])` | Her field üzerinde proc çalıştırır |
| `_W(field, value, [AIIF])` | Alan yazar — string/integer/boolean/variant/stream overload'ları |
| `_WDt(field, [dt], [AIIF])` | DateTime yazar; dt verilmezse Now |
| `_WTry(field, AProc)` | Field varsa proc çalıştırır, yoksa sessizce geçer |
| `_Value(field, variant, [AIIF])` | Variant değer yazar |
| `_F(field)` | `FieldByName` kısayolu |
| `_Values` / `_Values(fields[])` | Tüm ya da belirli field değerlerini `TArray<Variant>` döner |
| `_Locate(keys, values, [opts])` | DisableControls korumalı Locate |
| `_LoadValue(src, [disable[]])` | Kaynak dataset'ten aynı adlı alanları kopyalar |
| `_LoadValueALL(src, [disable[]], [ABeforePost])` | Kaynak dataset'teki tüm kayıtları Insert+LoadValue ile ekler |
| `_ToJSONArray` | Mevcut satırı görünür fieldlardan JSON dizisi olarak döner (`RawUtf8`) |
| `_ToJSONArrayALL` | Tüm satırları `[[...],[...]]` şeklinde döner (`RawUtf8`, DisableControls korumalı) |
| `_ToJSONArrayALLStr` | `_ToJSONArrayALL` sonucunu `string` olarak döner |
| `_ToJSONObject([disable[]])` | Mevcut satırı `{key:val,...}` olarak döner (`RawUtf8`) |
| `_ToJSONObjectStr([asJson], [disable[]])` | `_ToJSONObject` sonucunu `string` döner |
| `_ToJSONStructure` | Field adı/tipi/boyutunu JSON dizisi olarak döner (`RawUtf8`) |
| `_FromJson(json, recNo, isRecord)` | `RawUtf8` JSON → dataset satırı (belirli kayıt numarasına) |
| `_FromJson(json)` | Object ise tek satır, array ise tüm satırları yükler |
| `_FromJsonArray(json, isRecord)` | JSON dizisini dataset'e aktar |
| `_FromJsonStr(json)` | `string` JSON'u parse edip `_FromJson` çağırır |
| `_AddField(name, type, size, ...)` | Dinamik field ekler |
| `_IsEditOrInsert` | State dsEdit/dsInsert mi? |
| `_IsChangeField(field/fields[])` | Field değişti mi? (OldValue karşılaştırması) |
| `_ReOpen` | Close + Open |
| `_toAs<T>` | Dataset'i T'ye cast eder |

### Özellikler (property)
`_S`, `_I`, `_B`, `_D`, `_DT`, `_V` — string/integer/boolean/extended/datetime/variant shortcut property'leri

## TFieldsHelper — Metodlar

| Metod | Açıklama |
|---|---|
| `_IsChange` | Insert modunda her zaman True; Edit'te OldValue ≠ Value |
| `_GetType<T>` | Field'ı T'ye cast eder |
| `_SaveToFile(path)` | Blob/Memo içeriğini dosyaya kaydeder |
| `_LoadToFile(path)` | Dosyadan blob/memo'ya yükler |
| `_SqlStr([inc])` | Field değerini SQL uyumlu string'e çevirir |

## TDbClass

RTTI + `[TDBFieldAttr('FIELD_NAME')]` attribute'ları ile index-bazlı hızlı field cache.

```pascal
type
  TMyRow = class(TDbClass)
  public
    [TDBFieldAttr('ID')]
    property ID: Variant index 0 read GetVar write SetVar;
    [TDBFieldAttr('NAME')]
    property Name: Variant index 1 read GetVar write SetVar;
  end;
```

## JSON Motor — mORMot2

`System.JSON` tamamen kaldırıldı. JSON işlemleri:
- **Üretim**: `TJsonWriter` (streaming, sıfır nesne allocasyon)
- **Ayrıştırma**: `TDocVariantData.InitJson` + `dv.GetValueIndex`
- **Base64**: `BinToBase64` / `Base64ToBin` (`mormot.core.buffers`)
- **Tarih/Saat**: `Iso8601ToDateTime` / `AddDateTime` (`mormot.core.datetime`)
- **İç helper**: `WriteFieldJson(W, Field)` — tüm field tiplerini JSON'a yazar
- **İç helper**: `SetFieldFromJsonValue(Field, S, IsNull)` — JSON string'ten field'a yazar

## Örnek

```pascal
uses help.db;

// Fluent yazma
ds._Edit
  ._W('NAME', 'Ahmet')
  ._W('AGE', 30)
  ._W('ACTIVE', True)
  ._Post;

// JSON dışa aktarım (RawUtf8)
var raw := ds._ToJSONArrayALL;
// veya string olarak
var s := ds._ToJSONArrayALLStr;

// JSON içe aktarım
ds._FromJsonStr('[{"ID":1,"NAME":"Ali"},{"ID":2,"NAME":"Veli"}]');

// Güvenli locate
if ds._Locate('ID', 42) then
  ShowMessage(ds._S['NAME']);
```
