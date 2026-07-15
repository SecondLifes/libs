---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\rad.json.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: de090292925626b7d75a8651d2f0bfce0dcdd603d0143045f7917d28816b7cf0
---

# rad.json + rad.json.mormot
`IJson` (JSON nesne) ve `IJsonArray` (JSON dizi) contract tanımları.
`rad.json.mormot.pas` mORMot2 `IDocDict` / `IDocList` ile implementasyonu sağlar.

## Gereksinimler
Sadece standart RTL — provider bağımlılığı yoktur.

## IJson — JSON Nesnesi

| Metod / Property | Açıklama |
|---|---|
| `Len / IsEmpty` | Eleman sayısı / boş mu? |
| `Exists(key)` | Key var mı? |
| `Keys` | Tüm key'leri `TArray<string>` döner |
| `S[key]` | string okur/yazar |
| `I[key]` | Int64 okur/yazar |
| `F[key]` | Double okur/yazar |
| `B[key]` | Boolean okur/yazar |
| `C[key]` | Currency okur/yazar |
| `O[key]` | İç içe IJson okur/yazar |
| `A[key]` | İç içe IJsonArray okur/yazar |
| `GetDef(key, default)` | Key yoksa default döner, exception yok |
| `Del(key)` | Key'i siler |
| `Clear` | Tümünü siler |
| `ToJson` | `'{"key":val,...}'` string döner |
| `FromJson(json)` | JSON string'ten yükler |

## IJsonArray — JSON Dizisi

| Metod / Property | Açıklama |
|---|---|
| `Len / IsEmpty` | Eleman sayısı / boş mu? |
| `S/I/F/B/C/O/A[idx]` | Index bazlı tip-güvenli okuma |
| `Add(value)` | string/Int64/Double/Boolean/Currency ekler |
| `AddObj(IJson)` | İç içe nesne ekler |
| `AddArr(IJsonArray)` | İç içe dizi ekler |
| `IndexOf(value)` | İlk eşleşmenin index'ini döner |
| `Exists(value)` | Değer var mı? |
| `Del(idx)` | Index'teki elemanı siler |
| `Pop([idx])` | Eleman çıkarır ve döner (varsayılan son) |
| `Clear` | Tümünü siler |
| `ToJson` | `'[...]'` string döner |
| `FromJson(json)` | JSON string'ten yükler |

## Factory

`rad.json.mormot` birimi `initialization`'da `JsonFactory` / `JsonArrayFactory`'yi otomatik atar.
uses listesine eklemek yeterli:

## Örnek

```pascal
uses rad.json, rad.json.mormot;

var
  obj: IJson;
  arr: IJsonArray;
begin
  obj := NewJson;
  obj.S['name'] := 'Ahmet';
  obj.I['age']  := 30;
  obj.B['active'] := True;

  arr := NewJsonArray;
  arr.Add('elma');
  arr.Add('armut');
  obj.A['fruits'] := arr;

  ShowMessage(obj.ToJson);
  // {"name":"Ahmet","age":30,"active":true,"fruits":["elma","armut"]}

  // Okuma
  var ad := obj.GetDef('name', 'Bilinmiyor');
  var yas := obj.I['age'];
end;
```

## mORMot2 Eşlemesi

| Framework | mORMot2 |
|---|---|
| `IJson` | `IDocDict` |
| `IJsonArray` | `IDocList` |
| `NewJson` | `DocDict(...)` |
| `NewJsonArray` | `DocList(...)` |
| `O[key]` | `D[key]` |
| `A[key]` | `L[key]` |
