# help.datetime
mORMot2 datetime tipleri üzerinden Unix/TimeLog/ISO8601 dönüşümleri ve iş günü/dönem hesapları.

## Gereksinimler
`mormot.core.base`, `mormot.core.datetime`

## Yeniden Dışa Aktarılan Tipler
Bu unit'i kullanan birimler `TUnixTime`, `TTimeLog`, `TSynSystemTime` tiplerine doğrudan erişir.

## Dönüşüm Fonksiyonları

| Fonksiyon | Açıklama |
|---|---|
| `NowUnix` | Şimdiki zamanı `TUnixTime` (Int64, epoch saniye) olarak döner |
| `NowLog` | Şimdiki zamanı `TTimeLog` (40-bit kompakt) olarak döner |
| `ToUnix(dt)` | `TDateTime → TUnixTime` |
| `FromUnix(unix)` | `TUnixTime → TDateTime` |
| `ToLog(dt)` | `TDateTime → TTimeLog` |
| `FromLog(log)` | `TTimeLog → TDateTime` |
| `ToISO8601(dt)` | `TDateTime → 'YYYY-MM-DDTHH:MM:SS'` string |

## İş Günü / Dönem Fonksiyonları

| Fonksiyon | Döner |
|---|---|
| `StartOfDay(dt)` | Günün 00:00:00 |
| `EndOfDay(dt)` | Günün 23:59:59 |
| `StartOfMonth(dt)` | Ayın ilk günü 00:00:00 |
| `EndOfMonth(dt)` | Ayın son günü 23:59:59 |
| `StartOfYear(dt)` | Yılın ilk günü |
| `EndOfYear(dt)` | Yılın son günü |
| `StartOfQuarter(dt)` | Çeyreğin ilk günü |
| `EndOfQuarter(dt)` | Çeyreğin son günü |
| `IsWeekend(dt)` | Cumartesi veya Pazar mı? |
| `Quarter(dt)` | 1–4 arası çeyrek numarası |

## Örnek

```pascal
uses help.datetime;

var
  Unix  : TUnixTime;
  Logged: TTimeLog;
begin
  Unix   := NowUnix;
  Logged := NowLog;

  // Ay başı / sonu
  var AyBasi := StartOfMonth(Now);
  var AySonu := EndOfMonth(Now);

  // ISO string
  ShowMessage(ToISO8601(Now)); // '2026-06-25T14:30:00'

  // Çeyrek
  var Q := Quarter(Now);  // 2  (Nisan–Haziran)
end;
```
