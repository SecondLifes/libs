# help.date — TDateTime Helper
`TDateTime` (+ `TDate`/`TTime`) için genel amaçlı, `_` önekli metotlarla
donatılmış `record helper`. Kaynak: `src\core\help.date.pas`.

> Kaynaklar ve tasarım kararları için bkz. `docs\vendor\...` altındaki ilgili
> dokümanlar (mormot.core.datetime, mormot.core.search, GpTimestamp, GpTimezone,
> JclDateTime, JvDateUtil, Quick.Commons, MiTeC_Datetime, ESBPCSDateTime,
> ESBPCSCalendarClasses, kbmMWDateTime, Tee.FastDateTime).

## ISO-8601

| Metot | Örnek |
|---|---|
| `_ToISO8601` | `Now._ToISO8601` → `'2026-07-04T12:00:00'` |
| `_ToISO8601MS` | `Now._ToISO8601MS` → milisaniyeli |
| `_ToISO8601Short` | `Now._ToISO8601Short` → tahsissiz (allocation-free) varyant |
| `_ToISO8601Date` | `Now._ToISO8601Date` → `'2026-07-04'` |
| `_ToISO8601Time` | `Now._ToISO8601Time` → `'T12:00:00'` |
| `TDateTime._FromISO8601(s)` | `D := TDateTime._FromISO8601('2026-07-04T12:00:00');` |
| `TDateTime._FromISO8601Date(s)` | Sadece tarih kısmını parse eder |
| `TDateTime._FromISO8601Time(s)` | Sadece saat kısmını parse eder |

## Unix / TTimeLog

```pascal
var U: TUnixTime; L: TTimeLog;
U := Now._ToUnix;
L := Now._ToLog;
D := TDateTime._FromUnix(U);
D := TDateTime._FromLog(L);
```

## Bileşen Erişimi

```pascal
ShowMessage(Format('%d/%d/%d %d:%d:%d, hafta günü %d, yılın %d. günü',
  [Now._Day, Now._Month, Now._Year, Now._Hour, Now._Minute, Now._Second,
   Now._DayOfWeek, Now._DayOfYear]));
ShowMessage(Format('Çeyrek %d, Yarıyıl %d, %d gün var bu ayda',
  [Now._Quarter, Now._Semester, Now._DaysInMonth]));
```

## Dönem Sınırları

```pascal
var AyBasi := Now._StartOfMonth;
var AySonu := Now._EndOfMonth;
var HaftaBasi := Now._StartOfWeek;
var CeyrekSonu := Now._EndOfQuarter;
if Now._IsWeekend then ShowMessage('Hafta sonu');
```

## ISO-8601 Hafta Numarası

```pascal
var Hafta := Now._ISOWeekNumber; // gerçek ISO hafta no (yıl sınırı kurallarını doğru işler)
if Now._IsISOLongYear then ; // 53 haftalık yıl mı
var Pazartesi := TDateTime._FromISOWeek(2026, 27, 1); // 2026'nın 27. haftasının pazartesisi
```

## Karşılaştırma (1/10ms toleranslı)

```pascal
if D1._DateEQ(D2) then ;
if D1._DateGT(D2) then ;
var GunSayisi := D1._DaysBetween(D2);
var AySayisi := D1._MonthsBetween(D2);
```

## Ekleme/Çıkarma

```pascal
var YarinAyniSaat := Now._IncDay;       // varsayılan +1
var GecenAy := Now._IncMonth(-1);
var Saat9 := Now._ChangeTime(9, 0, 0);  // tarihi koru, saati 09:00 yap
var YeniTarih := Now._ChangeDate(2027, 1, 1); // saati koru, tarihi değiştir
```

## Timezone (mORMot2 TSynTimeZone tabanlı)

```pascal
var Utc := Now._ToUtc;                              // yerel makine
var IstanbulUtc := Now._ToUtc('Turkey Standard Time'); // keyfi isimli TZ
var Yerel := TDateTime._FromUtc(Utc, 'Turkey Standard Time');
var Bias := Now._GetTZBias('Turkey Standard Time');  // dakika cinsinden UTC offset
ShowMessage(Now._DaylightSavingInfo('Turkey Standard Time'));
```

## Format / Metin

```pascal
ShowMessage(Now._Format('dd.mm.yyyy hh:nn'));
ShowMessage(Now._ToHttpDate);        // 'Tue, 15 Nov 1994 12:45:26 GMT' tarzı
ShowMessage(Now._ToRelativeString);  // '3 saat önce'
var D := TDateTime._Today;
```

## İş Günü

```pascal
if Now._IsWorkingDay then ;
var Sonraki := Now._NextWorkingDay;
var UcIsGunuSonra := Now._IncWorkDays(3);
var KacIsGunu := D1._CountWorkingDays(D2);
```

## Yaş

```pascal
var DogumTarihi := EncodeDate(1990, 5, 15);
var Yas := DogumTarihi._Age; // tam yıl, doğum günü henüz gelmediyse düşer
```

## "Ayın N'inci X Günü"

```pascal
var SonPazar := TDateTime._DayOfMonth2Date(2026, 12, 5, 1); // rad.utils.pas'a referans
var UcuncuCuma := TDateTime._IndexedWeekDay(2026, 3, 3);
```

## Win32 Interop (dosya zaman damgaları)

```pascal
var FT := Now._ToFileTime;
var D2 := TDateTime._FromFileTime(FT);
var TS := Now._ToTimeStamp; // Delphi'nin kendi TTimeStamp tipi
```

## Riskli — Gerçek Sistemi Değiştirir

```pascal
// DİKKAT: gerçek işletim sistemi saatini/saat dilimini değiştirir!
Now._SetOperatingSystemDateTime;
TDateTime._SetOperatingSystemTimeZone('Turkey Standard Time');
```

## Notlar
- `_DayOfMonth2Date`, kendi implementasyonunu içermez — `rad.utils.pas`'taki
  aynı isimli fonksiyona ince bir sarmalayıcıdır (kod tekrarı yok).
- Timezone metotları mORMot2'nin `TSynTimeZone`'una dayanır — Windows registry
  veya cross-platform bir kaynaktan (resource/dosya) okur.
- Bu doküman tüm ~100 metodu değil, kategori başına temsili örnekleri kapsar;
  tam metot listesi için `help.date.pas`'ın `interface` bölümüne bakılabilir.
