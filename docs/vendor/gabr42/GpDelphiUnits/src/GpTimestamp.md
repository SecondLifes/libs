# GpTimestamp (gabr42 / GpDelphiUnits)
Tip-güvenli, çoklu saat kaynaklı geçen-süre (elapsed time) ölçümü.
Kaynak: `src\vendor\gabr42\GpDelphiUnits\src\GpTimestamp.pas`
SHA256: `92C00209D497FA842EB60F5E396A9795BFCCE886812084118450F6A55E2365EF`
(Vendor'ın kendi ayrıntılı dokümanı: `src\vendor\gabr42\GpDelphiUnits\src\GpTimestamp.md`)

## Ne İşe Yarar
`TGpTimestamp` record'ı, bir zaman değerini **hangi saat kaynağından** (QueryPerformanceCounter,
GetTickCount, TStopwatch, TDateTime, TimeGetTime) geldiğiyle birlikte saklar. Farklı kaynaklardan
gelen değerler birbiriyle karşılaştırılır/çıkarılırsa `EInvalidOpException` fırlatır — yanlışlıkla
uyumsuz saatleri karıştırma hatasını derleme zamanında değil ama ilk çalıştırmada yakalar.
Değerler içeride nanosaniye (Int64) olarak tutulur (292 yıl aralık).

Self-contained'dır (başka GpXxx birimine bağımlı değil), bu yüzden temel altyapı projelerinde
güvenle kullanılabilir. 21 testlik hazır DUnitX suite'i (`GpTimestamp.UnitTests.pas`) mevcuttur.

## Gereksinimler
`System.SysUtils`, `System.Diagnostics`. Windows-only özellikler (`FromTickCount`,
`FromQueryPerformanceCounter`, `FromTimeGetTime`) için `Winapi.Windows` (+ `DSiWin32.pas`).

## Temel Kullanım

| Fonksiyon/Metod | Ne İşe Yarar |
|---|---|
| `TGpTimestamp.FromStopwatch` / `.Now` | Cross-platform yüksek hassasiyetli zaman damgası |
| `TGpTimestamp.FromQueryPerformanceCounter` | Windows-only yüksek hassasiyet |
| `TGpTimestamp.FromTickCount` | Windows-only, milisaniye çözünürlük |
| `TGpTimestamp.FromDateTime(dt)` | `TDateTime` tabanlı zaman damgası |
| `TGpTimestamp.Milliseconds/Seconds/Minutes/Hours(n)` | Saf süre (duration) oluşturma — her kaynakla uyumlu |
| `ts.Elapsed` | Bu zaman damgasından bu yana geçen süreyi döner |
| `ts.HasElapsed(timeout)` | Timeout doldu mu? (geçersiz zaman damgasında `True` döner — lazy init için) |
| `ts.HasRemaining(timeout)` | Deadline'a kadar süre var mı? |
| `ts.ToMilliseconds/ToSeconds/...` | Birim dönüşümü |
| `ts.AsString` | Serileştirme/deserileştirme (`"TimeSource|Value_ns"`) |

## Örnek

```pascal
uses GpTimestamp;

var
  start: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.FromStopwatch;
  DoWork;
  elapsed_ms := start.Elapsed.ToMilliseconds;  // Fluent API

  // Timeout kontrolü
  while not start.HasElapsed(TGpTimestamp.Seconds(5)) do
    ProcessMessages;
end;
```

## Notlar
- Sadece geçen süre/timeout ölçümü içindir; takvim aritmetiği (yıl/ay ekleme) veya
  timezone dönüşümü yapmaz — bunlar için [GpTimezone.md](GpTimezone.md) veya
  QDAC [qtimetypes.md](../../../qdac/3.0/Source/qtimetypes.md) referans alınabilir.
- Ayrıntılı API referansı ve tasarım gerekçeleri için vendor'ın kendi `GpTimestamp.md`
  dosyasına (kaynak dizininde, yanında) bakılabilir; bu doküman Rad Core bağlamında kısa özet niteliğindedir.
