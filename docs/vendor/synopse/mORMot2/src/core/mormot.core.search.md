# mormot.core.search — TSynTimeZone Bölümü (Synopse mORMot2 core)
Kaynak: `src\vendor\synopse\mORMot2\src\core\mormot.core.search.pas`
SHA256: `27B4413F0F4814D4BEEEF84C911BD32C5DE0DD50470AA82A09DFE8780A18295C` (tüm dosya)
(satır 1852-2043, `{ ***** Cross-Platform TSynTimeZone Time Zones }` region'ı)

> Not: `mormot.core.search.pas` genel olarak arama/eşleştirme (Boyer-Moore,
> IP/e-posta doğrulama vb.) sağlayan geniş bir birimdir. Bu doküman SADECE
> DateTime bileşeni tasarımı sırasında incelenen `TSynTimeZone` bölümünü
> kapsar — dosyanın tamamının analizi değildir.

## Ne İşe Yarar
`TSynTimeZone`, Windows registry'sinden (veya cross-platform bir sıkıştırılmış
dosya/resource'tan) okunan, isimle (Windows `TzId`, ör. `'Turkey Standard
Time'`) erişilen bir timezone veritabanıdır. Windows dışı platformlarda da
(Linux/POSIX) önceden Windows'ta üretilip gömülen bir kaynak/dosya üzerinden
çalışabilir — yani **cross-platform, keyfi-isimli timezone dönüşümü** sağlar;
`GpTimezone.pas`'ın registry-tabanlı `TGpRegistryTimeZone(s)` ile çözmeye
çalıştığı problemin doğrudan (ve daha modern) karşılığıdır.

## Temel Tipler ve Kullanım

| Tip/Fonksiyon | Ne İşe Yarar |
|---|---|
| `TSynTimeZone` (class) | Thread-safe (`TObjectRWLightLock` miras alır) timezone veritabanı; `Create`/`Destroy`, `LoadFromRegistry` (Windows), `LoadFromFile`/`LoadFromBuffer`/`LoadFromResource` (cross-platform) |
| `TSynTimeZone.Default` | Lazy-init edilen, paylaşılan global singleton (`SharedSynTimeZone`) — genelde doğrudan bu kullanılır |
| `LocalToUtc(ALocalDateTime, ATzId)` | Belirtilen `TzId`'ye göre yerel zamanı UTC'ye çevirir |
| `UtcToLocal(AUtcDateTime, ATzId)` | UTC'yi belirtilen `TzId`'ye göre yerel zamana çevirir |
| `NowToLocal(ATzId)` | Şu anki UTC zamanını belirtilen `TzId`'ye göre döner |
| `GetBiasForDateTime(AValue, ATzId, out ABias, out AHaveDaylight)` | Belirli bir tarih için dakika cinsinden UTC offset + o an DST aktif mi bilgisini döner |
| `GetDisplay(ATzId)` | `TzId`'nin kullanıcıya gösterilecek adını döner (ör. '(UTC+03:00) Istanbul') |
| `Ids` / `Displays` | Tüm `TzId`/görünen-ad listesini `TStrings` olarak döner — UI'da seçim listesi doldurmak için |
| `ChangeOperatingSystemTimeZone(ATzId)` | (Windows-only) İşletim sisteminin timezone ayarını değiştirir |
| `GetBiasForDateTime`/`GetDisplay`/`UtcToLocal`/`NowToLocal`/`LocalToUtc` (serbest fonksiyonlar) | `TSynTimeZone.Default` üzerinden çalışan, sınıf instance'ı almadan kullanılabilen kısayollar |

## Örnek

```pascal
uses mormot.core.search;

var
  Utc, Local: TDateTime;
  Bias: integer;
  Dst: boolean;
begin
  // Belirli bir timezone'a göre dönüşüm (yerel makinenin ayarından bağımsız)
  Local := TSynTimeZone.Default.NowToLocal('Turkey Standard Time');
  Utc := TSynTimeZone.Default.LocalToUtc(Local, 'Turkey Standard Time');

  if TSynTimeZone.Default.GetBiasForDateTime(Now, 'Romance Standard Time', Bias, Dst) then
    ShowMessage(Format('Offset: %d dakika, DST: %s', [Bias, BoolToStr(Dst, true)]));

  // UI'da timezone seçim listesi doldurma
  ComboBox1.Items := TSynTimeZone.Default.Displays;
end;
```

## Notlar
- Windows dışı platformlarda `LoadFromRegistry` yoktur; mORMot2 deposu Linux
  için hazır bir `{$R mormot.tz.res}` kaynağı sağlıyor (bu proje Windows-only
  VCL olduğu için pratikte `LoadFromRegistry`/`TSynTimeZone.Default` yeterli).
- `TSynTimeZone`, `TSynSystemTime`i (bkz. [mormot.core.datetime.md](mormot.core.datetime.md))
  hem parametre hem iç veri yapısı olarak kullanır (`TTimeZoneInfo.change_time_std/_dlt`).
- Bu keşif, Rad Core DateTime bileşeni tasarımında GpTimezone'un registry
  portunun düşürülüp bunun yerine `TSynTimeZone` üzerine ince bir sarmalayıcı
  (`TDtTimeZone`) yazılması kararını doğurdu (bkz. proje planı).
