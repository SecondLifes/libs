# MiTeC_Datetime (MiTeC Common Routines)
Kapsamlı tarih/saat yardımcıları — iş günü ailesi, işaretli-fark fonksiyonları,
timezone-by-name dönüşümü.
Kaynak (proje dışı): `E:\system\dev\01-Component\2026.6.6\MiTeC_SICS_FS_16.0.0\Common\MiTeC_Datetime.pas`
SHA256: `50612C3C48DE1AEE51374524E07A9640C8285009FB8CED437C1B1B9C48E01C1A`

## Ne İşe Yarar
Zengin bir tarih/saat yardımcı fonksiyon koleksiyonu: iş günü bazlı aritmetik,
RTL'in aksine YÖN KORUYAN (işaretli, negatif olabilen) fark fonksiyonları,
isimli timezone dönüşümü, XML tarih parse. Ayrıca zodyak/burç hesaplamaları
içeriyor (iş mantığıyla ilgisiz, kapsam dışı bırakıldı).

## Gereksinimler
`Windows`, `SysUtils`, `Classes`.

## Temel Kullanım (datetime-ilgili kısım)

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `IncWorkDays(dt, days)` / `DecWorkDays` | Hafta sonlarını atlayarak iş günü ekleme/çıkarma |
| `GetWorkDays(dt, count)` | Belirli sayıda iş günü sonrasının hesabı |
| `SecondsBetweenSgn`/`MinutesBetweenSgn`/`HoursBetweenSgn`/`DaysBetweenSgn`/`WeeksBetweenSgn` | RTL'in `SecondsBetween` ailesinden FARKLI: yön koruyan (negatif olabilen) fark |
| `IsDateInRange`/`IsTimeInRange`/`IsDateTimeInRange` | Aralık kontrolü |
| `XMLStrToDateTime`/`XMLTryStrToDateTime` | XML'e özgü tarih metni parse |
| `GetTimeZoneList`/`GetTimeZone(keyName, out data, year)`/`LocalDateTimeToTZ` | İsimli (registry tabanlı) timezone dönüşümü — mORMot2 `TSynTimeZone` ile örtüşüyor |
| `EasterSunday(year)` | Paskalya hesabı (JclDateTime'daki ile aynı fikir, bağımsız implementasyon) |

## Örnek

```pascal
uses MiTeC_Datetime;

var
  SonrakiIsGunu: TDateTime;
  Fark: Integer;
begin
  SonrakiIsGunu := IncWorkDays(Now, 3); // 3 iş günü sonrası (hafta sonu atlanır)
  Fark := DaysBetweenSgn(EncodeDate(2026,1,1), Now); // yön korunur (negatif olabilir)
end;
```

## Notlar
- `help.date.pas`'ın `_IncWorkDays`/`_NextWorkingDay`/`_PrevWorkingDay`/
  `_CountWorkingDays` metotları bu dosyadaki iş-günü fikrinden esinlenildi.
- İsimli timezone dönüşümü zaten mORMot2'nin `TSynTimeZone`'u (cross-platform,
  thread-safe) ile karşılandığı için bu dosyanın registry mantığı ayrıca
  alınmadı (bkz. proje planı, "Pillar C" kararı).
- Zodyak/burç kısmı (`TZodiac`, `TZodiacSign` vb.) tamamen kapsam dışı.
