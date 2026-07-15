# GpTimezone (gabr42 / GpDelphiUnits)
Windows zaman dilimi (timezone) bilgisi ve UTC ↔ Local dönüşümleri.
Kaynak: `src\vendor\gabr42\GpDelphiUnits\src\GpTimezone.pas`
SHA256: `7CB44AAB4E4ADF9B226B81480FCBBB62088E6FE234A1DEF3CAB6F448D3071669`

## Ne İşe Yarar
Windows registry'deki timezone tanımlarını okur/yazar (`TGpRegistryTimeZones`) ve DST
(yaz saati) kurallarını hesaba katarak local↔UTC dönüşümü yapar. 2008'den beri
güncellenmemiş, eski ama hâlâ çalışan bir Windows-only birim.

## Gereksinimler
`Windows`, `Classes`. Windows-only (registry + `TTimeZoneInformation` API'sine bağımlı).

## Temel Kullanım

| Fonksiyon/Tip | Ne İşe Yarar |
|---|---|
| `TGpRegistryTimeZones` | Registry'deki tüm timezone kayıtlarına erişim (liste, `FindByName`) |
| `TGpRegistryTimeZone` | Tek bir timezone kaydı (DisplayName, EnglishName, TimeZone) |
| `LocalTimeToUTC(loctime, preferDST)` | Geçerli (yerel) zaman dilimine göre Local → UTC |
| `UTCToLocalTime(utctime)` | UTC → Local (geçerli zaman dilimi) |
| `TZLocalTimeToUTC(TZ, loctime, preferDST)` | Belirli bir `TZ` için Local → UTC |
| `UTCToTZLocalTime(TZ, utctime)` | Belirli bir `TZ` için UTC → Local |
| `GetTZDaylightSavingInfoForYear` | Belirli yıl için DST başlangıç/bitiş tarihleri |
| `DateEQ/DateLT/DateLE/DateGT/DateGE` | 1/10 ms toleranslı `TDateTime` karşılaştırma |
| `FixDT(date)` | Float yuvarlama hatalarını düzeltir (`Trunc`/`Frac` öncesi) |
| `DayOfMonth2Date(year,month,weekInMonth,dayInWeek)` | "Ayın son pazarı" gibi tarihleri hesaplar |

## Örnek

```pascal
uses GpTimezone;

var
  tzList: TGpRegistryTimeZones;
  tz: TGpRegistryTimeZone;
  utcNow, localNow: TDateTime;
begin
  // Geçerli zaman dilimine göre dönüşüm
  utcNow := LocalTimeToUTC(Now, False);
  localNow := UTCToLocalTime(utcNow);

  // Belirli bir zaman dilimini registry'den bulup kullanma
  tzList := TGpRegistryTimeZones.Create;
  try
    tz := tzList.FindByName('Turkey Standard Time');
    if Assigned(tz) then
      localNow := UTCToTZLocalTime(tz.TimeZone, utcNow);
  finally
    tzList.Free;
  end;

  // Ayın son pazarı (ör. AB yaz saati kuralı gibi)
  var SonPazar := DayOfMonth2Date(2026, 3, 5, 1);
end;
```

## Notlar
- Geçen süre ölçümü için değil — bunun için [GpTimestamp.md](GpTimestamp.md) kullanılmalı.
- `GetTZCount`/`GetTZ` deprecated; yerine `TGpRegistryTimeZones` kullanılmalı.
