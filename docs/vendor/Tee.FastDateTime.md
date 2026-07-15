# Tee.FastDateTime (David Berneda)
Performans odaklı, dar kapsamlı TDateTime bileşen çıkarma fonksiyonları.
Kaynak (proje dışı): `C:\Users\SecondLife\Downloads\FastDateTime-master\FastDateTime-master\Tee.FastDateTime.pas`
SHA256: `4707AF1840962357CA822BA56F1745CECCE57063C0CEC47286CA1AC60190D5DF`

## Ne İşe Yarar
`TFastDateTime` adında, sadece 4 işlem sunan çok dar bir `record` — ama platform
bazlı (32/64-bit) lookup-table optimizasyonlarıyla `DayOf`/`MonthOf`/`YearOf`/
`DayOfTheYear` hesaplarını RTL'in `DecodeDate`'inden daha hızlı yapıyor.

## Gereksinimler
`System.SysUtils` (veya FPC'de `SysUtils`).

## Temel Kullanım

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `TFastDateTime.DayOf(dt)` | Ayın günü (hızlı) |
| `TFastDateTime.MonthOf(dt)` | Ay (hızlı) |
| `TFastDateTime.YearOf(dt)` | Yıl (hızlı) |
| `TFastDateTime.DayOfTheYear(dt)` | Yılın kaçıncı günü (hızlı) |

## Örnek

```pascal
uses Tee.FastDateTime;

var
  Gun: Word;
begin
  Gun := TFastDateTime.DayOf(Now);
end;
```

## Notlar
- `help.date.pas`'ın `_Day`/`_Month`/`_Year`/`_DayOfYear` metotları şimdilik
  standart `DecodeDate`/`DayOfTheYear` (RTL) kullanıyor — bu dosyanın
  optimizasyon tekniği (lookup table), performans testleri gerçekten
  darboğaz gösterirse ileride bu implementasyona geçirilebilir.
- Fonksiyonel olarak yeni bir yetenek eklemiyor, sadece hız optimizasyonu.
