# qtimetypes (QDAC 3.0)
Takvimsel süre/tarih tipleri ve cron benzeri tekrarlayan zaman planı (scheduler mask).
Kaynak: `src\vendor\qdac\3.0\Source\qtimetypes.pas`

## Ne İşe Yarar
`TDateTime` üzerine üç ayrı yapı kurar:
- **`TQInterval`** — yıl/ay/gün/saat/dakika/saniye/ms bileşenli bir *süre* (interval) tipi.
- **`TQTimestamp`** — kompakt bir *tarih+saat* record'ı (BC/MÖ desteği dahil).
- **`TQPlanMask`** — tekrarlayan zaman planı (hangi saniye/dakika/saat/gün/ay/yıl/haftanın-günü kabul edilir), cron ifadesine benzer.

## Gereksinimler
`classes`, `qstring`, `sysutils`, `dateutils`, `math` (QDAC'ın kendi `qstring` birimine bağımlı).

## Temel Tipler ve Kullanım Alanları

| Tip/Fonksiyon | Ne İşe Yarar |
|---|---|
| `TQInterval` | Takvimsel süre; `TDateTime + TQInterval` operatörüyle tarihe eklenebilir |
| `TQInterval.EncodeInterval(Y,M,D,H,N,S,MS)` | Süre oluşturma (overload'larla kısmi de olabilir) |
| `TQInterval.AsISOString` / `AsSQLString` / `AsOracleString` | Süreyi string formatına çevirir |
| `TQTimestamp` | Tarih+saat değeri; `TDateTime`/`TSQLTimeStamp` ile implicit dönüşümlü |
| `TQTimestamp.IncYear/IncMonth/IncDay/...` | Takvim bileşenini artırır |
| `TQPlanMask` | Tekrarlayan zaman planı tanımı ve kontrolü |
| `TQPlanMask.Accept(ATime)` | Verilen zaman plana uyuyor mu? |
| `TQPlanMask.NextTime` | Plana uyan bir sonraki zaman |
| `TQPlanMask.Timeout(ATime)` | `pcrOk / pcrNotArrived / pcrTimeout / pcrExpired` durumunu döner |
| `IsWorkDay` (fonksiyon değişkeni) | İş günü kontrolü; `DefaultIsWorkDay` varsayılan implementasyon, override edilebilir |
| `MinInterval` / `MaxInterval` | Sınır değerler |

## Örnek

```pascal
uses qtimetypes;

var
  Aralik: TQInterval;
  Sonraki: TDateTime;
  Plan: TQPlanMask;
begin
  // 1 yıl 3 ay 10 gün'lük bir süre tanımla ve bugüne ekle
  Aralik := TQInterval.EncodeInterval(1, 3, 10, 0, 0, 0);
  Sonraki := Now + Aralik;

  // Her iş günü saat 09:00'da çalışacak bir plan
  Plan := TQPlanMask.Create('* * 9 * * 1-5'); // örnek maske söz dizimi, gerçek format için kaynağa bakılmalı
  if Plan.Accept(Now) then
    ; // planlanan zaman şu an geçerli

  case Plan.Timeout(Now) of
    pcrOk: ; // zamanında
    pcrNotArrived: ; // henüz gelmedi
    pcrTimeout: ; // zaman aşımı
    pcrExpired: ; // süresi geçmiş
  end;
end;
```

## Notlar
- `TQPlanMask.AsString` maskenin gerçek metin söz dizimini taşır; format detayları için `SetAsString`/`GetAsString` implementasyonuna bakılmalı (bu doküman sadece arayüzü özetler).
- `TQInterval` ve `TQTimestamp`, projede zaten kullanılan `mORMot2`/`help.datetime.pas` (bkz. [help.datetime.md](../../../../help.datetime.md)) ile aynı işi (takvim aritmetiği) farklı bir API ile yapar — hangisinin kullanılacağı ihtiyaca göre karar verilmeli.
