---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\rad.permission.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: c0c9ce32fca482c8c4ed2c5b0e493719836ba24531d1104d07becf7f7f8538f0
---

# rad.permission
Yetki kümesi contract'ı ve implementasyonu. `IPermission` — izin verilen yetki kodlarını `TDynArrayHashed` ile O(1) hızında tutar; DB'ye JSON array olarak yazılır/okunur.

## Gereksinimler
`mormot.core.base`, `mormot.core.data`, `mormot.core.variants`, `mormot.core.json`, `mormot.core.unicode`

## IPermission

| Metod | Açıklama |
|---|---|
| `IsExists(name)` | Yetki kümesinde var mı? (`true`/`false`) |
| `Get(name, default)` | Varsa `true`, yoksa `default` döner |
| `Add(name, value)` | `value=true` → ekle; `false` → çıkar |
| `AddOrGet(name, default)` | Yoksa `default` ile ekle ve dön; varsa `true` dön |
| `ToJson` | `'["STOK.FATURA","MRP.PLAN"]'` döner |
| `FromJson(json)` | JSON array'den yükler |
| `Clear` | Tüm izinleri temizler |

## Factory

```pascal
function NewPermission(const AJson: RawUtf8 = '[]'): IPermission;
```

## Örnek

```pascal
uses rad.permission;

var
  p: IPermission;
begin
  p := NewPermission('["STOK.FATURA","STOK.LISTE"]');

  p.IsExists('STOK.FATURA');   // True
  p.Get('MRP.PLAN');           // False
  p.Get('MRP.PLAN', True);     // True (default)

  p.Add('SATIS.SIPARIS', True);
  p.Add('STOK.LISTE', False);  // çıkar

  // DB'ye kaydet
  dbField.AsString := p.ToJson; // '["STOK.FATURA","SATIS.SIPARIS"]'

  // DB'den yükle
  p.FromJson(dbField.AsString);
end;
```

## TRadPermission (component)

`src/Components/Permission.Edit.pas` içindedir.

| Field | Açıklama |
|---|---|
| `FTree: RawUtf8` | Tüm yetki tanımları — DFM'e yazılır, design-time edit |
| `FData: IPermission` | İzin verilenler — DB'den yüklenir, runtime erişim |

| Metod | Açıklama |
|---|---|
| `Edit` | Ancestor yoksa tree düzenlenir; ancestor varsa sadece görüntülenir (`csAncestor`) |
| `Show` | Her zaman salt-okunur görüntüler |
| `Data` | `IPermission` erişimi |
