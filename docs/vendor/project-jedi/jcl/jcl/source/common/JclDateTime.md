# JclDateTime (Project JEDI Code Library — JCL)
Kapsamlı tarih/saat dönüşüm ve hesaplama fonksiyonları.
Kaynak: `src\vendor\project-jedi\jcl\jcl\source\common\JclDateTime.pas`
SHA256: `0D890A20364F66867C75754F17491B16CAB315ED3903DB5D4B965F03C111CC76`

## Ne İşe Yarar
`TDateTime`/`TDosDateTime`/`TFileTime`/`TSystemTime` arasında kapsamlı dönüşümler,
gerçek ISO-8601 hafta numarası hesaplama, hafta-içi/hafta-sonu günü bulma ve
takvimsel bileşen erişimi sağlayan, JEDI ekibinin uzun süredir bakımını yaptığı
bir birim.

## Gereksinimler
`System.SysUtils`, Windows'ta `Winapi.Windows`.

## Temel Kullanım

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `DayOfTheYear(dt)` / `DayOfTheYearToDateTime(year, day)` | Yılın kaçıncı günü + tersi |
| `ISOWeekNumber(dt)` / `ISOWeekToDateTime(year, week, day)` | Gerçek ISO-8601 hafta numarası (basit gün-sayımından farklı, yıl sınırı kurallarını doğru işler) + tersi |
| `IsISOLongYear(dt)` | Yılın 53 haftalık (uzun) ISO yılı olup olmadığı |
| `EasterSunday(year)` | Paskalya tarihi hesabı |
| `FirstWeekDay`/`LastWeekDay`/`IndexedWeekDay` | Bir ayın ilk/son/N'inci hafta-içi günü |
| `FirstWeekendDay`/`LastWeekendDay`/`IndexedWeekendDay` | Aynısı hafta sonu için |
| `DateTimeToFileTime`/`FileTimeToDateTime` | `TDateTime` ↔ Win32 `TFileTime` |
| `DateTimeToSystemTime`/`SystemTimeToDateTime`(RTL'de de var) | `TDateTime` ↔ `TSystemTime` |
| `DateTimeToDosDateTime`/`DosDateTimeToDateTime` | `TDateTime` ↔ DOS tarih formatı |

## Örnek

```pascal
uses JclDateTime;

var
  Hafta: Integer;
  Paskalya: TDateTime;
begin
  Hafta := ISOWeekNumber(Now); // ör. 27
  Paskalya := EasterSunday(2026);
end;
```

## Notlar
- `help.date.pas`'ın `_ISOWeekNumber`/`_FromISOWeek`/`_IsISOLongYear` metotları bu
  birimden ilham alındı (standart algoritma yeniden yazıldı, birebir kopyalanmadı).
- Gezegen/sidereal yıl dönüşümleri ve tatil hesapları (US/AU'ya özgü) bu dosyada
  YOK — bu dosya sade ve genel amaçlı; o tür kapsamlı ek özellikler için
  `ESBPCSDateTime.md`'ye bakılabilir.
