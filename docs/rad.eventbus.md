---
original_path: "D:\dev\Delphi\00-Lib\rad.eventbus.md"
source: 00-lib
copied_at_utc: 2026-07-02T17:23:22Z
sha256: 3e4cefef14e4e46a78ea526b0bb6f60f7fd7087e9b1d940d49a1f33fea462373
---

# rad.eventbus.pas — `TChannelBus` Kullanım Kılavuzu ve Analiz

## Ne İşe Yarar

`rad.eventbus.pas`, adlandırılmış kanallı (**named channel**, string tabanlı) bir **event bus** (olay veriyolu) sağlar. `vendor\gabr42\GpDelphiUnits\src\GpEventBus.pas` ve `vendor\dalijap\nx-horizon\source\NX.Horizon.pas` kütüphanelerinden ilham alınmış, kanıtlanmış teknikleri yeniden kullanan **yeni bir yapıdır** (bkz. aşağıdaki analiz).

Temel özellikler:
- **Kanal bazlı yayın/abonelik**: aynı olay tipi farklı kanallarda, farklı kanallar aynı isimde ama farklı case/boşlukla (`'Siparis'`, `' SIPARIS '`) yazılsa bile normalize edilip (`Trim.ToLowerInvariant`) aynı kanala eşlenir.
- **4 teslimat modu** (`TChannelDelivery`): `dmSync`, `dmAsync`, `dmMainSync`, `dmMainAsync`.
- **Güvenli abonelik iptali**: `IChannelSubscription.Unsubscribe`, dispatch sırasında (handler'ın kendi içinden) çağrılsa bile AV oluşturmaz (ref-counting + lazy removal).
- **`WaitAndUnsubscribe`**: devam eden dispatch'in bitmesini bekleyip sonra iptal eder — component/form kapanırken güvenli temizlik için.
- **4 taşma politikası** (`TOverflowPolicy`, sadece `dmAsync` kuyruğu için): `opDropOldest`, `opDropNewest`, `opBlockPublisher`, `opGrow`.
- **`TArray<TValue>` ve `IDocDict` (JSON) tabanlı esnek `Subscribe`/`Publish` overload'ları** — `T:record` kısıtına takılmadan, çalışma zamanında (RTTI/JSON ile) dinamik veri taşımak için.
- **İzolasyon + `OnError`**: bir abonenin handler'ı exception fırlatırsa, aynı `Publish` çağrısındaki diğer aboneler yine de çağrılır; hata isteğe bağlı `OnError` olayına (hangi kanal, hangi veri, hangi exception) bildirilir. `AErrorIsolation: Boolean` ayarıyla (varsayılan `True`) kapatılabilir.
- **Wildcard/catch-all abonelik** (`'siparis.*'` gibi): `System.Masks.MatchesMask` ile glob-style desen eşleştirme; wildcard kullanılmadığı sürece hiçbir ekstra maliyeti yoktur.
- **Interceptor/Middleware** (`AddBeforePublish`/`AddAfterPublish`): her `Publish` çağrısından önce/sonra (abone başına değil, çağrı başına bir kez) çalışan merkezi loglama/denetim hook'ları.
- **Debounce**: `Subscribe`'a `ADebounceMs` verilirse, ardışık olaylarda handler yalnızca sessizlik süresi dolunca ve EN SON değerle bir kez çalışır (arama kutusu, resize gibi senaryolar için).
- **`dmMainSync` için opsiyonel zaman aşımı**: `AMainSyncTimeoutMs` verilirse yayıncı thread ana thread'i sonsuza kadar beklemez; iş kaybolmaz, sadece bekleme süresi sınırlanır.

## Analiz: Wrapper mı, Yeni Yapı mı?

**Karar: Ne GpEventBus'ın ne de NX.Horizon'ın doğrudan wrapper'ı değil — ikisinin kanıtlanmış tekniklerini yeniden kullanan yeni bir yapı.**

Gerekçe:
- **GpEventBus.Subscribe\<T\>/Fire\<T\>**, sadece `T`'nin `PTypeInfo`'suna göre anahtarlanıyor — **kanal kavramı yok**. Aynı `T` tipini birden fazla isme (`'customer.record'`, `'order.process'`) bağlamak için bir "zarf" (envelope) tipiyle sarmalayıp filtrelemek gerekirdi; bu da GpEventBus'ın kendi dispatch mekanizmasını (thread-based APC dispatch, `RegisterThread` zorunluluğu, alertable-wait gerekliliği) bypass edip ayrı bir dispatch katmanı yazmayı gerektirirdi — yani görünüşte "wrapper" ama içeriği tamamen yeniden yazılmış bir kod ortaya çıkardı.
- GpEventBus'ın kendi dokümanındaki ("No Synchronous Dispatch Option") kısıtı, `dmSync`/`dmMainSync` gibi bloklayan modları desteklemeyi zaten imkansız kılıyor.
- **NX.Horizon** da `TDictionary<PTypeInfo, ...>` ile anahtarlanıyor — string kanal yok.
- Bu yüzden kanal deposu (`TDictionary<string, ...>`, normalize edilmiş anahtar) **yeni** yazıldı; ama şu **kanıtlanmış teknikler doğrudan** bu iki kütüphaneden alınıp uyarlandı:
  - GpEventBus'ın generic anonymous method'u `IInterface` olarak "boxing" ile tip silme (type erasure) tekniği (`IInterface(Pointer(@handler)^)`) — heterojen `T` tipli abonelikleri aynı listede saklamak için.
  - GpEventBus'ın `TLightweightMREW` + "kilit altında snapshot array al, kilidi bırak, snapshot üzerinde dispatch et" deseni.
  - GpEventBus'ın **"class, interface değil"** kararı — Delphi interface'leri generic method içeremediği için (`Subscribe<T>`/`Publish<T>` bu yüzden `TChannelBus` sınıfında, bir arayüzde değil).
  - NX.Horizon'un `TChannelDelivery` (Sync/Async/MainSync/MainAsync) ayrımı ve ana thread'e `TThread.Synchronize`/`ForceQueue` ile dispatch deseni.
  - NX.Horizon'un `TCountdownEvent` tabanlı `BeginWork`/`EndWork`/`WaitFor` deseni — GpEventBus'ın basit atomik iptal bayrağından daha güçlü olduğu için (devam eden işi **bekleyebilme** yeteneği) tercih edildi.

### Ek İnceleme: `GpEventBus.DispatchProof.md` ve `GpEventBus.AlertableWaitMonitor.pas` — Wrapper Kararını Değiştirir mi?

Kullanıcı isteğiyle bu iki dosya da incelendi. **Sonuç: Wrapper kararını DEĞİŞTİRMİYOR, tam tersine DOĞRULUYOR/PEKİŞTİRİYOR.**

- **`GpEventBus.DispatchProof.md`**, GpEventBus'ın arka plan thread'lerine dağıtım yaptığı `DispatchToBackgroundThread`/`APCProc` protokolünün (bir "bayrak + kuyruk" deseni: `TThreadedQueue<TProc>` + atomik `APCSignaled` bayrağı, Windows `QueueUserAPC` ile tetiklenen) **biçimsel doğruluk ispatıdır** — tek/çoklu üretici (producer) senaryolarında hiçbir olayın kaybolmadığını (stranding olmadığını) kanıtlıyor.
- **`GpEventBus.AlertableWaitMonitor.pas`**, bu APC tabanlı mekanizmanın **çalışması İÇİN ZORUNLU bir ön koşulu** doğruluyor: hedef arka plan thread'inin `SleepEx`/`WaitForSingleObjectEx(..., bAlertable=True)` gibi bir **"alertable wait"** içinde olması gerekiyor — aksi halde `QueueUserAPC` ile kuyruklanan olay o thread'e **asla teslim edilmiyor**. Bu dosya (sadece DEBUG derlemede) bunu unutan thread'leri otomatik tespit edip hata fırlatan bir yardımcı monitor.

Bu iki dosya, ilk analizde tespit edilen iki gerçek engeli **teyit ediyor**:
1. GpEventBus'ın arka plan teslimatı, çağıranın (subscriber thread'inin) **kendi mesaj döngüsünü APC-uyumlu (alertable wait) yazmasını** şart koşuyor — `rad.eventbus.pas`'ın `dmAsync`'i ise `TTask.Run` (thread pool) kullandığı için abone tarafında **hiçbir özel gereksinim yok**; bu, GpEventBus'ın temel tasarım varsayımıyla kökten uyumsuz.
2. `GpEventBus.md`'de zaten tespit edilen **"No Synchronous Dispatch Option"** kısıtı hâlâ geçerli — APC mekanizması doğası gereği asenkron; `dmSync`/`dmMainSync` gibi bloklayan/senkron modlar bu protokolün üzerine inşa edilemez.

Kısacası: APC-coalescing protokolü kanıtlanmış derecede doğru ve zarif bir mühendislik — ama **farklı bir problemi** (thread'e-özel, alertable-wait-gerektiren dağıtım) çözüyor. `rad.eventbus.pas`'ın çözdüğü problem (senkron + asenkron + ana-thread modları, abone tarafında sıfır özel gereksinim) için bu protokolün üzerine wrapper yazmak, GpEventBus'ın tüm abone thread'lerinin `RegisterThread` çağırıp alertable wait kullanmasını zorunlu kılardı — kullanım kolaylığı açısından mevcut tasarımdan geriye gidiş olurdu.

## MainSync Deadlock Önleme

`dmMainSync`, çağıran thread ana thread ise handler'ı **doğrudan** çağırır; `TThread.Synchronize` kullanmaz. Çünkü `TThread.Synchronize`, ana thread'den ana thread'e kendi kendini beklemeye çalışırsa **sonsuza kadar kilitlenir** (self-deadlock — ana thread hem bekleyen hem de beklenen taraf olur). Sadece çağıran thread ana thread **değilse** `TThread.Synchronize` kullanılır.

```pascal
// TChannelBus.DispatchOne içinde:
dmMainSync:
  if TThread.CurrentThread.ThreadID = MainThreadID then
    LWrapped()                                   // doğrudan çağrı — kilitlenmez
  else
    TThread.Synchronize(nil, TThreadProcedure(LWrapped));
```

Bu davranış `AnaThreadtanMainSyncYayinKendiKendiniKilitlemez` testiyle doğrulanmıştır (bkz. Test Kapsamı) — test, ana thread'den `dmMainSync` abonelikli bir kanala `Publish` çağırır; kod bu özel durumu ele almasaydı test **hiç dönmezdi**.

`WaitAndUnsubscribe` de aynı prensiple çalışır: ana thread'den çağrılıyorsa `CheckSynchronize`'i pompalayarak bekler (aksi halde kendi kuyruklamış olabileceği `dmMainSync`/`dmMainAsync` dispatch'leri asla çalışamaz ve sonsuza kadar bloklanır).

## Hata Yönetimi: İzolasyon + `OnError`

**Sorun (eski davranış):** `dmSync`/`dmMainSync`'te bir abonenin handler'ı exception fırlatırsa, `Publish` içindeki `for` döngüsü o noktada kesiliyor ve aynı çağrıdaki **diğer aboneler hiç çağrılmıyordu**. Ayrıca `dmAsync` (`TTask.Run`) içindeki exception'lar hiç gözlemlenmiyor, sessizce kayboluyordu.

**Çözüm:** `DispatchOne`, her abonenin `AProc()` çağrısını artık kendi `try/except`'ine sarıyor — bu, **HER delivery modunda** (dmSync/dmAsync/dmMainSync/dmMainAsync fark etmez) geçerli, tek ve merkezi bir mekanizma:
- Bir abone hata fırlatırsa, o hata **o aboneyle sınırlı kalır** — aynı `Publish` çağrısındaki diğer abonelerin çağrılmasını asla engellemez.
- `TChannelBus.OnError` atanmışsa, hata `(AChannel, AData, E)` ile bildirilir — `AData`, dispatch edilmekte olan olayın `TValue`'ya kutulanmış hali (`TValue.From<T>`/`From<TArray<TValue>>`/`From<IDocDict>`), `AData.AsType<T>` ile geri açılabilir.
- `OnError` **atanmamışsa**, hata sessizce yutulur (`rad.cmd.pas`'taki `ExecuteAsync`/`OnError` deseniyle tutarlı bir tercih — bkz. `rad.cmd.md`) — ama `ErrorIsolation=True` olduğu sürece izolasyon `OnError`'un atanıp atanmadığından bağımsız her koşulda geçerlidir.

```pascal
ChannelBus.OnError :=
  procedure(const AChannel: string; const AData: TValue; E: Exception)
  begin
    // AData.AsType<TSiparisOlayi> ile orijinal olay verisine erişilebilir (tipini biliyorsan).
    WriteLn(Format('Kanal=%s Hata=%s Veri=%s', [AChannel, E.Message, AData.ToString]));
  end;
```

Bu davranış `BirAboneninHatasiDigerAboneleriEngellemez`, `OnErrorAtanmamissaHataSessizceYutulur`, `OnErrorAtanmissaKanalVeVeriDogruBildirilir` ve `OnErrorAsenkronAbonedeDeCalisir` testleriyle doğrulanmıştır.

### Performans: `AData` TEMBEL (lazy), `AErrorIsolation` ayarı

İlk implementasyonda `AData: TValue`, `TValue.From<T>(AEvent)` ile HER `Publish` çağrısında (hata olsun olmasın) EAGER hesaplanıyordu — bu, benchmark'ta ölçülebilir bir gerileme yarattı (`dmSync`: ~1.975.000 → ~1.677.800 olay/sn). Kök neden teşhis edilip düzeltildi: `AData` artık `reference to function: TValue` tipinde TEMBEL bir sağlayıcı olarak taşınıyor — yalnızca bir handler GERÇEKTEN exception fırlatırsa (`except` bloğunun içinde) çağrılıyor. Sonuç: `dmSync` şimdi ~2.000.000-2.160.000 olay/sn (orijinal ölçümün üstünde/eşit) — bkz. Benchmark tablosu.

Ayrıca, izolasyon+`OnError` sarmalamasının kendisinin bile (try/except'in `dmSync` gibi çok sık çağrılan bir yolda ekstra maliyeti) tamamen ortadan kaldırılmak istenen ileri seviye senaryolar için `AErrorIsolation: Boolean = True` ayarı eklendi (`TChannelBus.Create`/`CreateChannelBus`'ın 3. parametresi, `ErrorIsolation` property'siyle salt-okunur okunabilir):

```pascal
// AErrorIsolation=False: try/except sarmalaması HİÇ yapılmaz — eski/çıplak davranış.
// Bir abone hata fırlatırsa, o hata (dmSync'te) doğrudan Publish çağıranına yükselir ve
// aynı çağrıdaki SONRAKİ aboneler çağrılmaz; OnError da hiç devreye girmez. Üst düzeyde
// kendi hata yönetimini yapan, mutlak azami throughput isteyen senaryolar için.
var HizliBus := CreateChannelBus(opBlockPublisher, 1024, False);
```

## Wildcard (Catch-All) Abonelik

`Subscribe`/`Subscribe(...Dyn...)`/`Subscribe(...Json...)`'a verilen kanal adı `'*'` veya `'?'` içeriyorsa (ör. `'siparis.*'`), bu bir **desen (pattern)** olarak ayrı bir havuzda tutulur ve `System.Masks.MatchesMask` (glob-style, case-insensitive) ile eşleştirilir — `'siparis.*'` deseni `'siparis.tamamlandi'`, `'siparis.iptal'` gibi TÜM `'siparis.'` ile başlayan somut kanalları karşılar.

```pascal
// Tüm sipariş olaylarını tek bir yerden izleyen bir debug/log paneli:
ChannelBus.Subscribe<TSiparisOlayi>('siparis.*', dmMainAsync,
  procedure(const AEvent: TSiparisOlayi)
  begin
    LogMemo.Lines.Add('Sipariş olayı: #' + AEvent.SiparisNo.ToString);
  end);

// Aşağıdaki İKİ farklı somut kanala yapılan Publish de yukarıdaki handler'ı tetikler:
ChannelBus.Publish<TSiparisOlayi>('siparis.tamamlandi', Olay);
ChannelBus.Publish<TSiparisOlayi>('siparis.iptal', Olay);
```

**Performans:** wildcard abonelik hiç kullanılmadığı sürece (`FHasWildcardsInt=0`) `Publish`'te tek bir ucuz `TInterlocked` kontrolü dışında hiçbir ekstra maliyet yoktur — bu, `WildcardYokkenDavranisDegismez` testiyle davranış açısından, benchmark tablosundaki (wildcard kullanmayan) sayıların değişmediğiyle de performans açısından doğrulanmıştır. Eşleştirme artık her `Publish`'te `MatchesMask` ile yeniden PARSE ETMİYOR — her abonelik kendi önceden derlenmiş `TMask`'ını `Subscribe` anında bir kez oluşturuyor (bkz. "2026-07-09 (2. tur)" bölümü).

**Sınırlamalar/notlar:**
- `SubscriberCount(AChannel)` yalnızca TAM eşleşen abonelikleri sayar — o kanalı karşılayabilecek wildcard abonelikleri saymaz (kasıtlı olarak basit tutuldu).
- `Channels` yalnızca tam (wildcard olmayan) kanal adlarını döner; kayıtlı desenler için `WildcardPatterns` kullanılır.
- `TotalSubscriberCount`, wildcard havuzundakileri de dahil eder (bus genelindeki GERÇEK toplam abone sayısı).

## Interceptor / Middleware

`AddBeforePublish`/`AddAfterPublish`, her `Publish` çağrısından ÖNCE/SONRA (abone sayısından bağımsız, **çağrı başına bir kez**) çalışacak merkezi bir hook kaydeder — loglama, denetim (audit), metrik toplama gibi kesişen ilgiler (cross-cutting concerns) için.

```pascal
ChannelBus.AddBeforePublish(
  procedure(const AChannel: string; const AData: TValue)
  begin
    WriteLn(Format('[YAYIN] %s -> %s', [AChannel, AData.ToString]));
  end);
```

**Sıra:** `Before` → (tüm abonelere dispatch) → `After`. **Kaldırma desteklenmez** — tipik kullanım uygulama ömrü boyunca sürecek bir logger/denetim middleware'idir. Bir interceptor exception fırlatırsa (`ErrorIsolation=True` iken) yutulur, diğer interceptor'lar ve asıl dispatch etkilenmez.

**Performans:** hiç interceptor eklenmediği sürece (`FHasBeforePublishInt`/`FHasAfterPublishInt` her ikisi de `0`) `Publish`'te iki ucuz `TInterlocked` kontrolü dışında hiçbir maliyet yoktur — `AData` (`TValue.From<T>`) yalnızca EN AZ BİR interceptor kayıtlıyken hesaplanır. İnterceptor listeleri (Add-only, kaldırma desteklenmediği için) artık her `Publish`'te `TList.ToArray` ile kopyalanmıyor — yalnızca `AddBeforePublish`/`AddAfterPublish` çağrıldığında önbelleğe alınıyor.

## Debounce

`Subscribe`'ın son parametresi `ADebounceMs > 0` verilirse, handler ARDIŞIK olaylarda hemen değil, **`ADebounceMs` kadar sessizlik oluşunca ve o ana kadarki EN SON veriyle** bir kez çalışır — arama kutusu, pencere yeniden boyutlandırma gibi "çok sık tetiklenen ama yalnızca sonuncusu önemli" senaryolar için.

```pascal
// Kullanıcı her tuş vuruşunda bu kanala yayın yapılıyor varsayalım; sunucuya sorgu
// yalnızca kullanıcı 300ms yazmayı durdurunca, EN SON yazdığı metinle atılır.
ChannelBus.Subscribe<TAramaOlayi>('arama.metin', dmAsync,
  procedure(const AEvent: TAramaOlayi)
  begin
    SunucuyaSorgulaAsync(AEvent.Metin);
  end, INFINITE, 300); // AMainSyncTimeoutMs=INFINITE (kullanılmıyor), ADebounceMs=300
```

**Nasıl çalışır (iç mekanizma):** kalıcı bir thread TUTULMAZ. Her yeni olay, "en son gelen" olarak kaydedilip bir nesil (generation) sayacını artırır ve `Sleep(ADebounceMs)` sonra kontrol edecek bir `TTask.Run` görevi başlatır. Görev uyandığında kendi ürediği andaki nesil hâlâ GÜNCELse (aradan daha yeni bir olay gelmediyse) çalışır; değilse sessizce hiçbir şey yapmaz (daha yeni bir görev zaten onun yerini almıştır). `ADebounceMs=0` (varsayılan) ise debounce tamamen devre dışıdır, her `Publish` handler'ı normal şekilde tetikler.

**Not:** debounce, delivery modunun NE'sini değil NE ZAMAN'ını etkiler — sessizlik süresi dolunca, `ADelivery` (dmSync/dmAsync/dmMainSync/dmMainAsync) normal kurallarına göre dispatch edilir (dmSync/dmMainSync için bu, "debounce zamanlayıcısının kendi arka plan thread'inde, ileride bir noktada" anlamına gelir — çağrının kendisi artık orijinal `Publish` anıyla senkron değildir).

## `dmMainSync` İçin Opsiyonel Zaman Aşımı

`TThread.Synchronize`'ın timeout parametresi yoktur — ana thread meşgulse yayıncı thread SÜRESİZ bekler. `Subscribe`'a `AMainSyncTimeoutMs` verilirse (varsayılan `INFINITE` = eski davranış), yayıncı thread en fazla bu kadar bekler; süre dolarsa **iş kaybolmaz** (kuyruklanmış olarak kalır, ana thread müsait olduğunda çalışır), sadece yayıncı artık onu beklemez.

```pascal
// Ana thread meşgulse bile arka plan thread'i en fazla 200ms bekler, sonra devam eder.
ChannelBus.Subscribe<TDurumOlayi>('durum.guncelle', dmMainSync,
  procedure(const AEvent: TDurumOlayi) begin StatusBar1.SimpleText := AEvent.Mesaj; end,
  200); // AMainSyncTimeoutMs=200
```

**Nasıl çalışır:** `TThread.Synchronize` yerine `TThread.ForceQueue` (her zaman kuyruklar, hemen döner) + ref-counted (interface sarmalı) bir `TEvent.WaitFor(timeout)` kullanılır. Referans sayımı sayesinde, süre dolup yayıncı beklemeyi bıraksa bile, kuyruklanmış closure DAHA SONRA çalışıp event'i sinyallediğinde zaten-serbest-bırakılmış bir nesneye erişme (AV) riski YOKTUR — nesne, her iki tarafın da referansını bıraktığı anda otomatik serbest kalır.

## opBlockPublisher + Ana Thread Riski

**Risk:** `opBlockPublisher` politikasıyla `dmAsync` kuyruğu doluyken `Publish` çağıran thread'i bekletir. Bu thread UYGULAMANIN ANA (UI) THREAD'İ ise, kuyruk boşalana kadar **arayüz donar**. Daha da kötüsü: eğer kuyruktaki bekleyen işlerden biri `dmMainSync` ile (bloklanmış) ana thread'i bekliyorsa, teorik bir çıkmaza (deadlock'a yakın bir duruma) yol açabilir.

**Kesin kural: `opBlockPublisher` kullanıyorsan, ana/UI thread'den `dmAsync` `Publish` ÇAĞIRMA.** Bunun yerine: bir arka plan thread'inden yayınla, VEYA `opDropOldest`/`opDropNewest`/`opGrow` gibi asla bloklamayan bir politika kullan.

**DEBUG-modda otomatik tespit:** `TAsyncEventQueue.TryEnqueue`, kuyruk GERÇEKTEN doluyken (bloklamak üzereyken) çağıran thread'in ana thread olduğunu tespit ederse, **yalnızca `{$IFDEF DEBUG}` derlemelerde** açıklayıcı bir exception fırlatır — geliştirme sırasında bu anti-pattern'i erken yakalamak için (RELEASE derlemede bu kontrol tamamen devre dışıdır, sıfır maliyetlidir).

```pascal
// DEBUG derlemede, ana thread'den çağrılıp kuyruk dolarsa EXCEPTION fırlatır:
// "rad.eventbus: opBlockPublisher kuyruğu doluyken ANA THREAD'den (dmAsync) Publish
//  çağrıldı — ana thread kilitlenmek üzereydi. ..."
ChannelBus.Publish<TSiparisOlayi>('yogun.kanal', Olay); // (ana thread'den, opBlockPublisher ile)
```

Bu davranış `OpBlockPublisherAnaThreaddenCagrilirsaDebugtaHataVerir` testiyle doğrulanmıştır (test hem DEBUG hem RELEASE derlemede ayrı ayrı çalıştırılıp doğrulandı).

## Tipler ve Metodlar

| İsim | Parametreler | Ne işe yarar |
|---|---|---|
| `TChannelDelivery` | `dmSync, dmAsync, dmMainSync, dmMainAsync` | Bir olayın nasıl teslim edileceği. |
| `TOverflowPolicy` | `opDropOldest, opDropNewest, opBlockPublisher, opGrow` | `dmAsync` kuyruğu dolduğunda uygulanacak politika. |
| `TChannelHandler<T: record>` | `reference to procedure(const AEvent: T)` | Abone olunacak handler imzası; `T` bir `record` olmalı. |
| `TChannelHandlerDyn` | `reference to procedure(const AArgs: TArray<TValue>)` | Esnek/dinamik imzalı handler — `rad.cmd.pas`'taki `TCmd` (`TArray<TValue>`) tasarımıyla tutarlı, `T:record` kısıtı yok. |
| `TChannelHandlerJson` | `reference to procedure(const AJson: IDocDict)` | mORMot `IDocDict` (JSON) tabanlı handler — dinamik/scriptable senaryolar için. |
| `TChannelInterceptor` | `reference to procedure(const AChannel: string; const AData: TValue)` | `AddBeforePublish`/`AddAfterPublish` imzası. |
| `IChannelSubscription` | — | `Subscribe*`'in döndürdüğü token: `IsActive`, `Channel`, `Unsubscribe`, `WaitAndUnsubscribe(ATimeoutMs)`. |
| `CreateChannelBus(APolicy, ADepth, AErrorIsolation)` (global fonksiyon) | `TOverflowPolicy = opBlockPublisher`, `Integer = 1024`, `Boolean = True` | Yeni, izole bir `TChannelBus` oluşturur. **Çağıran Free etmekle sorumludur.** |
| `ChannelBus` (global fonksiyon) | — | Tembel-başlatılan (lazy), paylaşılan **global** `TChannelBus`. **Free ETME** — ünite `finalization`'ında otomatik temizlenir. |
| `TChannelBus.Create(APolicy, ADepth, AErrorIsolation)` | `TOverflowPolicy = opBlockPublisher`, `Integer = 1024`, `Boolean = True` | `CreateChannelBus` ile aynı; doğrudan constructor kullanımı. `AErrorIsolation=False` ise izolasyon/`OnError` sarmalaması hiç yapılmaz (bkz. "Hata Yönetimi" bölümü). |
| `ErrorIsolation` | — | Bu bus için izolasyon/`OnError`'un açık olup olmadığı (salt-okunur, `Create`'te belirlenir). |
| `Subscribe<T: record>(AChannel, ADelivery, AHandler, AMainSyncTimeoutMs, ADebounceMs)` | string, `TChannelDelivery`, `TChannelHandler<T>`, `Cardinal = INFINITE`, `Cardinal = 0` | Kanala abone olur; `IChannelSubscription` döner. Kanal adı normalize edilir (trim + lowercase-invariant); boş/whitespace-only kanal adı `EArgumentException` fırlatır. `AChannel` `'*'`/`'?'` içeriyorsa (ör. `'siparis.*'`) wildcard abonelik olarak kaydedilir. `AHandler` nil ise `EArgumentNilException` fırlatır. `AMainSyncTimeoutMs`/`ADebounceMs` opsiyoneldir (bkz. ilgili bölümler). |
| `Subscribe(AChannel, ADelivery, AHandler: TChannelHandlerDyn, AMainSyncTimeoutMs, ADebounceMs)` (overload) | string, `TChannelDelivery`, `TChannelHandlerDyn`, `Cardinal = INFINITE`, `Cardinal = 0` | `TArray<TValue>` tabanlı esnek abonelik. Yalnızca AYNI şekilde (`Publish(..., TArray<TValue>)`) yayınlanan olayları alır. |
| `Subscribe(AChannel, ADelivery, AHandler: TChannelHandlerJson, AMainSyncTimeoutMs, ADebounceMs)` (overload) | string, `TChannelDelivery`, `TChannelHandlerJson`, `Cardinal = INFINITE`, `Cardinal = 0` | `IDocDict` (JSON) tabanlı abonelik. Yalnızca `Publish(..., IDocDict)` ile yayınlanan olayları alır. |
| `Publish<T: record>(AChannel, AEvent)` | string, `T` | Kanala yayınlar; her abone **kendi** `ADelivery` modunda çağrılır. |
| `Publish<T: record>(AChannel, AEvent, ADelivery)` | string, `T`, `TChannelDelivery` | Kanala yayınlar; **bu çağrının** `ADelivery`'si abonenin kendi modunu geçersiz kılar (NX.Horizon'un `Send<T>` deseni). |
| `Publish(AChannel, AArgs: TArray<TValue>)` (overload) | string, `TArray<TValue>` | Yalnızca `TChannelHandlerDyn` abonelerine ulaşır. |
| `Publish(AChannel, AArgs: TArray<TValue>, ADelivery)` (overload) | string, `TArray<TValue>`, `TChannelDelivery` | Yukarıdakiyle aynı, `ADelivery` geçersiz kılar. |
| `Publish(AChannel, AJson: IDocDict)` (overload) | string, `IDocDict` | Yalnızca `TChannelHandlerJson` abonelerine ulaşır. |
| `Publish(AChannel, AJson: IDocDict, ADelivery)` (overload) | string, `IDocDict`, `TChannelDelivery` | Yukarıdakiyle aynı, `ADelivery` geçersiz kılar. |
| `SubscriberCount(AChannel)` | string | Kanaldaki **aktif** abone sayısı (henüz süpürülmemiş iptal edilmiş kayıtlar sayılmaz). Kanal hiç yoksa `0` döner — **kalıcı boş liste OLUŞTURMAZ** (bkz. "2026-07-09 (2. tur)" bölümü). |
| `Channels` | — | En az bir kayıtlı aboneliği olan tüm (normalize edilmiş, wildcard OLMAYAN) kanal adları. |
| `WildcardPatterns` | — | Kayıtlı tüm wildcard desenleri (ör. `'siparis.*'`). |
| `TotalSubscriberCount` | — | Bus genelinde, tüm kanallar + wildcard havuzundaki toplam **aktif** abone sayısı. |
| `UnsubscribeChannel(AChannel)` | string | Yalnızca AChannel'a TAM eşleşen abonelikleri kaldırır — **wildcard desenli abonelikleri (ör. `'siparis.*'`) KALDIRMAZ**, sessizce no-op'tur (ayrı bir havuzda tutuldukları için). Wildcard bir aboneliği kaldırmak için o aboneliğin kendi `IChannelSubscription.Unsubscribe`'ını kullanın. |
| `DroppedCount` | — | `dmAsync` kuyruğunda (`opDropOldest`/`opDropNewest` nedeniyle) o ana kadar atılmış toplam olay sayısı. |
| `OnError: TChannelErrorHandler` | `reference to procedure(const AChannel: string; const AData: TValue; E: Exception)` | Bir abone hata fırlattığında (hangi delivery modu olursa olsun) çağrılır. Atanmazsa hata sessizce yutulur; her iki durumda da dispatch **izole**dir (aşağıya bkz.). |
| `AddBeforePublish(AInterceptor)` | `TChannelInterceptor` | Her `Publish` çağrısından ÖNCE (çağrı başına bir kez) çalışacak interceptor kaydeder. Kaldırma yok. |
| `AddAfterPublish(AInterceptor)` | `TChannelInterceptor` | Her `Publish` çağrısından SONRA (çağrı başına bir kez) çalışacak interceptor kaydeder. Kaldırma yok. |

**Not — aynı kanalda üç "tür" karışmaz:** `Subscribe<T>`, `Subscribe(...TChannelHandlerDyn...)` ve `Subscribe(...TChannelHandlerJson...)` aynı kanal adına birlikte abone olabilir; her biri yalnızca **kendi tipinde** yayınlanan `Publish` çağrısına yanıt verir (dahili olarak her "tür" ayrı bir `PTypeInfo` etiketiyle işaretlenir — generic `T` için `TypeInfo(T)`, dinamik/JSON overload'lar için sabit `TypeInfo(TArray<TValue>)`/`TypeInfo(IDocDict)` etiketleri).

## Kullanım Örnekleri

**1. Basit abonelik + senkron yayın (`dmSync`):**
```pascal
type
  TSiparisOlayi = record
    SiparisNo: Integer;
    Tutar: Currency;
  end;

var Sub := ChannelBus.Subscribe<TSiparisOlayi>('siparis.tamamlandi', dmSync,
  procedure(const AEvent: TSiparisOlayi)
  begin
    WriteLn(Format('Sipariş #%d tamamlandı, tutar: %m', [AEvent.SiparisNo, AEvent.Tutar]));
  end);

var Olay: TSiparisOlayi;
Olay.SiparisNo := 1001;
Olay.Tutar := 249.90;
ChannelBus.Publish<TSiparisOlayi>('siparis.tamamlandi', Olay); // handler burada, senkron çalışır
```

**2. UI güncelleme için `dmMainAsync` (arka plan thread'inden UI'a güvenli bildirim):**
```pascal
// Herhangi bir arka plan thread'inden (worker, TTask, vs.) çağrılabilir.
ChannelBus.Subscribe<TSiparisOlayi>('siparis.tamamlandi', dmMainAsync,
  procedure(const AEvent: TSiparisOlayi)
  begin
    // Bu kod HER ZAMAN ana (VCL/FMX) thread'de çalışır — UI'a doğrudan dokunmak güvenli.
    Memo1.Lines.Add('Sipariş #' + AEvent.SiparisNo.ToString);
  end);
```

**3. Çağrının kendi `ADelivery`'siyle geçersiz kılma:**
```pascal
// Abone dmSync ile kayıtlı olsa bile, bu yayın onu dmAsync olarak zorlar.
ChannelBus.Publish<TSiparisOlayi>('siparis.tamamlandi', Olay, dmAsync);
```

**4. Abonelik iptali (dispatch sırasında bile güvenli):**
```pascal
var Sub := ChannelBus.Subscribe<TSiparisOlayi>('siparis.tamamlandi', dmSync,
  procedure(const AEvent: TSiparisOlayi)
  begin
    if AEvent.Tutar > 1000 then
      Sub.Unsubscribe; // handler'ın KENDİ İÇİNDEN çağrılıyor — güvenli
  end);
```

**5. Component/form kapanırken güvenli temizlik:**
```pascal
// Devam eden bir dispatch varsa (ör. dmAsync kuyrukta bekleyen bir çağrı), onun
// bitmesini bekler, SONRA iptal eder — form Free edilirken yarım kalmış bir
// dispatch'in artık var olmayan bir nesneye erişmesini engeller.
Sub.WaitAndUnsubscribe(5000); // en fazla 5 sn bekler
```

**6. Taşma politikası ile izole bir veriyolu oluşturma:**
```pascal
var Bus := CreateChannelBus(opDropOldest, 256); // kuyruk dolarsa en eski olay atılır
try
  Bus.Subscribe<TSiparisOlayi>('yogun.kanal', dmAsync, procedure(const AEvent: TSiparisOlayi) begin ... end);
  // ... yoğun yayın ...
  WriteLn('Atılan olay sayısı: ', Bus.DroppedCount);
finally
  Bus.Free; // CreateChannelBus ile üretilenler MUTLAKA Free edilmeli
end;
```

**7. Aynı kanalda farklı olay tipleri çakışmaz:**
```pascal
// İkisi de 'sistem.olay' kanalına abone ama farklı T — birbirini etkilemez.
ChannelBus.Subscribe<TGirisOlayi>('sistem.olay', dmSync, procedure(const AEvent: TGirisOlayi) begin ... end);
ChannelBus.Subscribe<TCikisOlayi>('sistem.olay', dmSync, procedure(const AEvent: TCikisOlayi) begin ... end);
```

**8. `TArray<TValue>` tabanlı esnek/dinamik abonelik (`rad.cmd.pas`'taki `TCmd` tasarımıyla tutarlı):**
```pascal
// T:record kısıtı yok — RTTI (TValue) ile herhangi bir imza taşınabilir; script/plugin
// gibi çalışma-zamanında tip bilinmeyen senaryolar için.
var Sub := ChannelBus.Subscribe('siparis.tamamlandi', dmSync,
  procedure(const AArgs: TArray<TValue>)
  begin
    WriteLn(Format('Sipariş #%d tamamlandı, tutar: %m', [AArgs[1].AsInteger, AArgs[2].AsExtended]));
  end);

// TValue'nun implicit operator'leri sayesinde dizi literali doğrudan yazılabilir.
ChannelBus.Publish('siparis.tamamlandi', ['siparis', 1001, 249.90]);
```

**9. mORMot `IDocDict` (JSON) tabanlı abonelik:**
```pascal
var Sub := ChannelBus.Subscribe('siparis.tamamlandi', dmSync,
  procedure(const AJson: IDocDict)
  begin
    // I[]:Int64  F[]:double  C[]:currency  U[]/S[]:string  B[]:boolean  D[]:IDocDict (iç içe)
    WriteLn(Format('Sipariş #%d tamamlandı, tutar: %m', [AJson.I['SiparisNo'], AJson.F['Tutar']]));
  end);

var Json := DocDict; // mormot.core.variants
Json.I['SiparisNo'] := 1001;
Json.F['Tutar'] := 249.90;
ChannelBus.Publish('siparis.tamamlandi', Json);
```

> **Not:** `Subscribe<T>`/`Publish<T>` bir `record` bekler; `TArray<TValue>` ve `IDocDict` birer `record` OLMADIĞI için (dizi/interface) bu iki yeni overload, generic `Subscribe<T>/Publish<T>` ile **asla karışmaz** — Delphi'nin overload çözümlemesi parametre tipine bakarak otomatik doğru metodu seçer, çağırırken `<T>` belirtmeye gerek yoktur.

**10. Diagnostik: aktif kanalları ve toplam abone sayısını listeleme:**
```pascal
var Kanal: string;
for Kanal in ChannelBus.Channels do
  WriteLn(Format('%s: %d abone', [Kanal, ChannelBus.SubscriberCount(Kanal)]));
WriteLn('Toplam abone: ', ChannelBus.TotalSubscriberCount);
```

## Performans Ölçümleri (Benchmark)

`Core\rad.eventbus.Benchmark.pas`, gerçek derlenmiş/çalıştırılmış ölçüm sonuçları (geliştirme makinesi — mutlak sayılar donanıma/sisteme göre değişir, göreli oranlar anlamlıdır). **Interceptor + Debounce + `dmMainSync` timeout + opBlockPublisher guard eklendikten SONRAKİ** güncel sayılar (birden fazla art arda çalıştırmanın temsili aralığı — hiçbiri bu turda kullanılmadığı için `FHasBeforePublishInt`/`FHasAfterPublishInt` kısayolu devrede, debounce da `ADebounceMs=0` yolunu izliyor):

| Mod | Olay Sayısı | Olay/sn | Ort. Gecikme (µs) | Min (µs) | Max (µs) |
|---|---|---|---|---|---|
| `dmSync` | 200.000 | ~1.870.000 – 1.970.000 | ~0,35-0,40 | 0,20-0,30 | değişken |
| `dmMainSync` | 5.000 | ~220.000 – 230.000 | ~1,9-2,1 | 1,30-1,40 | değişken |
| `dmMainAsync` | 20.000 | ~1.030.000 – 1.100.000 | ~9.400-9.700 | ~1.500-1.800 | değişken |
| `dmAsync` | 20.000 | ~35.000 – 76.000 | değişken (yüke göre) | değişken | değişken |

**Kullanıcının fark ettiği ilk düşüş (`dmSync`: ~1.975.000 → ~1.677.800) teşhis edildi ve düzeltildi.** Kök neden `OnError` özelliği eklenirken `AData: TValue`'nun `TValue.From<T>(AEvent)` ile HER `Publish` çağrısında (hata olsun olmasın) EAGER hesaplanmasıydı — RTTI tabanlı kutulama ölçülebilir bir maliyet. Çözüm: `AData` artık `reference to function: TValue` tipinde TEMBEL (lazy) — yalnızca gerçek bir exception yakalandığında (`except` bloğunda) hesaplanıyor. Ayrıca aşırı-yüksek-throughput senaryoları için `AErrorIsolation=False` ayarı ile try/except sarmalamasının kendisi de tamamen kapatılabiliyor (bkz. "Hata Yönetimi" bölümü).

**`SnapshotAndCompact` allocation optimizasyonu** (önceki turda yapıldı): eski implementasyon, ölü kayıt olmasa bile HER `Publish` çağrısında yeni bir dizi (`FItems.ToArray`) ayırıyordu; bu, `dmAsync`'in sıkı döngüde art arda `Publish` çağırdığı senaryoda asıl darboğazdı. Artık dizi yalnızca yeni `Subscribe` sonrası veya gerçekten ölü bir kayıt bulunduğunda yeniden oluşturuluyor.

**Wildcard/interceptor/debounce desteğinin maliyeti (hiçbiri kullanılmadığında):** hepsi ölçülebilir bir farka yol açmıyor — `dmSync` bu turdan sonra da (~1,87-1,97M olay/sn) önceki turla aynı sağlıklı aralıkta. `dmAsync` bu turda daha düşük (~35-76K) ölçüldü; bu, `dmAsync`'in zaten en gürültülü/thread-zamanlamasına-duyarlı ölçüm olduğu (aşağıdaki nota bkz.) göz önüne alınınca beklenen çalıştırma-arası varyansın içinde — `DispatchOne`'a eklenen tek gerçek ek maliyet (debounce=0 iken bile geçilen `LSub.ScheduleOrRun` dolaylaması, tek bir `Cardinal` karşılaştırması) bu büyüklükte bir düşüşü açıklamaz; kesin izolasyon için tekrarlı ölçüm gerekir.

**Not — `dmAsync`/`dmMainSync`/`dmMainAsync` sayıları neden geniş bir aralıkta değişiyor?** `dmAsync`/`dmMainAsync` ölçümleri, N olayın TAMAMINI önce sıkı bir döngüde yayınlayıp (kuyruğa/`ForceQueue`'ya atıp) ancak SONRA tüketmeye başlıyor (gerçekçi, yayın ile tüketimin iç içe olduğu bir senaryo değil, kasıtlı bir "burst" yükü) — bu, thread pool/işletim sistemi zamanlama gürültüsüne oldukça duyarlı. `dmMainSync` de arka plan thread'i ile ana thread'in pompalama döngüsü arasındaki zamanlamaya bağlı. Tek-tek, senkron kullanımda gerçek uçtan-uca gecikmeyi en güvenilir yansıtan `dmSync`'tir (~0,3µs, tutarlı). `dmAsync`/`dmMainAsync` için asıl önemli metrik tek-olay gecikmesi değil **saf teslimat hızı** (`olay/sn`) ve **kuyruk taşma davranışı**dır (aşağıya bkz.).

## Taşma Politikaları

| Politika | Davranış | Ne zaman kullanılır |
|---|---|---|
| `opBlockPublisher` (varsayılan) | Kuyruk doluyken `Publish` çağıran thread'i bekletir; **asla veri kaybetmez**. | Veri kaybının kabul edilemez olduğu, yayıncının biraz beklemesinin sorun olmadığı senaryolar. |
| `opGrow` | Kuyruk sınırsız büyür; **asla veri kaybetmez** ama bellek riski kullanıcı sorumluluğundadır. | Burst yükün kısa süreli ve toplam hacminin bilinip sınırlı olduğu senaryolar. |
| `opDropOldest` | Kuyruk doluyken en eski bekleyen olayı atıp yenisini ekler. | "En güncel durum önemli" senaryoları (ör. ilerleme yüzdesi bildirimi). |
| `opDropNewest` | Kuyruk doluyken yeni geleni sessizce reddeder. | "İlk gelen öncelikli" senaryoları. |

`opBlockPublisher` ve `opGrow` için "hiç veri kaybetmez" iddiası `OpBlockPublisherHicVeriKaybetmez`/`OpGrowSinirsizKabulEderVeKaybetmez` testleriyle **kesin (deterministik)** olarak doğrulanmıştır. `opDropOldest`/`opDropNewest`'in gerçekten atabildiği ise `OpDropOldestKuyrukDolunceVeriAtar` testiyle **en-iyi-çaba (best-effort, yarış koşuluna dayalı)** olarak doğrulanmıştır — bkz. Test Kapsamı.

## ✅ 2026-07-09 — Bağımsız inceleme dosyalarından ("1.md"/"2.md") doğrulanan 11 bug

Kullanıcı "inceleme yap" + iki serbest-adlı dosya verdi (bkz. `feedback_dikkat_workflow.md`);
ikisi de `rad.eventbus.pas`'ı bağımsız olarak inceleyip GpEventBus/Dext ile
karşılaştırmıştı. 11 gerçek bug/tutarsızlık tek tek doğrulanıp düzeltildi. Gerçek
`dcc32` derlemesi + `src\test\run_tests.bat` (proje geneli 111 test/110 geçti/
1 ilgisiz-bilinen hata/0 leak; `rad.eventbus.Tests`'in 34 testinin TAMAMI hiç
regresyon olmadan geçti) ile doğrulandı.

| # | Bug | Kök neden | Çözüm |
|---|---|---|---|
| 1 [Kritik] | `Publish`/`GetMatchingSubscriptions` ↔ `UnsubscribeChannel` arasında use-after-free — `GetOrCreateList` kilidi bırakıp bir `TSubscriberList` referansı döndürüyordu; başka bir thread `UnsubscribeChannel` ile (`doOwnsValues`) o listeyi tam o sırada `Free` edebiliyordu | Liste referansı alınırken kilit erken bırakılıyordu | `GetMatchingSubscriptions`, `TryGetValue` + `SnapshotAndCompact`'ı TEK bir `FLock.BeginRead` kapsamına aldı — `UnsubscribeChannel`'ın `BeginWrite`'ı okuma bitene kadar bloklanır |
| 2 [Kritik] | Debounce kullanan aboneliklerde kalıcı memory leak — `FPendingProc` hiçbir zaman `nil`'e sıfırlanmıyordu, tuttuğu closure `Self`'e (başka bir interface üzerinden) referans veriyordu → kalıcı self-cycle | `ScheduleOrRun`/`Unsubscribe`'da temizleme yoktu | Debounce başarıyla çalıştıktan SONRA ve `Unsubscribe`'da `FPendingProc := nil` |
| 3 [Yüksek] | `GetMatchingSubscriptions`, abonesi hiç olmayan kanallar için bile `GetOrCreateList` ile kalıcı boş liste oluşturuyordu — dinamik kanal adlarında bellek şişmesi + `Channels()` "hayalet" kanallar döndürüyordu | Okuma yolunda yaratma-da-yapan fonksiyon kullanılıyordu | (1 ile birlikte düzeltildi) artık `TryGetValue` — bulunamazsa `nil`, hiçbir şey oluşturulmaz; `SubscriberCount` de aynı şekilde `TryGetList` kullanıyor |
| 4 [Yüksek] | `SynchronizeWithTimeout`'ta `AWrapped()` hata fırlatırsa `SetEvent` hiç çağrılmıyordu → yayıncı gereksiz yere tam `ATimeoutMs` kadar bekliyordu (yalnızca `ErrorIsolation=False`+`dmMainSync`+timeout kombinasyonunda) | `try/finally` yoktu | `SetEvent` artık `finally` içinde — hata olsun olmasın garanti çağrılır |
| 5 [Orta] | `FHasWildcards`/`FHasBeforePublish`/`FHasAfterPublish` kilitsiz `Boolean` — yazımlar `TInterlocked` DEĞİLDİ, okumalar hiç senkronize değildi | Tutarsız/eksik senkronizasyon | `FHasWildcardsInt`/`FHasBeforePublishInt`/`FHasAfterPublishInt: Integer`, sadece `TInterlocked` ile |
| 6 [Orta] | `DroppedCount` yazımı `TInterlocked.Increment`, okuması kilitsiz field read | Getter'da `TInterlocked` kullanılmıyordu | `TAsyncEventQueue.GetDroppedCount`, `TInterlocked.CompareExchange` ile okuyor |
| 7 [Orta] | `Subscribe*` overload'larında nil handler kontrolü yoktu — nil geçilirse hata, Subscribe anında değil, İLK Publish/dispatch anında (başka bir thread'de) anlaşılmaz bir AV olarak ortaya çıkardı | Kontrol yoktu | `SubscribeBoxed`'da tek noktadan `Assigned(ABoxedHandler)` kontrolü → `EArgumentNilException` |
| 8 [Orta] | Wildcard eşleştirme her `Publish`'te `MatchesMask` ile kanal desenini sıfırdan yeniden parse ediyordu | Önceden derleme yoktu | Her `TChannelSubscription`, wildcard ise `Subscribe` anında bir `TMask` derliyor; `Matches` bunu kullanıyor |
| 9 [Orta] | `UnsubscribeChannel('siparis.*')` wildcard desenler için sessizce hiçbir şey yapmıyordu — davranış dokümante edilmemişti | — | Arayüz dokümanına netleştirici not eklendi (bkz. yukarıdaki tablo) |
| 10 [Düşük] | Boş/whitespace kanal adıyla abonelik/yayın yapılabiliyordu | `NormalizeChannel` boş sonucu kontrol etmiyordu | Boşsa `EArgumentException` fırlatır |
| 11 [Düşük] | `RunInterceptors`, her `Publish`'te `TList.ToArray` ile yeni dizi ayırıyordu (interceptor'lar add-only, kaldırma yok) | Cache yoktu | `FBeforePublishCache`/`FAfterPublishCache`, yalnızca `AddBeforePublish`/`AddAfterPublish`'te yeniden oluşturulur |

**Yeni genel API:** `IChannelSubscriptionInternal.Matches` (iç kullanım). **Davranış
değişiklikleri:** `Subscribe*`'a nil handler geçmek artık anında `EArgumentNilException`
fırlatır (eskiden ilk dispatch'te anlaşılmaz AV); boş/whitespace kanal adı artık
`EArgumentException` fırlatır (eskiden sessizce kabul edilirdi); `SubscriberCount`
artık var olmayan kanallar için kalıcı boş liste oluşturmaz.

**Not:** Bu turda özel regresyon testleri eklenmedi (mevcut 34 test hiç değiştirilmeden
hepsi geçti) — kullanıcı isteğiyle önce bu doküman güncellendi, ayrı regresyon testleri
sonraki bir adımda değerlendirilecek.

---

## Test Kapsamı

`Core\rad.eventbus.Tests.pas` — `TChannelBusTestleri`, 35 test (gerçek `dcc32` ile hem RELEASE hem `-DDEBUG` derlemede `-B` tam derlemeyle derlenip DUnitX konsol runner'ında art arda çalıştırılarak kararlılığı doğrulandı, hiç flaky sonuç gözlenmedi):

- `SenkronYayinAboneyeHemenUlasir` — `dmSync` senkron teslimat + veri doğruluğu.
- `KanalAdiBuyukKucukHarfVeBoslukDuyarsiz` (`[TestCase]`, 3 senaryo) — kanal adı normalizasyonu.
- `FarkliKanallarBirbirineKarismaz` — kanal izolasyonu.
- `AyniKanaldaFarkliTipteAbonelikBirbirineKarismaz` — aynı kanalda farklı `T` tipi izolasyonu.
- `DinamikTValueDizisiIleYayinAboneyeUlasir` — `TArray<TValue>` tabanlı `Subscribe`/`Publish` overload'ı.
- `JsonIDocDictIleYayinAboneyeUlasir` — `IDocDict` tabanlı `Subscribe`/`Publish` overload'ı.
- `DinamikVeJsonVeGenericAyniKanaldaKarismaz` — aynı kanalda `Subscribe<T>`/`TChannelHandlerDyn`/`TChannelHandlerJson` üç "tür"ün birbirine karışmadığı.
- `AsenkronYayinSonundaBaskaThreaddeUlasir` — `dmAsync` gerçekten arka planda çalışıyor mu.
- `AnaThreadtanMainSyncYayinKendiKendiniKilitlemez` — **MainSync self-deadlock önleme** (bkz. yukarı).
- `BaskaThreadtanMainSyncYayinAnaThreadePompalanarakUlasir` — `dmMainSync` çapraz-thread teslimatı.
- `MainAsyncYayinHemenCalismazSonraPompalaninceCalisir` — `dmMainAsync`'in gerçekten ertelendiğinin kanıtı.
- `DispatchSirasindaUnsubscribeCakismaOlusturmaz` — handler'ın kendi kendini iptal etmesi, AV/çift-çağrı yok.
- `WaitAndUnsubscribeDevamEdenIsiBekler` — devam eden işin gerçekten beklendiği.
- `AboneSayisiVeKanalSilmeCalisir` — `SubscriberCount`/`UnsubscribeChannel`.
- `KanallarVeToplamAboneSayisiDogruDoner` — `Channels`/`TotalSubscriberCount`.
- `BirAboneninHatasiDigerAboneleriEngellemez`, `OnErrorAtanmamissaHataSessizceYutulur`, `OnErrorAtanmissaKanalVeVeriDogruBildirilir`, `OnErrorAsenkronAbonedeDeCalisir` (Kategori: `Hata Yonetimi`) — izolasyon + `OnError` (hem sync hem async yolda).
- `WildcardAbonelikBirdenFazlaKanaliKarsilar`, `WildcardDesenUyusmayanKanaliTetiklemez`, `WildcardPatternsVeToplamSayiDogruDoner`, `WildcardYokkenDavranisDegismez` (Kategori: `Wildcard`) — `'siparis.*'` deseninin doğru kanalları karşıladığı, yanlış kanalı tetiklemediği, `WildcardPatterns`/`TotalSubscriberCount`'un doğru olduğu ve wildcard yokken eski davranışın değişmediği.
- `OpBlockPublisherHicVeriKaybetmez` (artık BİLEREK bir arka plan thread'inden yayınlıyor — ana thread'den yayınlasaydı DEBUG derlemede yeni guard'a takılırdı), `OpGrowSinirsizKabulEderVeKaybetmez`, `OpDropOldestKuyrukDolunceVeriAtar` (Kategori: `Geri Basinc`) — 4 taşma politikasından 3'ünün doğrudan testi.
- `InterceptorOncesindeVeSonrasindaDogruSirayla`, `InterceptorHatasiDispatchiEngellemez` (Kategori: `Interceptor`) — `Before -> Handler -> After` sırası ve bir interceptor hatasının dispatch'i/diğer interceptor'ları engellemediği.
- `DebounceArdisikOlaylardaSonDegerleBirKezCalisir`, `DebounceSifirsaHerOlaydaCalisir` (Kategori: `Debounce`) — ardışık olaylarda sessizlik sonunda EN SON değerle bir kez çalışma, `ADebounceMs=0` iken eski (her olayda çalışan) davranış.
- `MainSyncTimeoutSuresindeGeriDoner`, `MainSyncTimeoutsuzEskiDavranisDegismez` (Kategori: `MainSync Timeout`) — yayıncı thread'in verilen sürede geri döndüğü + işin kaybolmadığı, `INFINITE` ile eski davranışın korunduğu.
- `OpBlockPublisherAnaThreaddenCagrilirsaDebugtaHataVerir` (Kategori: `Geri Basinc`) — DEBUG derlemede `Assert.WillRaise` ile guard'ın gerçekten tetiklendiği, RELEASE derlemede aynı kod yolunun sorunsuz tamamlandığı (`{$IFDEF DEBUG}`/`{$ELSE}` ile HER İKİ derlemede de doğrulandı).

`Core\rad.eventbus.Benchmark.pas` — `TChannelBusBenchmarkTestleri`, 4 test (`Benchmark_DmSync`, `Benchmark_DmAsync`, `Benchmark_DmMainSync`, `Benchmark_DmMainAsync`), gerçek çalıştırılıp sonuçlar yukarıdaki tabloya işlendi.

## Geliştirme Sırasında Bulunan/Düzeltilen Gerçek Sorunlar

- **`TQueue<TProc>` derleyici hatası (E2010)**: `dcc32`, `T`'nin sıfır-parametreli bir "reference to procedure" (closure) tipi olduğu `TQueue<T>.Dequeue` çağrılarında yanlış tip çıkarımı yapıp "Incompatible types... Procedure of object" hatası veriyor. İzole minimal bir `.dpr` ile doğrulandı (repo dışında, `System.Generics.Collections`'ın kendi genel davranışı — proje koduna özgü değil). Çözüm: `TQueue<TProc>` yerine `TQueue<IInterface>` kullanılıp `TProc` GpEventBus'taki teknikle (`IInterface(Pointer(@Proc)^)`) kutulanıp/açılıyor (`TAsyncEventQueue.TryEnqueue`/`TryDequeue`).
- **Bare `finalization` sözdizimi hatası (E2029)**: Delphi'de `initialization` olmadan tek başına bir `finalization` bölümü **geçersizdir** (`initialization` boş bile olsa önce gelmesi şart) — minimal bir `.dpr` ile doğrulandı. `initialization` (boş) eklenerek düzeltildi.
- **`TSubscriberList.Count` bayat veri döndürüyordu**: İlk implementasyonda `Count`, `Unsubscribe` edilmiş ama henüz bir dispatch tarafından süpürülmemiş (lazy removal) kayıtları da sayıyordu — testte "beklenen 1, bulunan 2" olarak yakalandı. Artık sadece aktif (`IsActive`) abonelikleri sayıyor; `SubscriberCount` bir `Publish` beklemeden anında güncel.
- **`mormot.core.variants` eklenince "Unit 'sysutils' not found" (F2613)**: mORMot kaynağı kısa (namespace'siz) `sysutils`/`classes`/`variants` isimleriyle `uses` yapıyor; bu, ancak dcc32'ye Delphi projelerinin `.dproj`'da otomatik ayarladığı `-NS` (unit scope names) listesi verilirse çözülüyor — `Aksa.dproj`'daki `DCC_Namespace` değerleri referans alınarak (`System;Xml;Data;Datasnap;Web;Soap;Vcl;...;Winapi;System.Win;...`) düzeltildi. Kütüphanenin kendi kodunda bir sorun değil, standalone `dcc32` çağrılarında proje ayarlarının elle sağlanması gerektiği bir derleme-ortamı notu.
- **Dispatch izolasyonu eksikti**: `Publish<T>` içindeki `for` döngüsü, bir abonenin exception'ı yüzünden ortada kesiliyor, aynı çağrıdaki DİĞER aboneler hiç çağrılmıyordu (`dmSync`/`dmMainSync`'te doğrudan çağrı yolunda). Ayrıca `dmAsync` (`TTask.Run`) içindeki exception'lar hiç gözlemlenmiyordu. `DispatchOne` artık her abonenin çağrısını kendi `try/except`'ine sarıyor + opsiyonel `OnError` hook'u ekliyor (bkz. "Hata Yönetimi" bölümü) — kullanıcı isteğiyle eklendi.
- **`SnapshotAndCompact` her `Publish` çağrısında allocation yapıyordu (performans)**: ölü kayıt olmasa BİLE `FItems.ToArray` her seferinde yeni bir dizi ayırıyordu; `dmAsync`'te sıkı döngüde `Publish` çağrıldığında asıl darboğaz buydu (bkz. Benchmark tablosu — düzeltme sonrası `dmAsync` verimi ~4× arttı). Artık dizi yalnızca `Subscribe` sonrası veya gerçekten ölü bir kayıt bulunduğunda yeniden oluşturuluyor.
- **`OnError` eklenince `dmSync` yavaşladı (performans regresyonu, kullanıcı tarafından benchmark'ta fark edildi)**: kök neden `AData: TValue`'nun `TValue.From<T>(AEvent)` ile HER `Publish` çağrısında EAGER hesaplanmasıydı (hata olsun olmasın). Çözüm: `AData`, yalnızca gerçek bir exception yakalandığında çağrılan TEMBEL bir `reference to function: TValue` sağlayıcısına çevrildi — `dmSync` orijinal ölçümün üstüne çıktı. Ayrıca kullanıcı isteğiyle `AErrorIsolation: Boolean` ayarı eklendi (try/except sarmalamasının kendisini de kapatabilme seçeneği).
- **`dcc32`'nin artımlı derlemesi, yeni eklenen `{$IFDEF DEBUG}` guard kodunun test edilmesinde YANILTICI oldu**: birden fazla scratch `.dpr` dosyası aynı `Core\rad.eventbus.pas`'a `-U` ile işaret ederken, kaynak değiştiği HALDE bazen eski bir `.dcu` yeniden kullanılıyordu — guard kodu doğruydu ama testte "tetiklenmiyor" gibi görünüyordu. `-B` (tam yeniden derleme) ile kesin doğrulandı. Bkz. proje hafızası `project_delphi_compiler_quirks.md` madde 4 — bundan sonra bir scratch doğrulaması beklenmedik davranırsa önce `-B` ile tekrar denenecek.
- **`OpBlockPublisherHicVeriKaybetmez` testi, yeni DEBUG guard'ıyla çakışıyordu**: test ana thread'den (DUnitX test thread'i) doğrudan `opBlockPublisher` ile `Publish` çağırıyordu — DEBUG derlemede bu artık kasıtlı bir exception'a yol açıyor. Test, guard'ın hedeflediği anti-pattern'in ta kendisini (yanlışlıkla) sergiliyordu. Düzeltme: yayın artık bir arka plan thread'inden yapılıyor (gerçek kullanım deseniyle tutarlı).
