# JvDateUtil (Project JEDI VCL — JVCL)
Tarih/saat yardımcı fonksiyonları — göreli ay navigasyonu, Inc-ailesi, takvimsel fark.
Kaynak: `src\vendor\project-jedi\jvcl\jvcl\archive\JvDateUtil.pas`
SHA256: `7DEB955338BE071059993FBECBFCF9E3040B2022872712571351BAFC37BEAAF4`

> **Not**: Bu dosya JVCL'in kendi `archive\` klasöründe — JVCL içinde muhtemelen
> artık kullanılmayan/eskimiş sayılıyor. İçerik yine de değerli fikirler barındırıyor.

## Ne İşe Yarar
Göreli ay/gün navigasyonu (geçen/gelecek ay), kapsamlı `Inc*` ailesi (gün/ay/yıl/saat/
dakika/saniye ekleme), takvimsel Gün/Ay/Yıl farkı hesabı ve locale-aware string
parse fonksiyonları sağlar.

## Gereksinimler
`SysUtils`, `Classes`.

## Temel Kullanım

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `FirstDayOfPrevMonth`/`LastDayOfPrevMonth`/`FirstDayOfNextMonth` | Göreli ay navigasyonu |
| `IncDate(date, days, months, years)` | Tek çağrıda gün+ay+yıl ekleme |
| `IncDay`/`IncMonth`/`IncYear`/`IncHour`/`IncMinute`/`IncSecond`/`IncMSec` | Tekil Inc ailesi |
| `DateDiff(date1, date2, var days, months, years)` | Takvimsel (Gün/Ay/Yıl) fark |
| `MonthsBetween`/`DaysBetween`/`DaysInPeriod` | RTL'in kendi eşdeğerleriyle örtüşüyor |
| `CutTime(date)` | Saati 00:00:00'a sıfırlar |
| `ValidDate(date)` | Tarihin geçerliliğini kontrol eder |
| `StrToDateFmt(format, s)` | Belirli bir format string'ine göre metinden tarih parse eder |

## Örnek

```pascal
uses JvDateUtil;

var
  GecenAyIlkGun: TDateTime;
  Gun, Ay, Yil: Word;
begin
  GecenAyIlkGun := FirstDayOfPrevMonth;
  DateDiff(Now, EncodeDate(2020,1,1), Gun, Ay, Yil);
end;
```

## Notlar
- `help.date.pas`'ın `_IncDay`/`_IncMonth`/`_IncYear` (varsayılan parametre=1 ile)
  ve `_ChangeDate`/`_ChangeTime` fikirleri kısmen bu dosyadan (ve `Quick.Commons`'tan)
  esinlenildi.
- `MonthsBetween`/`DaysBetween`/`CutTime` zaten RTL/`help.date.pas`'ta karşılığı
  olduğu için ayrıca alınmadı.
- `GetDateOrder`/`MonthFromName`/`StrToDateFmt`/`DefDateFormat`/`FormatLongDate`
  gibi locale-format fonksiyonları, modern RTL `TFormatSettings` desteği
  tarafından karşılandığı için `help.date.pas`'a alınmadı.
