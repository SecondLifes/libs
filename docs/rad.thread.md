---
original_path: "D:\dev\Delphi\00-Lib\rad.thread.md"
source: 00-lib
copied_at_utc: 2026-07-02T17:23:22Z
sha256: b43b43a534ea27e1d0755e227f0774dc29f28de303556b5a4aa6c760ade830ed
---

# rad.thread.pas — `TRadTask` Kullanım Kılavuzu ve İnceleme Sonucu

> **Revize: 2026-07-09 (2. tur)** — Bağımsız iki inceleme dosyasından ("1.md"/"2.md")
> doğrulanan 10 ek bug düzeltildi (`WhenAll` OnFinally zincirleme, `ThrowIfCancelled`
> istisna tipi, `CheckTimedOut`/`ElapsedMs` erken-çağrı koruması, `FData` kilidi,
> `Wait()` cross-thread güvenliği, nil `AProc` kontrolü, `ReportProgress` clamp +
> `UseQueue`, `SetSmartDispatch` deprecated). Süreçte gerçek bir Delphi derleyici
> tuhaflığı bulundu (`project_delphi_compiler_quirks.md` #7). Ayrıntılar için bkz.
> aşağıdaki "✅ 2026-07-09 (2. tur)" bölümü.
>
> **Revize: 2026-07-09 (1. tur)** — SafeThread4D (`src\vendor\eduardoparaujo\SafeThread4D`)
> ile karşılaştırmalı inceleme sonucu 5 concurrency/lifecycle bug'ı + 1 ek bulgu
> düzeltildi; `OnTimeout`, `CheckTimedOut`, `TimedOut`, `ERadTaskCancelled`/
> `ERadTaskTimeout`/`ERadTaskAlreadyStarted` eklendi. Ayrıntılar için bkz. "✅ 2026-07-09
> (1. tur)" bölümü.

## Ne İşe Yarar

`TRadTask`, arka planda (background thread) iş çalıştırıp sonucunu UI thread'e güvenli şekilde taşıyan, fluent (zincirleme) API'li bir görev motorudur. `TThread.CreateAnonymousThread` üzerine kurulu; callback'leri (`OnSuccess`/`OnError`/`OnCancel`/`OnTimeout`/`OnFinally`/`After`) her zaman `TThread.Synchronize` ile UI thread'e dağıtır (`OnProgress` hariç — o `Queue` ile asenkron kalır), böylece kullanıcı kodu hiçbir zaman elle `Synchronize` yazmak zorunda kalmaz ve callback sırası deterministiktir.

## Tipler

| Tip | Ne işe yarar |
|---|---|
| `TRadTaskProc = TProc<TRadTask>` | Tüm callback'lerin (Run, Before, OnSuccess, ThenBy, ...) ortak imzası — parametre olarak görevin kendisini (`t`) alır. |
| `TCOMThreadModel` (`ctmNone`/`ctmApartment`/`ctmMultiThreaded`) | Arka plan thread'inde COM başlatma modeli (`SetCOM` ile kullanılır). |
| `IRadCancelToken` | Salt-okunur iptal durumu (`IsCancelled`, `ThrowIfCancelled`) — göreve `WithCancel` ile verilir. `ThrowIfCancelled` artık `ERadTaskCancelled` fırlatır (RTL'in `EOperationCancelled`'ı DEĞİL) — `TRadTask`'ın kendi cancel-yakalama yolu ile uyumlu, `OnCancel`'a yönlenir. |
| `IRadCancellationSource` | İptal kaynağı; `Cancel`/`Reset` ile tetiklenir, `.Token` ile `IRadCancelToken`'ı verir (`NewCancellationSource` ile üretilir). |
| `ERadTaskCancelled` | `CheckCancelled(True)` tarafından fırlatılır — generic `Exception` handler'dan önce yakalanıp `OnCancel`'a yönlendirilir (retry/`OnError` tetiklenmez). |
| `ERadTaskTimeout` | `CheckTimedOut(True)` tarafından fırlatılır — aynı şekilde `OnTimeout`'a yönlendirilir. |
| `ERadTaskAlreadyStarted` | Aynı `TRadTask` ikinci kez `Start`/`Wait` edilirse fırlatılır (çift-başlatma koruması). |
| `ERadTaskInvalidArgument` | `Create`'e nil `AProc` geçilirse fırlatılır. |

## `TRadTask` Metodları

| Metod | Parametreler | Ne işe yarar |
|---|---|---|
| `Create(AProc)` | `AProc: TRadTaskProc` — arka planda çalışacak iş | Görevi oluşturur, henüz başlatmaz. `AProc` nil ise `ERadTaskInvalidArgument` fırlatır. |
| `SetPreDelay(AMs)` / `SetPostDelay(AMs)` | Milisaniye | İş öncesi/sonrası bekleme (arka plan thread'inde, UI'ı bloklamaz). |
| `SetRepeat(N, DelayMs)` | Tekrar sayısı, aralardaki bekleme | İşi `N` kez, aralarda `DelayMs` bekleyerek tekrarlar. |
| `SetRetry(N, DelayMs)` / `Retry` (alias) | Deneme sayısı, aralardaki bekleme | Exception olursa `N` kere daha dener. |
| `SetThrottle(AMs)` | Milisaniye (vars. 500) | `ReportProgress` çağrılarını en az `AMs` aralıkla sınırlar (son `%100` her zaman geçer). |
| `SetSmartDispatch(AEnabled)` | Boolean | **[NO-OP, 2026-07-09]** Artık hiçbir etkisi yok — tüm yaşam-döngüsü callback'leri her zaman senkron (`Synchronize`) çalışır. Yalnızca mevcut `.SetSmartDispatch(...)` zincirlerini kırmamak için korunuyor. |
| `WithTimeout(AMs)` | Milisaniye | Süreyi ayarlar; kontrol **cooperative**'tir (watchdog thread YOK) — `InternalExecute`'un checkpoint'lerinde `CheckTimedOut` ile denetlenir. Süre dolunca `OnCancel` DEĞİL, ayrı `OnTimeout` tetiklenir. |
| `SetName(AName)` / `Named` (alias) | string | Görev adı — loglarda ve hata mesajlarında görünür. |
| `SetTag(ATag)` | Integer | Kullanıcı tanımlı serbest alan. |
| `SetCOM(AModel)` | `TCOMThreadModel` | Arka plan thread'inde COM başlatılmasını ister. |
| `Before(A)` | `TRadTaskProc` | UI thread'de, arka plan başlamadan önce senkron çalışır (örn. `Edit1.Text` okumak). |
| `After(A)` | `TRadTaskProc` | Arka plan işi bittikten hemen sonra, sonuç callback'lerinden ÖNCE çalışır. |
| `OnSuccess(A)` / `OnError(A)` / `OnCancel(A)` / `OnTimeout(A)` / `OnFinally(A)` | `TRadTaskProc` | Sırasıyla: başarı, hata, iptal, zaman aşımı, ve her durumda-en-son çalışan UI callback'leri. Bunlardan tam olarak biri (Success/Error/Cancel/Timeout) tetiklenir; `OnFinally` her zaman en son, koşulsuz çalışır. |
| `OnProgress(A)` | `TRadTaskProc` | `ReportProgress` çağrıldığında (throttle'a tabi) UI thread'de tetiklenir. |
| `ThenBy(A)` | `TRadTaskProc` | Ana işten sonra, arka planda çalışan ek adım — `t.StepResult` ile bir önceki adımın sonucunu devralır. |
| `WithCancel(AToken)` | `IRadCancelToken` | Görevi harici bir iptal kaynağına bağlar. |
| `SetData(AKey, AValue)` | string, Variant | Görevle taşınan anahtar-değer verisi (tipik kullanım: `Before` içinde UI'dan veri toplayıp `Run`'a taşımak). `FDataLock` ile korunur — birden fazla thread'den eşzamanlı çağrılması güvenlidir. |
| `Cancel` | — | Görevi iptal eder (bekleyen delay'leri de anında keser; `FCancelEvent`'i sinyaller — tamamlanma sinyaline dokunmaz). |
| `CheckCancelled(RaiseException)` | Boolean (vars. False) | İptal edilmiş mi kontrol eder; `True` verilirse iptalse `ERadTaskCancelled` fırlatır (Abort/EAbort DEĞİL). `Run`/`ThenBy` içinde döngülerde kullanılır. |
| `CheckTimedOut(RaiseException)` | Boolean (vars. False) | `CheckCancelled` ile simetrik: `WithTimeout` süresi dolmuş mu kontrol eder; `True` verilirse dolmuşsa `ERadTaskTimeout` fırlatır. Görev henüz başlamadıysa her zaman `False` döner (önceden sistem çalışma süresini — uptime'ı — yanlışlıkla süre aşımı sayabiliyordu). |
| `ReportProgress(APct, AMsg, UseQueue)` | Yüzde, mesaj, kuyruk kullan mı | İlerleme bildirir (throttle'a tabi), `OnProgress`'i tetikler. `APct` 0-100 aralığına kırpılır. `UseQueue` artık GERÇEKTEN kullanılır (`False` verilirse `OnProgress` senkron/`Synchronize` ile çalışır — önceden bu parametre yok sayılıp her zaman Queue kullanılıyordu). |
| `Start` | — | Arka planı başlatır, sonucu beklemez (fire-and-forget); iş bitince nesne kendini otomatik `Free` eder. Aynı görev ikinci kez `Start`/`Wait` edilirse `ERadTaskAlreadyStarted` fırlatır. |
| `Wait` | — | Arka planı başlatır ve UI donmadan (mesaj pompalayarak) sonucu bekler; bitince kendini `Free` eder. `OnFinally` KESİN tamamlanmadan dönmez. Aynı görev ikinci kez `Start`/`Wait` edilirse `ERadTaskAlreadyStarted` fırlatır. Main thread DIŞINDAN çağrılırsa (ör. başka bir arka plan thread'inden) `Application.ProcessMessages` KULLANILMAZ — doğrudan bloklayarak bekler (VCL güvenliği). |
| `InUI(AProc)` (class) | `TProc` | Verilen işi her zaman UI thread'inde çalıştırır (çağıran zaten UI'daysa direkt, değilse kuyruklu). |
| `WhenAll(ATasks)` (class) | `array of TRadTask` | Verilen görevlerin hepsini başlatıp hepsi bitene kadar (event tabanlı, busy-wait'siz) bekleyen birleşik bir görev döndürür. Alt görevlerin ÖNCEDEN tanımlanmış `OnFinally`'leri artık EZİLMEZ — zincirlenir (önce orijinal `OnFinally`, sonra sayaç azaltma çalışır). |
| `GetData(AKey, ADefault)` | string, Variant | `SetData` ile konan veriyi okur. `FDataLock` ile korunur. |
| `ElapsedMs` | — | Görevin (başlangıçtan şu ana ya da bitişe kadar) geçen süresi. Görev henüz `Start`/`Wait` edilmediyse `0` döner (önceden `FStartTime`'ın varsayılan `TDateTime` değeri — 30.12.1899 — üzerinden anlamsız derecede büyük bir süre hesaplanabiliyordu). |
| `NewCancellationSource` (global fonksiyon) | — | Yeni bir `IRadCancellationSource` üretir. |

Salt-okunur özellikler: `ID`, `Name`, `Tag`, `Cancelled`, `Success`, `Progress`, `ProgressMsg`, `ErrorMsg`, `StepResult` (okunur/yazılır), `IsRunning`, `IsDone`, `TimedOut`.

## Kullanım Örnekleri

**1. Basit fire-and-forget görev:**
```pascal
TRadTask.Create(procedure(t: TRadTask) begin
    t.StepResult := TValue.From<TDataSet>(DB.Sorgu('SELECT * FROM Musteri'));
  end)
  .Named('MusteriYukle')
  .OnSuccess(procedure(t: TRadTask) begin
    Grid.DataSource.DataSet := t.StepResult.AsType<TDataSet>;
  end)
  .OnError(procedure(t: TRadTask) begin ShowMessage(t.ErrorMsg) end)
  .Start;
```

**2. PreDelay + Repeat + Retry:**
```pascal
TRadTask.Create(procedure(t: TRadTask) begin SenkronEt end)
  .SetPreDelay(300)          // 300ms sonra başla
  .SetRepeat(5, 1000)        // 5 kez, aralarda 1sn bekleyerek tekrarla
  .Retry(3, 500)             // her denemede hata olursa 3 kez daha dene
  .Start;
```

**3. Dahili ve harici iptal:**
```pascal
var Source := NewCancellationSource;
var Task := TRadTask.Create(procedure(t: TRadTask) begin
    while not t.CheckCancelled do
    begin
      IsSurBirim();
      Sleep(50);
    end;
  end)
  .WithCancel(Source.Token)
  .OnCancel(procedure(t: TRadTask) begin Log('İptal edildi') end);
Task.Start;
...
Task.Cancel;          // doğrudan iptal
// veya
Source.Cancel;         // harici token üzerinden iptal
```

**4. `ThenBy` zinciri (adımlar arası tipli veri aktarımı):**
```pascal
TRadTask.Create(procedure(t: TRadTask) begin
    t.StepResult := TValue.From<Integer>(10);
  end)
  .ThenBy(procedure(t: TRadTask) begin
    var v := t.StepResult.AsType<Integer>;
    t.StepResult := TValue.From<string>('Sonuc=' + IntToStr(v * 2));
  end)
  .OnSuccess(procedure(t: TRadTask) begin
    ShowMessage(t.StepResult.AsType<string>); // 'Sonuc=20'
  end)
  .Start;
```

**5. `WhenAll` — birden çok görevi paralel çalıştırıp hepsini bekle:**
```pascal
var T1 := TRadTask.Create(procedure(t: TRadTask) begin Islem1 end);
var T2 := TRadTask.Create(procedure(t: TRadTask) begin Islem2 end);
TRadTask.WhenAll([T1, T2])
  .OnSuccess(procedure(t: TRadTask) begin ShowMessage('Hepsi bitti') end)
  .Start;
```

**6. İlerleme bildirimi (throttle'lı):**
```pascal
TRadTask.Create(procedure(t: TRadTask) begin
    for var i := 1 to 100 do
    begin
      t.ReportProgress(i, Format('%d/100', [i]));
      Sleep(20);
    end;
  end)
  .SetThrottle(200)  // en az 200ms arayla UI'a bildir
  .OnProgress(procedure(t: TRadTask) begin ProgressBar1.Position := t.Progress end)
  .Start;
```

**7. `Wait` — UI donmadan senkron gibi bekleme:**
```pascal
TRadTask.Create(procedure(t: TRadTask) begin t.StepResult := TValue.From<Integer>(UzunIslem) end)
  .WithTimeout(5000)
  .Wait; // UI mesaj pompalanır, ama fonksiyon dönene kadar akış burada bekler
```

**8. `WithTimeout` + `OnTimeout` — süre dolunca `OnCancel` DEĞİL `OnTimeout` tetiklenir:**
```pascal
TRadTask.Create(procedure(t: TRadTask) begin
    while not (t.CheckCancelled or t.CheckTimedOut) do
      UzunAdim; // cooperative — checkpoint'lerde kontrol edilir, watchdog thread yok
  end)
  .WithTimeout(3000)
  .OnTimeout(procedure(t: TRadTask) begin Log('Zaman aşımı: ' + t.ElapsedMs.ToString + 'ms') end)
  .OnCancel(procedure(t: TRadTask) begin Log('Kullanıcı iptal etti') end) // ayrı yol, timeout'ta tetiklenmez
  .Start;
```

---

## Test Kapsamı

`src\test\unit\rad.thread.Tests.pas` (DUnitX, `TRadTaskTestleri`, `src\test\RunTests.dpr`/`.dproj`'a bağlı) — **37 test, tümü gerçek `dcc32` derlemesiyle geçiyor** (son doğrulama: 2026-07-09, `src\test\run_tests.bat`; proje genelinde 111 test, 110 geçti, 1 hata — o hata `rad.eventbus.Benchmark`'ta, bu dosyayla ilgisiz, 0 leak). Not: test eklerken eskiler SİLİNMEZ (bkz. `dunitx_test_style.md` madde 4) — bu yüzden sayı sadece artar.

**Temel davranış:** `OnGeciktirmeSuresiUygulanir`, `SonGeciktirmeSuresiUygulanir`, `TekrarTamSayidaCalisir`, `HataliGorevYenidenDenenirVeHataVerir`, `TumGorevleriBeklerVeTamamlar` (`WhenAll`), `AdimlarArasiSonucTasinir` (`ThenBy`), `EszamanliCokGorevBasariylaTamamlanir` (25 eşzamanlı görev), `IlerlemeBildirimiKisitlanir` (throttle), `BeklemeCagrisiEsZamanliCalisir` (`Wait`), `CallbackHatasiYutulurVeZincirDevamEder`.

**İptal (`Category('İptal')`):** `OnGeciktirmeSirasindaIptalEdilebilir`, `YenidenDenemeGeciktirmesindeIptalEdilebilir`, `HariciTokenIleIptalEdilebilir`, `TekrarGeciktirmesindeIptalEdilebilir`, `AcikIptalIstisnasiHataDegilIptalSayilir`, `BaslamadanOnceIptalEdilenGorevCalismaz`, `CheckCancelledYanlisPozitifVermez`, `AdimZincirindeIptalKalanAdimlariAtlar`.

**Zaman Aşımı (`Category('Zaman Aşımı')`):** `ZamanAsimindaOnTimeoutTetiklenir`, `YenidenDenemeSirasindaZamanAsiminaUgrayanGorevTekrarlanmaz`, `TimeoutAyarlanmamisGorevZamanAsimayaUgramaz`.

**Kök bug regresyon testleri (2026-07-09 1. tur, bkz. aşağıdaki bölüm):** `BeklemeSirasindaIptalOnFinallyTamamlanmasiniGarantiEder` (bug #1/#4 — `Wait()`, `OnFinally` tamamlanmadan asla dönmez), `CalismaVeTamamlanmaDurumuDogruYansir` (bug #3 — `IsRunning`/`IsDone`), `BasariliGorevdeSadeceOnSuccessTetiklenir` (Success/Error/Cancel/Timeout karşılıklı dışlama), `IkinciBaslatmaCagrisiIstisnaFirlatir` + `IkinciWaitCagrisiDaIstisnaFirlatir` (çift-başlatma koruması), `WhenAllBasarisizAltGorevIleTamamlanir`, `WhenAllBosDiziIleAnindaTamamlanir`.

**2. tur ek-bug regresyon testleri (2026-07-09, "1.md"/"2.md" incelemesi):** `OncekiOnFinallyEzilmezZincirlenir` (`WhenAll` OnFinally zincirleme + `MakeChainedFinally` closure düzeltmesi), `HariciTokenThrowIfCancelledOnCancelTetikler` (`ThrowIfCancelled` → `ERadTaskCancelled`), `CheckTimedOutBaslamadanOnceYanlisPozitifVermez`, `NilProcIleOlusturmaIstisnaFirlatir`, `IlerlemeYuzdesiAralikDisindaKirpilir`, `IlerlemeUseQueueFalseSenkronCalisir`, `EsZamanliSetDataGetDataHataVermez` (`FDataLock` stresi), `ArkaPlanThreadindenWaitCokmez`, `ElapsedMsBaslamadanOnceSifirDoner`.

Not: `CallbackHatasiYutulurVeZincirDevamEder` ve retry/hata testleri kasıtlı `raise` içerir — IDE debugger'da "Stop on Delphi Exceptions" açıksa debugger durabilir, exe'den veya Run Without Debugging ile çalıştır.

## ✅ 2026-07-09 (1. tur) — SafeThread4D karşılaştırmalı bug düzeltmeleri

Kullanıcı tarafından bildirilen 5 concurrency/lifecycle bug'ı doğrulandı ve
`src\vendor\eduardoparaujo\SafeThread4D\src\SafeThread4D.pas` (aynı problem
sınıfını çözen bir vendor kütüphanesi) ile karşılaştırmalı incelenerek
düzeltildi. Ayrıca planlama sırasında 1 ek bulgu (retry sırasında iptal/timeout
gelirse dış repeat döngüsünün kırılmaması) tespit edilip düzeltildi. Gerçek
`dcc32` derlemesi + scratch doğrulama programı (11/11 senaryo) + DUnitX
(28/28 test) ile doğrulandı.

| # | Bug | Kök neden | Çözüm |
|---|---|---|---|
| 1 [Kritik] | `Wait()` sırasında `Cancel()` gelirse arka plan bitmeden `Free` çağrılabiliyordu (use-after-free riski) | Tek `FWaitEvent`, hem cancel hem completion sinyali | `FCancelEvent` (iptal + kesilebilir bekleme) / `FCompletedEvent` (SADECE tüm callback'ler bittikten sonra set edilir) ayrımı |
| 2 [Kritik] | Timeout watchdog thread, `Self` free edildikten sonra `FDone`'a dokunabiliyordu | `Sleep(Timeout)` sonrası `Self` yakalayan ayrı thread | Watchdog tamamen kaldırıldı; timeout `InternalExecute`'un checkpoint'lerinde cooperative `CheckTimedOut` ile kontrol ediliyor |
| 3 [Yüksek] | `IsRunning`/`IsDone` kilitsiz okunuyordu, yazımlar kilitliydi | Tutarsız senkronizasyon | `FCancelledInt`/`FSuccessInt`/`FRunningInt`/`FDoneInt`/`FTimedOutInt: Integer`, sadece `TInterlocked` ile erişiliyor |
| 4 [Yüksek] | `OnFinally` async kuyruğa alınıyordu, hemen ardından completion sinyali set ediliyordu | `FireCallbackSmart`'ın Queue/Synchronize karışımı | Tüm yaşam-döngüsü callback'leri artık her zaman `Synchronize`; `OnProgress` hariç |
| 5 [Orta] | `Abort`/`EAbort`, generic `except on E: Exception` tarafından normal hata sayılıyordu | Cancel/timeout için özel exception yoktu | `ERadTaskCancelled`/`ERadTaskTimeout`, generic handler'dan ÖNCE ayrı `on E:` ile yakalanıyor |
| Ek bulgu | Retry-bekleme sırasında iptal/timeout gelirse dış `for I := 1 to FRepeatCount` döngüsü kırılmıyordu — bir sonraki repeat turunda `FProc` fazladan bir kez daha çalışıyordu | `Break`, sadece iç `repeat...until` döngüsünü kırıyordu | `until` sonrası dış döngüde de iptal/timeout kontrolü eklendi |

**Yeni genel API:** `OnTimeout(A)` (fluent), `CheckTimedOut(RaiseException)` (public), `TimedOut` (property); `ERadTaskCancelled`/`ERadTaskTimeout`/`ERadTaskAlreadyStarted` (exception sınıfları). **Davranış değişiklikleri:** `After`/`OnSuccess`/`OnError`/`OnCancel`/`OnFinally` artık her zaman senkron (`SetSmartDispatch` no-op); ikinci `Start()`/`Wait()` çağrısı artık `ERadTaskAlreadyStarted` fırlatır; `CheckCancelled(True)` artık `Abort` değil `ERadTaskCancelled` fırlatır; zaman aşımında artık `OnCancel` değil `OnTimeout` tetiklenir.

---

## ✅ 2026-07-09 (2. tur) — Bağımsız inceleme dosyalarından ("1.md"/"2.md") doğrulanan 10 bug

Kullanıcı bu turda "inceleme yap" + iki serbest-adlı dosya (`1.md`, `2.md` — bkz.
`feedback_dikkat_workflow.md`) verdi; ikisi de `rad.thread.pas`'ı bağımsız olarak
inceleyip SafeThread4D/Dext ile karşılaştırmıştı. 1. turun 5-bug çerçevesine
takılıp kaçırılan 10 gerçek bug tek tek doğrulanıp düzeltildi. Gerçek `dcc32`
derlemesi + genişletilmiş scratch programı (25/25 senaryo) + DUnitX (37/37,
proje geneli 111 test/110 geçti/1 ilgisiz hata/0 leak) ile doğrulandı.

| # | Bug | Kök neden | Çözüm |
|---|---|---|---|
| 1 [Kritik] | `WhenAll`, alt görevin önceden tanımlı `OnFinally`'sini sessizce EZİYORDU | `task.OnFinally(...)` doğrudan atama, zincirleme yok | `MakeChainedFinally` — önce orijinal callback, sonra sayaç azaltma (bkz. derleyici tuhaflığı notu) |
| 2 [Yüksek] | `TRadCancellationImpl.ThrowIfCancelled`, `ERadTaskCancelled` değil RTL'in `EOperationCancelled`'ını fırlatıyordu — `TRadTask`'ın kendi handler'ı yakalamıyor, `OnError`/retry tetikleniyordu | İki paralel cancel-exception yolu senkronize değildi | `ThrowIfCancelled` artık `ERadTaskCancelled` fırlatıyor |
| 3 [Yüksek] | `CheckTimedOut`, görev `Start`/`Wait` edilmeden ÖNCE çağrılırsa `FRunStartTick=0` yüzünden sistem çalışma süresini (uptime) süre aşımı sanabiliyordu | Başlangıç durumu (0) kontrol edilmiyordu | `FRunStartTick=0` veya `FRunningInt=0` iken doğrudan `False` dönülür |
| 4 [Yüksek] | `FData` (`SetData`/`GetData`) hiç kilitsiz — proje daha önce TAM OLARAK bu sınıf bir hatadan (mORMot dynamic array + eşzamanlı erişim → AV, bkz. `project_no_more_tdynarrayhashed.md`) zarar görmüştü | `TDocVariantData`'ya doğrudan, korumasız erişim | `FDataLock: TLightLock` eklendi, `SetData`/`GetData` kilitli |
| 5 [Yüksek] | `Wait()`, main thread dışından çağrılırsa `Application.ProcessMessages` (VCL'de sadece main thread'de güvenli) çağrılıp çökme riski taşıyordu | Çağıran thread kontrol edilmiyordu | Main thread değilse `FCompletedEvent.WaitFor(INFINITE)` (doğrudan blok) kullanılır |
| 6 [Orta] | Constructor'a nil `AProc` geçilirse anlaşılmaz bir AV ile karşılaşılıyordu | Nil kontrolü yoktu | `ERadTaskInvalidArgument` ile erken, anlaşılır hata |
| 7 [Orta] | `ReportProgress`'e `-10`/`150` gibi aralık dışı değerler geçilebiliyordu | Clamp yoktu | `APct`, 0-100 aralığına kırpılıyor |
| 8 [Orta] | `ReportProgress`'in `UseQueue` parametresi TAMAMEN ÖLÜYDÜ — kod her zaman sabit `True` kullanıyordu | Parametre hiç okunmuyordu | `FireCallback(FOnProgress, UseQueue)` — artık gerçekten kullanılıyor |
| 9 [Düşük] | `SetSmartDispatch` artık no-op ama bu derleyici seviyesinde işaretlenmemişti | `deprecated` direktifi yoktu | Metoda `deprecated` mesajı eklendi |
| 10 [Düşük] | `FData`/`StepResult` thread-safety'si dokümante edilmemişti | — | Alan yorumları + birim başlığı güncellendi |

**Süreçte bulunan gerçek Delphi derleyici tuhaflığı (bkz. `project_delphi_compiler_quirks.md` #7):**
`WhenAll`'un ilk düzeltme denemesinde, bir döngü İÇİNDE oluşturulan wrapper
closure'ın (kendisi başka bir closure'ın — aggregate task'ın `FProc`'unun —
içine iç içe geçmişti) döngü-lokal `originalFinally` değişkenini doğru
yakalamadığı tespit edildi — klasik "loop variable capture" bug'ının inline-`var`
ile düzeltilmiş hali bile bu spesifik iç-içe-closure senaryosunda çalışmıyordu.
Bağımsız, `TRadTask`'sız minimal bir `.dpr` ile (sadece closure + `Writeln`)
doğrulanıp uygulama mantığı hatası olmadığı kanıtlandı. Çözüm: wrapper closure'ı
ayrı, adlı bir `class function` (`MakeChainedFinally`) içine taşımak — parametre
yakalayan closure'lar güvenilir çalışıyor (bu dosyanın geri kalanında zaten
kullanılan desen).

**Yeni genel API:** `ERadTaskInvalidArgument` (exception sınıfı). **Davranış
değişiklikleri:** `ThrowIfCancelled` artık `ERadTaskCancelled` fırlatır;
`WhenAll` alt görevlerin önceki `OnFinally`'lerini artık silmez; `ReportProgress`
clamp uygular ve `UseQueue`'yu gerçekten kullanır; `Wait()` main thread dışından
çağrılırsa `Application.ProcessMessages` kullanmaz; `Create(nil)` artık
`ERadTaskInvalidArgument` fırlatır.

---

## ✅ Doğrulandı ve düzeltildi

### 2. `TThread.Queue(nil, ...)` → `ForceQueue`
`InUI` ve `FireCallback` içindeki `TThread.Queue(nil, ...)` çağrıları `TThread.ForceQueue(nil, ...)` ile değiştirildi (main thread'den çağrılsa bile her zaman kuyruklanır).

### 3. `ProcessMessages` (PeekMessage+Sleep) kaldırıldı
`PreDelay`/`PostDelay` artık background thread'de `FWaitEvent.WaitFor(...)` ile bekliyor (main thread'e hiç dokunmuyor). `Wait` metodundaki elle yazılmış mesaj pompası `Application.ProcessMessages` ile değiştirildi. Kullanılmayan `ProcessMessages` private metodu kaldırıldı.

### 5. `FWaitEvent` — retry sırasında cancellation kaçırma bug'ı
`InternalExecute`'daki retry `repeat..until` bloğunda, `Cancel()` retry-delay beklerken tetiklenirse artık `CheckCancelled` tekrar kontrol ediliyor ve gereksiz ek deneme yapılmıyor.

### 8. `WhenAll` busy-wait kaldırıldı
`Sleep(10)` polling yerine, alt task'ların `OnFinally`'i ile tetiklenen paylaşımlı `TInterlocked` sayaç + `TEvent` kullanılıyor.

### 10. Thread-safe olmayan property okumaları
`Progress`/`ProgressMsg` (`FProgressLock`) ve `ErrorMsg`/`Success`/`Cancelled` (`FStatusLock`) artık kilit korumalı getter fonksiyonları üzerinden okunuyor; ilgili yazımlar da aynı kilitlerle sarmalandı.

### 15 (kısmen) — self-free / callback güvenliği
`FireCallback`'in kuyruklanan/senkronize edilen callback gövdesi `try/except` ile sarmalandı; hedef nesne veya form artık yoksa fırlayan istisna mesaj döngüsüne sızmıyor, log'a yazılıyor. (Otomatik `Free` mimarisinin `IInterface` tabanlıya çevrilmesi — mimari karar, uygulanmadı.)

---

## ❌ Doğrulandı, yanlış/kanıtsız bulundu — aksiyon alınmadı

### 1. `TProc<T>` tanımı — **yanlış iddia**
`System.SysUtils.pas:5108` → `TProc<T> = reference to procedure (Arg1: T);` doğrudan RTL kaynağından teyit edildi. `TRadTaskProc = TProc<TRadTask>` doğru kullanım, değişiklik yapılmadı.

### 4. `CoInitialize` tekrar çağrımı — **kodda yok**
Her `Start`/`Wait` yeni bir OS thread'i açıyor; `InitCOM`/`UninitCOM` her thread ömründe tam bir kez, düzgün eşleşiyor.

### 6. `TSynLog` boş olabilir — **yanlış iddia**
mORMot2 `TSynLog.Add` kendi kendini başlatan bir singleton (mormot.core.log.pas:4625); harici init gerekmez.

### 9. Cancellation token yetersiz
Poll tabanlı (cooperative) iptal modeli bug değil, .NET `CancellationToken` ile aynı felsefe. İstenirse ayrı bir görev olarak event tabanlı bildirim eklenebilir.

### 11 / 14. `TDocVariantData` yerine `TDictionary`/`TValueMap`
Dosyanın kendi tasarım amacı ("mORMot2 entegrasyonlu") bu seçimi bilinçli yapmış; performans iddiası ölçümsüz. Değişiklik yapılmadı.

### 12. Genel thread modeli desteği
Yeni özellik talebi, hata değil — kapsam dışı bırakıldı.

### 7. `TCallbackKind` enum önerisi
Sadece okunabilirlik önerisi, opsiyonel/düşük öncelik, uygulanmadı.

### 13. `TRadTask` SRP ihlali
Gözlem doğru ama dosya/sınıf ayrımı kararı kullanıcıya ait — sadece bilgilendirme, aksiyon alınmadı.
