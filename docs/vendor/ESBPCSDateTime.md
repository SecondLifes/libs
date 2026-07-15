# ESBPCSDateTime (ESBPCS for VCL)
Devasa (369 bildirim) bir tarih/saat fonksiyon kütüphanesi.
Kaynak (proje dışı): `E:\system\dev\01-Component\2026.6.6\ESBPCS(TM) for VCL v6.15.1\source\ESBPCSDateTime.pas`
SHA256: `2B6C2ACD464A5850FB1EED88554381A584F0C47CF22A7439593A775490BD4251`

> **Not**: Bu dosya çok büyük (~14000 satır, 8364 satırlık interface). Ham
> dosya okunmadı — zaten `reuse-finder` MCP aracıyla indekslenmiş yapılandırılmış
> veri (`code_index`) üzerinden analiz edildi. Bu doküman SADECE `help.date.pas`
> için değerlendirilen/kullanılan alt kümeyi kapsar, 369 bildirimin tamamını değil.
> (2026-07-15 güncellemesi: `reuse-finder` tool'u projeden kaldırıldı — bu
> doküman o dönemki kısmi/dolaylı analize dayanıyor, dosyanın tamamı henüz
> ham okunmadı.)

## Ne İşe Yarar
Aynı yazar ailesinden (ESB Consultancy — `GpTimezone.pas` ile akraba) gelen,
son derece kapsamlı bir tarih/saat kütüphanesi: yaş hesabı, iş günü ailesi,
ISO hafta, DOW numaralandırma çevirileri ve çok sayıda niş özellik (gezegen
yılı dönüşümleri, ülkeye özgü tatil hesapları, astroloji) içeriyor.

## Gereksinimler
Bilinmiyor (ham dosya okunmadı) — muhtemelen `SysUtils`, Windows API.

## Temel Kullanım (help.date.pas için değerlendirilen alt küme)

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `AgeAtDate`/`AgeNow`/`AgeAtDateInMonths`/`AgeNowInWeeks`/`CurrentBirthday`/`LastBirthday`/`DesiredBirthday` | Yaş hesabı ailesi |
| `CountWorkingDays`/`NextWorkingDay`/`PrevWorkingDay`/`WeekDaysInMonth` | İş günü ailesi |
| `ESBToday`/`ESBTomorrow`/`ESBYesterday` | Bugün/yarın/dün kısayolları |
| `StartOfWeek`/`EndOfWeek`/`StartOfISOWeek`/`EndOfISOWeek`/`WeeksApart` | Hafta sınırları ve farkı |
| `DaysLeftInMonth`/`DaysLeftInYear` | Kalan gün sayısı |
| `DOW2ISODOW`/`ISODOW2DOW` (ve ESB varyantları) | Farklı gün-numarası konvansiyonları arası çeviri |

## Örnek

```pascal
uses ESBPCSDateTime;

var
  Yas: Integer;
  BirSonrakiIsGunu: TDateTime;
begin
  Yas := AgeAtDate(EncodeDate(1990,5,15), Now);
  BirSonrakiIsGunu := NextWorkingDay(Now);
end;
```

## Kapsam Dışı Bırakılanlar (nedenle)
- Gezegen/sidereal yıl dönüşümleri (`Days2JupiterYears` vb.) — astronomi, iş
  mantığıyla ilgisi yok.
- Ülkeye özgü tatil hesapları (`GetIndependenceDayUS`, `GetThanksgivingDayCan`,
  `GetAustraliaDay` vb.) — ABD/Avustralya/Kanada'ya özgü, genel bir Türkçe
  framework'e uymuyor.
- `IsJanuary`.."IsDecember", `IsMonday`.."IsSunday" (19 ayrı fonksiyon) —
  `help.date.pas`'ın zaten sağladığı `_Month`/`_DayOfWeek` ile trivial şekilde
  karşılanıyor, ayrı metotlara gerek yok.
- `Date2StarSign` — astroloji.
