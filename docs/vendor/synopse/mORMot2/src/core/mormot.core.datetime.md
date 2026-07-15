# mormot.core.datetime (Synopse mORMot2 core)
Düşük seviye tarih/saat desteği: boyut/süre metne çevirme, ISO-8601 kodlama,
yüksek seviyeli tarih/saat record'ları (`TSynDate`/`TSynSystemTime`), Unix
epoch tabanlı 64-bit zaman damgaları ve `TTimeLog` kompakt kodlaması.
Kaynak: `src\vendor\synopse\mORMot2\src\core\mormot.core.datetime.pas`
SHA256: `18C9DD994DC93F31FC24B41C5766231E81FCC1518E332D80E3A954D1BBFAE52D`

## Ne İşe Yarar
mORMot2'nin tüm framework birimlerinin paylaştığı tarih/saat altyapısı. RTL'in
`SysUtils`/`DateUtils`'ine göre çok daha hızlı (pointer-tabanlı, tahsissiz)
alternatifler sunar: `TryEncodeDate`/`EncodeDateTime` gibi kendi hızlı
sürümleri, ISO-8601 parse/format fonksiyonları, ve iki farklı kompakt
zaman-damgası tipi (`TUnixTime`/`TTimeLog`).

## Gereksinimler
`sysutils`, `classes`, `mormot.core.base`, `mormot.core.os`,
`mormot.core.os.security`, `mormot.core.unicode`, `mormot.core.text`.

## TSynDate — Sadece Tarih (Yıl/Ay/Gün)
`TDate` gibi ara hesaplama gerektirmeden Year/Month/Day/DayOfWeek alanlarını
doğrudan tutan hafif bir record. `FromNow`/`FromDate` ile doldurulur,
`Compare`/`IsEqual` ile karşılaştırılır, `ToText` ile ISO-8601 metne çevrilir.

```pascal
uses mormot.core.datetime;

var
  D: TSynDate;
begin
  D.FromNow(false); // UTC bugünün tarihi
  D.ComputeDayOfWeek;
  ShowMessage(D.ToText); // '2026-07-04'
end;
```

## TSynSystemTime — Tam Tarih+Saat (Y/M/D/H/N/S/MS)
`TSynDate`'in tüm alanlarına ek olarak Hour/Minute/Second/MilliSecond taşır.
`FromNowUtc`/`FromNowLocal` 16ms'lik thread-safe bir cache kullanarak çok
hızlı çalışır. ISO-8601, HTTP-date (RFC 7231), NCSA/Apache log formatı ve
insan-okunur metin (`ToHuman`) gibi birçok çıktı formatına doğrudan
dönüştürülebilir.

```pascal
uses mormot.core.datetime;

var
  ST: TSynSystemTime;
  Txt: RawUtf8;
begin
  ST.FromNowUtc;
  ST.ToHttpDate(Txt); // 'Sat, 04 Jul 2026 12:00:00 GMT'
  ShowMessage(ST.ToText(true)); // '2026-07-04T12:00:00'
end;
```

## TTimeLogBits / TTimeLog — 64-bit Bit-Paketli Tarih+Saat
`TTimeLog` (Int64), Seconds(6bit)/Minutes(6bit)/Hours(5bit)/Day-1(5bit)/
Month-1(4bit)/Year(12bit) olarak bit düzeyinde paketlenmiş kompakt bir
zaman damgasıdır — JSON'da güvenle 52-bit mantissa'ya sığar. `TTimeLogBits`
bu değere doğrudan erişim sağlayan wrapper'dır. `TimeLogNow`/`TimeLogNowUtc`
gibi serbest fonksiyonlarla üretilip/tüketilir.

```pascal
uses mormot.core.datetime;

var
  TL: TTimeLog;
  DT: TDateTime;
begin
  TL := TimeLogNowUtc;              // şu an, TTimeLog olarak
  DT := TimeLogToDateTime(TL);      // TDateTime'a geri çevir
  ShowMessage(PTimeLogBits(@TL)^.Text(true)); // ISO-8601 metin
end;
```

## TUnixTime / TUnixMSTime — POSIX Epoch 64-bit Zaman Damgaları
Unix epoch'tan (1970-01-01) itibaren saniye (`TUnixTime`) veya milisaniye
(`TUnixMSTime`) cinsinden 64-bit zaman damgaları. `DateTimeToUnixTime`/
`UnixTimeToDateTime` ile `TDateTime`'a dönüştürülür; `UNIXTIME_MINIMAL`
sabiti sayesinde 32-bit "Year 2038" taşma sorunu yaşanmaz.

```pascal
uses mormot.core.datetime;

var
  U: TUnixTime;
begin
  U := DateTimeToUnixTime(Now);
  ShowMessage(UnixTimeToString(U)); // ISO-8601 metin
end;
```

## ISO-8601 Metin Dönüşümü
`Iso8601ToDateTime`/`DateTimeToIso8601Text` çifti, RTL'in kendi ISO ayrıştırma
fonksiyonlarından çok daha hızlı, pointer-tabanlı (tahsissiz) çalışır.

```pascal
uses mormot.core.datetime;

var
  DT: TDateTime;
  S: RawUtf8;
begin
  DT := Iso8601ToDateTime('2026-07-04T12:30:00');
  S := DateTimeToIso8601Text(DT); // 'YYYY-MM-DDThh:mm:ss'
end;
```

## Boyut/Süre → Okunabilir Metin
`SecToString`/`MilliSecToString`/`MicroSecToString`/`NanoSecToString`,
geçen bir süreyi (elapsed time) "1.234s", "123.456ms" gibi insan-okunur
metne çevirir — kendi Format mantığını yazmaya gerek bırakmaz.

```pascal
uses mormot.core.datetime;

begin
  ShowMessage(MilliSecToString(1500)); // '1.50s'
end;
```

## Notlar
- `TValuePUtf8Char` bu dosyada tanımlı olsa da tarih/saat ile ilgisiz — genel
  bir JSON metin-değer wrapper'ıdır, bu doküman kapsamında değerlendirilmedi.
- Keyfi isimli (Windows TzId, ör. "Turkey Standard Time") timezone dönüşümü
  bu dosyada DEĞİL, `mormot.core.search.pas`'taki `TSynTimeZone` sınıfında —
  bkz. [mormot.core.search.md](../mormot.core.search.md).
- Bu birim, projenin henüz yazılmamış `help.datetime.pas`'ının (bkz.
  `docs\help.datetime.md`) doğrudan temel taşı olarak kullanılması planlanıyor.
