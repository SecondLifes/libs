# Quick.Commons (QuickLib — exilon)
Genel amaçlı yardımcı fonksiyonlar; içinde hazır bir `TDateTimeHelper` var.
Kaynak: `src\vendor\exilon\QuickLib\Quick.Commons.pas`
SHA256: `F76E2103C74E2EA106CA420BF39B504112613E9B186C51EF1F3D870E02145BB9`

## Ne İşe Yarar
Dosya/path/string/log yardımcılarının yanında, **modern bir `record helper for
TDateTime` (+ `TDate`/`TTime` helper'ları) örneği** içeriyor — `help.date.pas`
tasarımı için doğrudan karşılaştırma referansı oldu.

## Gereksinimler
`Classes`, `SysUtils`, `Types`, platforma göre `Windows`/`IOUtils` vb.

## Temel Kullanım (DateTime ile ilgili kısım)

| Fonksiyon/Metot | Ne İşe Yarar |
|---|---|
| `TDateTimeHelper.IncDay/IncMonth/IncYear(aValue=1)` / `Dec*` | Varsayılan parametreli ekleme/çıkarma |
| `TDateTimeHelper.IsEqualTo/IsAfter/IsBefore` | Fluent karşılaştırma |
| `TDateTimeHelper.IsSameDay/IsSameTime` | Aynı gün/saat mi kontrolü |
| `TDateTimeHelper.ToUTC`/`FromUTC(aUTCTime)` | Timezone dönüşümü |
| `TDateTimeHelper.Date`/`Time` | Tarih/saat bileşenini ayıklama |
| `ChangeTimeOfADay(date, h, n, s, ms=0)` | Tarihi koruyup SADECE saati değiştirir |
| `ChangeDateOfADay(date, y, m, d)` | Saati koruyup SADECE tarihi değiştirir |
| `DateTimeToJsonDate`/`JsonDateToDateTime` | JSON/ISO-8601 tarih dönüşümü |
| `IsSameDay(date1, date2)` | İki tarihin aynı gün olup olmadığı |

## Örnek

```pascal
uses Quick.Commons;

var
  Randevu: TDateTime;
begin
  Randevu := Now.ChangeTimeOfADay(Now, 9, 0, 0); // bugünün tarihi, saat 09:00
  if Randevu.IsAfter(Now) then
    ; // henüz gelmedi
end;
```

## Notlar
- `help.date.pas`'ın `_ChangeDate`/`_ChangeTime` metotları doğrudan bu dosyadaki
  `ChangeDateOfADay`/`ChangeTimeOfADay` fikrinden alındı — daha önce hiç
  düşünülmemişti, bu dosya sayesinde eklendi.
- `IsEqualTo`/`IsAfter`/`IsBefore` isimlendirmesi yerine `help.date.pas`'ta
  GpTimezone kökenli `_DateEQ`/`_DateGT`/`_DateLT` (1/10ms toleranslı) tercih
  edildi — aynı işi görüyorlar, tek bir isimlendirme ailesi seçildi.
