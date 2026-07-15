# kbmMWDateTime (kbmMW Enterprise Edition)
Sofistike, kendi iç temsiline sahip bir DateTime/Duration tip sistemi.
Kaynak (proje dışı): `E:\system\dev\01-Component\2026.6.6\kbmMW Enterprise Edition 5.19\Source\kbmMWDateTime.pas`
SHA256: `68E7FF19BA60FB48BE2589AC97BC23C9E5BA5D5FE2948E73D70F0DEC979C28A1`

> **Not**: Ham dosya okunmadı (7078 satır) — `reuse-finder` MCP aracının
> indekslediği yapılandırılmış veri (`code_index`, 167 benzersiz isim)
> üzerinden analiz edildi. (2026-07-15 güncellemesi: `reuse-finder` tool'u
> projeden kaldırıldı — bu doküman o dönemki kısmi/dolaylı analize dayanıyor,
> dosyanın tamamı henüz ham okunmadı.)

## Ne İşe Yarar
`TkbmMWDateTime`/`TkbmMWDuration` gibi kendi kayıt tiplerini tanımlayan,
ISO8601/RFC1123/NCSA/VAX-timestamp/temporenc gibi birçok formatı destekleyen,
"Fixed" (timezone değişiminden etkilenmeyen) ile "Floating" (timezone
değişimiyle kayan) zaman kavramlarını ayıran sofistike bir tarih/saat alt
sistemi.

## Gereksinimler
Bilinmiyor (ham dosya okunmadı, kbmMW framework'üne bağımlı).

## Temel Kullanım

| Fonksiyon/Kavram | Ne İşe Yarar |
|---|---|
| `GetComparativeHours`/`Minutes`/`MSecs`/`Secs` | Göreli zaman farkı ("X saat önce" tarzı metinler için yapı taşı) |
| `GetISO8601String`/`SetISO8601String` (+ Date/Time/Duration/TimeZone varyantları) | Ayrıştırılmış ISO-8601 bileşenleri |
| Fixed vs Floating UTC/Local ayrımı | "Sabit" zamanlar timezone değişse de kaymaz, "değişken" zamanlar kayar — ileri seviye bir kavram |
| `GetRFC1123DateTime`/`GetNCSADateTime` | HTTP/log formatları |
| `IsNull`/`Null` | Nullable-datetime kavramı (kendi tipi için) |

## Örnek

```pascal
uses kbmMWDateTime;

var
  DT: TkbmMWDateTime;
begin
  DT.SetISO8601DateTime('2026-07-04T12:00:00Z');
  ShowMessage(DT.GetLocalAsFormat('dd.mm.yyyy'));
end;
```

## Kapsam Dışı Bırakılanlar (nedenle)
- RFC1123/NCSA formatları — `help.date.pas`'ta zaten `_ToHttpDate`/`_ToNcsaText`
  ile karşılanıyor.
- Temporenc, VAX timestamp — aşırı niş/eski formatlar.
- `IsNull`/`Null` kavramı — plain `TDateTime` doğal olarak "null" durumunu
  temsil edemez, bu ayrı bir "nullable DateTime" tipi gerektirir; `help.date.pas`
  kapsamı dışında (ileride ayrı bir tip/helper olarak ele alınabilir).

## İlham Aldığımız Nokta
`help.date.pas`'ın `_ToRelativeString` metodu ("X saat önce" tarzı göreli
zaman metni), bu dosyanın `GetComparativeHours/Minutes/MSecs/Secs` fikrinden
esinlenildi (ama kbmMW'nin kendi tipine değil, doğrudan `TDateTime`'a).
