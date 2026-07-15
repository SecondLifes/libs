# ESBPCSCalendarClasses (ESBPCS for VCL)
Dini/ulusal takvim sistemi (Hristiyan/Musevi/ulusal yıl sınıfları).
Kaynak (proje dışı): `E:\system\dev\01-Component\2026.6.6\ESBPCS(TM) for VCL v6.15.1\source\ESBPCSCalendarClasses.pas`
SHA256: `8B3809E8B1CB0FFA2307F28BFA7730A75818C4B825F5F494A47955190CDA68F4`

> **Not**: Ham dosya okunmadı (4453 satır) — `reuse-finder` MCP aracının
> indekslediği yapılandırılmış veri (`code_index`, 140 benzersiz isim)
> üzerinden analiz edildi. (2026-07-15 güncellemesi: `reuse-finder` tool'u
> projeden kaldırıldı — bu doküman o dönemki kısmi/dolaylı analize dayanıyor,
> dosyanın tamamı henüz ham okunmadı.)

## Ne İşe Yarar
`TESBChristianYear`, `TESBJewishYear`, `TESBNationalYear`, `TESBYear` gibi
sınıflarla Paskalya, Pesah, Yom Kippur, Hanukkah, Advent, Ash Wednesday,
Good Friday gibi dini/ulusal bayram tarihlerini hesaplayan kapsamlı bir
takvim sistemi.

## Gereksinimler
Bilinmiyor (ham dosya okunmadı).

## Temel Kullanım

| Sınıf/Fonksiyon | Ne İşe Yarar |
|---|---|
| `TESBChristianYear.EasterSunday`/`.ChristmasDay`/`.GoodFriday`/`.Pentecost` | Hristiyan takvimi bayramları |
| `TESBJewishYear.Passover`/`.YomKippur`/`.RoshHashanah`/`.Hanukkah`/`.Purim` | Musevi takvimi bayramları |
| `TESBNationalYear.IndependenceDayUS`/`.ThanksgivingDayUS`/`.CanadaDay`/`.AustraliaDay` | Ülkeye özgü resmi tatiller |

## Örnek

```pascal
uses ESBPCSCalendarClasses;

var
  Yil: TESBChristianYear;
begin
  Yil := TESBChristianYear.Create;
  try
    Yil.SetYear(2026);
    ShowMessage(DateToStr(Yil.EasterSundayAsDateTime));
  finally
    Yil.Free;
  end;
end;
```

## Kapsam Dışı — help.date.pas'a HİÇBİR ŞEY ALINMADI
Bu dosyanın tamamı (140 bildirim) dini/ulusal takvime özgü — genel amaçlı,
Türkçe bir `TDateTime` helper'ı için aşırı kültüre/dine özgü içerik. Böyle bir
ihtiyaç gerçekten doğarsa, `TDateTime` helper'ının bir parçası değil, AYRI bir
"tatil takvimi" modülü olarak ele alınmalı.
