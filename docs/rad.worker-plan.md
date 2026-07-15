# rad.worker.pas — Mimari Tasarım Planı

**Durum:** Planlama (kod yok, test yok, kaynak dosya değişikliği yok — bu doküman
tek başına planın kaydıdır). Tüm bulgular OmniThreadLibrary ve mORMot2'nin
**gerçek kaynak kodu** okunarak çıkarıldı (2026-07-05, Opus destekli Plan
agent ile). Amaç: QDAC'ın `QWorker.pas`'ından (src\vendor\qdac\3.0\Source\)
API ergonomisi ilham alınarak, bu projenin çekirdeği olacak bir
worker/job-zamanlama framework'ü (`rad.worker.pas`) tasarlamak — QWorker'ın
iç mimarisi KOPYALANMAYACAK, mevcut vendor (mORMot2) altyapısı üstüne
kurulacak.

---

## 0. Araştırmadan Çıkan Kritik Bağlam (karar öncesi)

1. **mORMot2 bu projede zaten canlı threading altyapısı.** `src/core/rad.thread.pas`
   (`TRadTask`) tamamen mORMot2 üstüne kurulu: `TThread.CreateAnonymousThread`,
   `TSynLog`, `TLightLock`, `TDocVariantData`, `mormot.core.os` (doğrulandı:
   `rad.thread.pas` satır 42-47 `mormot.core.base/os/data/variants/json/log`
   kullanıyor). mORMot2 hâlihazırda derlenen, kullanılan, ekibin idiomlarına
   aşina olduğu bir bağımlılık.

2. **OmniThreadLibrary projede henüz hiçbir yerde tüketilmiyor.** OTL'ye
   (`OtlParallel`, `OtlThreadPool`, `GlobalOmniThreadPool` vb.) referans veren
   tek yerler `src/vendor/exilon/QuickLib` içindeki alakasız üçüncü-parti
   demo `.dproj`'leri. Projenin kendi `packages/` veya `core/` klasöründe OTL
   kullanımı sıfır. OTL vendor'lanmış ama build'e bağlanmamış durumda.

   > Not: Primoz Gabrijelcic'in **GpDelphiUnits**'i (GpStuff, GpTimestamp,
   > GpTimezone, GpString) projede canlı kullanılıyor (`rad.date.pas`,
   > `help.date.pas`, `help.str.pas`, `rad.utils.pas`). Ama bunlar OTL
   > değil — OTL'nin ayrı, çok daha ağır bir bağımlılık grafiği (OtlCommon,
   > OtlTaskControl, OtlParallel, OtlSync, hepsi zincirleme) getiren bağımsız
   > bir kütüphanesi.

3. **`TDtSchedule` (rad.date.pas) hazır ve `NextTime`/`Accept`/`Timeout`
   API'si zaten var, test edilmiş, performansı optimize edilmiş** (gün-bazlı
   fast-forward — bkz. `docs/help.date.md` ve bu oturumun geçmişi: bir kez
   yılda-bir-eşleşen cron için 3.3sn'den ~0ms'ye indirildi). Cron mantığı
   `rad.worker` için sıfırdan yazılmayacak, doğrudan tüketilecek.

---

## 1. Motor Kararı: **mORMot2** (net tercih, hedge değil)

**Karar: `rad.worker.pas` mORMot2 (`mormot.core.threads` + `mormot.core.os`)
üstüne kurulacak. OmniThreadLibrary kullanılmayacak.**

### 1.1 QWorker özellik listesinin her maddesi mORMot2'de zaten var

| QWorker özelliği | mORMot2 karşılığı (kaynakta doğrulandı) |
|---|---|
| `Post` (tek-atış dispatch) | `TSynThreadPool.Push` (IOCP tabanlı sabit havuz) veya `TLoggedWorker.Run` |
| `LongtimeJob` (uzun işe ayrı thread) | `TLoggedWorkThread` — uzun iş için ayrı, kendini yöneten thread (`FreeOnTerminate`) |
| Dinamik havuz (Min/MaxWorkers) | `TLoggedWorker` — `MaxRunning`/`Running`, ihtiyaca göre thread yaratıp bırakan havuz |
| `Post(AInterval)` / `At` / `Delay(repeat)` | `TSynBackgroundTimer.Enable(proc, secs)` + `EnQueue`/`ExecuteNow`/`ExecuteOnce` |
| `Plan` (cron) | `TSynBackgroundThreadProcess` (keyfi `aOnProcessMS` tick + `ProcessEvent.SetEvent` ile event-driven uyandırma) → tick içinde `TDtSchedule.NextTime` |
| Parallel-For (`TQForJobs.&For`) | `TSynParallelProcess.ParallelRunAndWait(method, count, OnMainThreadIdle)` — built-in UI-idle callback |
| `WaitJob`/`Signal`/`SendSignal` (async→sync köprü) | `TBlockingProcess` (semafor: WaitFor/NotifyFinished, timeout'lu) + `TBlockingProcessPool` |
| `FireTimeout`/`OnJobFrozen` (watchdog) | `TSynMonitor` istatistikleri + `TLoggedThread.Processing`/`WaitFinished(timeout)`; kendi tick-watchdog'umuz kolayca kurulur |
| Per-worker extension (DB bağlantısı vb.) | `TLoggedThread`'in before/after-execute hook'ları + thread-context kaynak yönetimi |
| İstatistik (Runs/Min/Max/TotalUsedTime) | `TSynMonitor` (mormot.core.perf) |
| `BeforeExecute`/`AfterExecute`/`OnError` | `TOnNotifyThread` hook'ları her sınıfta mevcut |

OTL de bunların çoğunu karşılıyor (`IOmniThreadPool`, `Parallel.For/ForEach/Async/Future`)
— kapsam yeterli. Karar "kapsam" üzerinden değil, aşağıdaki eksenlerle verildi.

### 1.2 Kararın gerçek eksenleri

**(a) Tip evreni tutarlılığı — belirleyici faktör.** Çekirdek (`rad.thread`,
`rad.cache`, `rad.eventbus`, `rad.utils`) zaten mORMot2 tip evreninde:
`RawUtf8`, `TDocVariantData`/`IDocDict`, `TSynLog`, `TLightLock`. mORMot2
seçmek, `rad.worker`'ın payload'unu bu evrenin bir parçasıyla (`IDocDict` —
bkz. 2.1) taşımasını, loglamayı `TSynLog` ile yapmasını sağlar — hepsi
`mormot.core.variants`/`mormot.core.log`'un aynı ailesi. OTL seçmek paralel
bir tip evreni (`TOmniValue`, `IOmniCancellationToken`, `IOmniTask`) sokar;
sınırlarda sürekli dönüşüm gerektirir.

**(b) Bağımlılık ağırlığı.** mORMot2 zaten derleniyor — sıfır yeni bağımlılık.
OTL'yi devreye almak `OtlCommon/OtlSync/OtlTaskControl/OtlThreadPool/
OtlParallel/OtlComm/OtlContainers/OtlHooks` zincirini (~1MB kaynak) build'e
sokmak demek — çekirdek birim için kalıcı bakım yükü.

**(c) GUI/VCL mesaj-pompası deseni projede kanıtlanmış.** `TSynParallelProcess.
ParallelRunAndWait`'in `OnMainThreadIdle` parametresi + `TBlockingProcess.
WaitFor(timeout)` + VCL `CheckSynchronize` deseni; `rad.thread.pas`'ın `Wait`
metodu (satır 526-530) bu deseni zaten kullanıyor.

**(d) Bakım/olgunluk.** İkisi de aktif, ama mORMot2 README'de zaten "birincil
performans vendor'ı" ilan edilmiş.

### 1.3 OTL'nin tek gerçek avantajı ve neden belirleyici değil

`IOmniThreadPool` API şekli olarak QWorker'a en yakın tek parça (`MinWorkers`,
`MaxExecuting`, `MaxQueuedTime_sec` — frozen-job watchdog'a hazır karşılık,
`Cancel(taskID)`, `SetThreadDataFactory` — per-worker extension'a hazır
karşılık). Ama `rad.worker` QWorker'ın iç mimarisini değil API ergonomisini
kopyalıyor; OTL'nin "hazır kutu" olması (a)+(b)+(c)'deki kalıcı entegrasyon
maliyetini geçersiz kılmıyor. Watchdog gibi OTL'de hazır olan birkaç şeyi
mORMot üstünde ~30-40 satırla kendimiz kuracağız (Faz 2).

**Sonuç: mORMot2.**

---

## 2. Faz 1 — Çekirdek (somut, uygulanabilir)

### 2.1 Job tipi: `TJob` — record (class değil)

QWorker'ın `TQJob`'u da record — milyonlarca kısa iş için heap/GC baskısı
olmamalı; `TDtElapsed`/`TDtInterval` precedent'iyle uyumlu.

**Payload: `IDocDict`, `TDocVariantData` DEĞİL.** QWorker'ın 6+ ownership modu
(object/record/interface/custom×6) bu proje için over-engineering — tek payload
tipi yeterli. `mormot.core.variants.pas` (satır 3523+) incelendi:
`IDocDict` bir **interface** (referans sayılı, otomatik ömür yönetimi),
Python-dict tarzı `Get`/`Set`/`Exists`/`Del`/`Pop`/`Reduce`/`Sort` API'siyle
ve **`.Copy` metoduyla** (job `Post()` edilirken payload'un bağımsız bir
kopyasını almak için — üretici thread sonradan veriyi değiştirse bile job'u
etkilemez) geliyor. `TJob`'un anonim `Proc`/`DataProc` alanları thread'ler
arası taşınacağı (closure capture) için, ham bir `TDocVariantData` record'una
göre `IDocDict`'in interface/refcount semantiği daha güvenli. Tek fark:
`rad.thread.TRadTask.FData` hâlâ ham `TDocVariantData` (`AddOrUpdateValue`/
`GetValueOrDefault`) — yani `rad.worker` ile `rad.thread` arasında payload
tipi birebir aynı değil, ama ikisi de aynı `mormot.core.variants` ailesinden.
Ham `Pointer`+free-callback interop yolu opsiyonel ikinci yol olarak
kalabilir, varsayılan değil.

```pascal
type
  TRadWorkerJobId = type Int64;

  TRadWorkerProc     = reference to procedure;
  TRadWorkerDataProc = reference to procedure(const AData: IDocDict);
  TRadWorkerJobFlag  = (wjRunOnce, wjMainThread, wjLongRunning,
                        wjByPlan, wjRepeat, wjTerminated);
  TRadWorkerJobFlags = set of TRadWorkerJobFlag;

  TJob = record
    Id         : TRadWorkerJobId;
    Name       : RawUtf8;
    Proc       : TRadWorkerProc;
    DataProc   : TRadWorkerDataProc;
    Data       : IDocDict;
    Flags      : TRadWorkerJobFlags;
    PushTixMs, StartTixMs, DoneTixMs : Int64;
    IntervalMs : Int64;
    DelayMs    : Int64;
    Schedule   : TDtSchedule;          // wjByPlan ise dolu (rad.date reuse)
    Runs       : Integer;
    MinUsedMs, MaxUsedMs, TotalUsedMs : Int64;
  end;
  PJob = ^TJob;
```

### 2.2 Havuz yöneticisi: `TRadWorkers` (singleton `Workers`)

QWorker'ın `var Workers: TQWorkers` deseniyle birebir: global varsayılan
havuz + isteğe bağlı özel örnekler.

**Motor eşlemesi:**

| rad.worker API | Altta yatan mORMot2 primitifi |
|---|---|
| `Workers.Post(proc)` | `TSynThreadPool.Push` (sabit IOCP havuz, kısa iş) |
| `Workers.LongJob(proc)` | `TLoggedWorkThread.Create(...)` |
| `Workers.Delay(proc, ms)` | `TSynBackgroundTimer.ExecuteOnce` |
| `Workers.Every(proc, ms)` | `TSynBackgroundTimer.Enable` + `EnQueue` |
| `Workers.Plan(proc, mask)` | Cron scheduler tick (bkz. 2.4) |
| `Workers.ForEach(lo, hi, proc)` | `TSynParallelProcess.ParallelRunAndWait` |
| `Workers.WaitJob(id, timeout)` | `TBlockingProcessPool.NewProcess` + `NotifyFinished` |
| `MinWorkers`/`MaxWorkers`/`Busy`/`Idle` | `TLoggedWorker.MaxRunning`/`Running` |
| `DisableWorkers`/`EnableWorkers` | kendi katmanımızda pause bayrağı |

> **Tasarım notu:** İki havuz mekanizmasını (`TSynThreadPool` sabit +
> `TLoggedWorker` dinamik) birleştirmek yerine, başlangıçta **tek motor:
> `TLoggedWorker`** öneriliyor (runtime'da thread yaratıp bırakması QWorker'ın
> dinamizmine en yakın, `TSynLog` entegrasyonu hazır). `TSynThreadPool`
> yalnızca ölçüm "çok-yüksek-frekans kısa iş" darboğazı gösterirse ikinci
> motor olarak eklenir (açık soru #3).

### 2.3 Public API iskeleti

```pascal
TRadWorkers = class
public
  function Post(const AProc: TRadWorkerProc): TRadWorkerJobId; overload;
  function Post(const AProc: TRadWorkerDataProc;
                const AData: IDocDict): TRadWorkerJobId; overload;
  function PostMainThread(const AProc: TRadWorkerProc): TRadWorkerJobId;

  function Delay(const AProc: TRadWorkerProc; ADelayMs: Int64): TRadWorkerJobId;
  function Every(const AProc: TRadWorkerProc; AIntervalMs: Int64;
                 AFirstDelayMs: Int64 = 0): TRadWorkerJobId;

  function Plan(const AProc: TRadWorkerProc;
                const AMask: string): TRadWorkerJobId; overload;
  function Plan(const AProc: TRadWorkerProc;
                const ASchedule: TDtSchedule): TRadWorkerJobId; overload;

  function LongJob(const AProc: TRadWorkerProc): TRadWorkerJobId;

  procedure ForEach(ALow, AHigh: Integer;
                    const ABody: TProc<Integer, Integer>;
                    AMsgWait: Boolean = False);

  function  Cancel(AId: TRadWorkerJobId): Boolean;
  procedure Clear;
  function  WaitJob(AId: TRadWorkerJobId; ATimeoutMs: Integer;
                    AMsgWait: Boolean = False): Boolean;

  procedure Disable;
  procedure Enable;
  property MinWorkers : Integer read ... write ...;
  property MaxWorkers : Integer read ... write ...;
  property BusyWorkers: Integer read ...;
  property IdleWorkers: Integer read ...;
  /// True ise her worker thread'i başlamadan CoInitializeEx, bitince
  /// CoUninitialize çağrılır (UniDAC/ADO gibi COM tabanlı DB sürücüleri
  /// worker içinde kullanılacaksa gerekir) — bkz. 2.6.
  property ComInitPerWorker: Boolean read ... write ...;
end;

var
  Workers: TRadWorkers;
```

### 2.4 Plan (cron) — TDtSchedule reuse, motor = tick-loop

- `TSynBackgroundThreadProcess` ile bir "scheduler tick" thread'i (ör.
  `aOnProcessMS = 1000`, yeni plan eklenince `ProcessEvent.SetEvent` ile
  event-driven uyandırma da açık).
- Her tick'te, kayıtlı her plan-job için `Job.Schedule.NextTime(LLastFire)`
  ≤ `Now` ise → job'u **normal havuza `Post`** et (tick thread'i işi kendi
  yapmaz, sadece tetikler → uzun iş scheduler'ı bloklamaz).
- `TDtSchedule.NextTime`'ın gün-gün fast-forward optimizasyonu sayesinde her
  tick maliyeti ~0ms (yılda-bir cron'da bile). Cron mantığı sıfır satır
  yeniden yazılmadan reuse edilir.

### 2.5 Parallel-For

`Workers.ForEach(lo, hi, body, AMsgWait)` → doğrudan `TSynParallelProcess.
ParallelRunAndWait(method, count, OnMainThreadIdle)`. `AMsgWait=True` ise
`OnMainThreadIdle` = VCL mesaj pompası callback'i (UI donmaz). mORMot'ta
built-in, glue kodu minimal.

### 2.6 COM Apartment Init per-Worker (Faz 1'e alındı)

QWorker'ın `ComNeeded` özelliğinin dar kapsamlı karşılığı — genel amaçlı
"per-worker extension object" (Faz 2'de kalan `TQWorkerExt` karşılığı) ile
KARIŞTIRILMAMALI, bu sadece COM apartment init/uninit:

- `Workers.ComInitPerWorker := True` ise `TLoggedWorker`'ın before-task
  hook'unda `CoInitializeEx(nil, COINIT_APARTMENTTHREADED)`, after-task
  (worker sonlanırken) hook'unda `CoUninitialize` çağrılır.
- Varsayılan `False` — sadece worker içinde UniDAC/ADO gibi COM tabanlı bir
  DB sürücüsü kullanılacaksa açılır.
- Genel per-worker extension mekanizması (thread-local DB connection nesnesi
  gibi rastgele bir "ekstra" nesne tutma) hâlâ Faz 2'de; bu madde sadece COM
  apartment'ın kendisiyle sınırlı.

---

## 3. Faz 2 — İleri Özellikler (mimari eskiz)

| Özellik | Yaklaşım / mORMot primitifi |
|---|---|
| **Signal pub-sub** | **KARAR (bkz. madde 5.2): ayrı registry YOK, `rad.eventbus.pas`'a delege.** `Workers.Wait(proc, channel)` = `EventBus.Subscribe(channel, proc-that-Posts)`. `SendSignal`-tarzı senkron bekleme gerekiyorsa `TBlockingProcess.WaitFor(timeout)` ile eventbus handler'ının üstüne ince bir bekleme katmanı eklenir — ama registry'nin kendisi eventbus'ın. |
| **WaitGroup (`TRadWorkerGroup`)** | Job kümesi + `TInterlocked.Decrement(remaining)` sayacı + `TBlockingProcess`/`TSynEvent` ile toplu bekleme. `rad.thread.pas`'taki `WhenAll` deseninin (satır 596-623) havuz-tabanlı genelleştirmesi. |
| **Frozen-job watchdog** | Scheduler tick içinde: çalışan her job için `Now - StartTixMs > FrozenThreshold` ise `OnJobFrozen` tetikle. mORMot'ta hazır değil ama ~30-40 satır. |
| **Per-worker extension** (thread-local DB conn) | `TLoggedWorker.OnBeforeEachTask`/`OnAfterEachTask` + thread-context kaynak yönetimi. |
| **Dinamik havuz resize** | `TLoggedWorker.MaxRunning` runtime yazılabilir + kuyruk uzunluğu ölçülüp otomatik ayar; `TSynMonitor` ile izleme. |
| **İstatistik/introspection** | Job record snapshot'ı + `TSynMonitor` sayaçları; `TDocVariantData` olarak dışa ver. |

---

## 4. Dosya Yapısı: **Tek dosya `rad.worker.pas`** (başlangıçta)

**Gerekçe:** `rad.date.pas` dört ayrı record'u (`TDtElapsed`/`TDtInterval`/
`TDtTimeZone`/`TDtSchedule`) tek dosyada tutuyor — precedent tutarlılığı.
`TJob`+`TRadWorkers`+`TRadWorkerGroup` sıkı bağlı; ayırmak yapay
sınırlar yaratır. Tek `uses` yüzeyi: `mormot.core.threads, mormot.core.os,
mormot.core.variants, mormot.core.log, rad.date`.

**Ne zaman bölünür:** Faz 2'de Signal + WaitGroup dosyayı ~2000 satırın
üstüne çıkarırsa `rad.worker.signal.pas`/`rad.worker.group.pas` olarak
ayrılabilir — ölçülen ihtiyaç doğunca, şimdiden değil.

**`rad.worker` ↔ `rad.thread` ilişkisi:** Çakışmıyor, katmanlı:
- `rad.thread.TRadTask` = tek, zengin, fluent, UI-odaklı iş (Before/ThenBy/
  OnSuccess/Retry/Progress) — her seferinde yeni thread.
- `rad.worker.Workers` = havuz-tabanlı, yüksek-hacim, zamanlanmış işler
  (Post/Plan/Every/ForEach) — paylaşımlı worker thread'leri.
- İleride `TRadTask.Start` opsiyonel olarak `Workers` havuzuna post edebilir
  (açık soru #5).

---

## 5. Kararlar (kullanıcı yetkiyi bıraktı, aşağıda çözüldü — 2026-07-05)

1. **Payload modeli: sadece `IDocDict`** (2026-07-05'te `TDocVariantData`'dan
   değiştirildi — bkz. 2.1: interface/otomatik ömür yönetimi + `.Copy` +
   zengin Get/Set/Pop API, closure-capture için daha güvenli). QWorker'ın 6
   ownership modundan (object/record/interface/custom×6) hiçbiri Faz 1'e
   girmiyor — gerçek bir kullanım senaryosu yok, YAGNI. Ham `Pointer`+free-callback yolu
   da Faz 1'de YOK; gerçek bir interop ihtiyacı (ör. C API'sinden gelen bir
   handle) doğarsa ayrıca eklenir.

2. **Signal sistemi: ayrı bir registry KURULMAYACAK, `rad.eventbus.pas`'a
   delege edilecek.** `rad.eventbus.pas`'ın interface'i incelendi — zaten
   olgun bir channel-tabanlı pub-sub (`Subscribe`/`IChannelSubscription`,
   `TChannelDelivery`, `NormalizeChannel`/`GetMatchingSubscriptions` ile
   wildcard eşleşme, senkron/asenkron/main-thread teslimat modları) var.
   `Workers.Wait(AProc, AChannel: string)` içeride
   `EventBus.Subscribe(AChannel, proc-that-does-Workers.Post(AProc))` olarak
   uygulanacak — QWorker'ın `RegisterSignal`/`Signal`/`SendSignal`/`PostSignal`
   ailesi TEKRAR yazılmayacak, sadece "kanalı dinle, tetiklenince havuza
   post et" ince bir köprü olacak.

3. **Motor: TEK `TLoggedWorker` ile başla.** `TSynThreadPool` (sabit IOCP)
   sadece ölçülmüş bir "çok-yüksek-frekans kısa iş" darboğazı çıkarsa Faz 2+
   içinde eklenir — baştan hibrit kurulmayacak.

4. **Dosya yapısı: TEK `rad.worker.pas`, Faz 1 VE Faz 2 boyunca.** Signal
   artık ayrı bir alt-sistem olmadığı (madde 2) için dosyanın büyüme riski
   zaten azaldı; sadece gerçekten ~2000 satırı aşarsa (ölçülünce, tahminen
   değil) bölünür.

5. **`rad.thread` ↔ `rad.worker`: ayrı, katmanlı kalacak.** `TRadTask.Start`'ın
   opsiyonel olarak `Workers` havuzuna post etmesi ayrı bir Faz 3+ kararı —
   Faz 1/2'yi bloklamıyor.

6. **`TDtSchedule` by-value kopyalama:** İmplementasyon sırasında doğrulanacak
   bir kontrol maddesi (risk düşük — `SetAsString` her seferinde `FLimits`'i
   baştan kurduğu için partial-mutation riski yok), ayrı bir mimari karar
   değil.

7. **COM apartment init per-worker: Faz 1'e alındı** (bkz. 2.6) —
   `Workers.ComInitPerWorker: Boolean`, `TLoggedWorker`'ın before/after-task
   hook'unda `CoInitializeEx`/`CoUninitialize`. Genel per-worker extension
   object mekanizması (rastgele nesne tutma) hâlâ Faz 2'de; sadece COM
   apartment'ın kendisi Faz 1'e taşındı.

---

## Uygulama İçin Kritik Dosyalar

- `src\vendor\synopse\mORMot2\src\core\mormot.core.threads.pas` — motor
  primitifleri (`TLoggedWorker`, `TSynParallelProcess`, `TSynBackgroundTimer`,
  `TSynBackgroundThreadProcess`, `TBlockingProcess`/`TBlockingProcessPool`,
  `TSynThreadPool`)
- `src\core\rad.date.pas` — `TDtSchedule` (cron reuse), `TDtElapsed`
- `src\core\rad.thread.pas` — kardeş katman + tip-evreni deseni
  (TDocVariantData payload, TSynLog, IRadCancelToken, VCL mesaj-pompası
  `Wait` deseni, satır 526-530 ve 596-623)
- `src\packages\RadKon.dpk` — yeni `rad.worker.pas` buraya eklenecek
- `src\vendor\qdac\3.0\Source\QWorker old.pas` — API ergonomi referansı
  (temiz yorumlu sürüm — mevcut `QWorker.pas`'ın Çince yorumları bozuk/
  mojibake; sadece imza/ergonomi için kullanılmalı, iç mimari için değil)

---

*Bu plan 2026-07-05'te, kullanıcının isteği üzerine Opus destekli bir Plan
agent'ın OmniThreadLibrary ve mORMot2 kaynak kodunu gerçekten okuyarak yaptığı
karşılaştırmalı analize dayanır. Uygulamaya geçmeden önce yukarıdaki 7 açık
soru gözden geçirilip karara bağlanmalı.*
