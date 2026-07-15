---
original_path: "D:\dev\Delphi\00-Lib\rad.cmd.md"
source: 00-lib
copied_at_utc: 2026-07-02T17:23:22Z
sha256: 4f823e7daf2f5680f17bd82b05cd55cbc86fc0bccdc7fa72cff070e8e99722c2
---

# rad.cmd.pas — `ICmds`/`TCmd` Kullanım Kılavuzu ve İnceleme Sonucu
> Revize: 2026-07-09 (bkz. "Düzeltme Geçmişi" bölümü — 2 kritik use-after-free/AV düzeltmesi + normalizasyon/guard + loglama).

## Ne İşe Yarar

`rad.cmd.pas`, isimle kayıtlı komutları (string → closure) tutan, senkron/asenkron çalıştırılabilen basit bir **komut kaydı (command registry)** sağlar. `TValue`/`TArray<TValue>` (RTTI) kullandığı için herhangi bir imzayla fonksiyon kaydedilebilir. `CreateCmds` ile bir `ICmds` örneği üretilir; iç implementasyon (`TCmds`) mORMot `TRWLock` ile thread-safe (reentrant `WriteLock` — komutlar birbirini zincirleme çağırabildiği için tercih edildi), anahtarlar `string.ToLowerInvariant` ile normalize edilerek büyük/küçük harf duyarsız saklanır.

## Tipler ve Metodlar

| İsim | Parametreler | Ne işe yarar |
|---|---|---|
| `TCmd` | `reference to function(Sender: TObject; const Args: TArray<TValue>): TValue` | Kaydedilecek komutun imzası. |
| `CreateCmds` (global fonksiyon) | — | Yeni bir `ICmds` örneği üretir. |
| `RegisterCommand(Name, Func)` | string, `TCmd` | Bir komutu kaydeder/günceller (isim büyük/küçük harf duyarsız). |
| `UnregisterCommand(Name)` | string | Kaydı siler (yoksa sessizce hiçbir şey yapmaz). |
| `Exists(Name)` | string | Komut kayıtlı mı. |
| `CommandCount` | — | Kayıtlı komut sayısı. |
| `Execute(Name, Sender, Args)` | string, `TObject` (vars. nil), `TArray<TValue>` (vars. nil) | Komutu **senkron** (çağıran thread'de) çalıştırır; komut yoksa `Exception` fırlatır. |
| `TryExecute(Name, Sender, Args, out Res)` / `TryExecute(Name, out Res, Sender)` | — | `Execute`'u exception fırlatmadan dener; başarı/başarısızlığı `Boolean` döner (hata mesajı korunmaz — sadece var/yok bilgisi). |
| `ExecuteAsync(Name, Sender, Args, OnDone, OnError)` | string, `TObject`, `TArray<TValue>`, `TProc<TValue>`, `TProc<Exception>` (vars. nil) | Komutu bir thread pool thread'inde (`TTask.Run`) çalıştırır; `OnDone`/`OnError` ana thread'e kuyruklanarak (`TThread.ForceQueue`) çağrılır. `OnError` verilmezse hata sessizce yutulur. |

## Kullanım Örnekleri

**1. Kayıt + senkron çalıştırma:**
```pascal
var Cmds := CreateCmds;
Cmds.RegisterCommand('Topla', function(Sender: TObject; const Args: TArray<TValue>): TValue
  begin
    Result := Args[0].AsInteger + Args[1].AsInteger;
  end);

var Sonuc := Cmds.Execute('topla', nil, [TValue.From<Integer>(3), TValue.From<Integer>(4)]);
ShowMessage(Sonuc.AsInteger.ToString); // '7' — isim büyük/küçük harf duyarsız
```

**2. Güvenli çalıştırma (`TryExecute`):**
```pascal
var Res: TValue;
if Cmds.TryExecute('yokBoyleKomut', nil, [], Res) then
  ShowMessage('Çalıştı')
else
  ShowMessage('Komut bulunamadı veya hata oluştu');
```

**3. Asenkron çalıştırma:**
```pascal
Cmds.ExecuteAsync('Topla', nil, [TValue.From<Integer>(1), TValue.From<Integer>(2)],
  procedure(V: TValue) begin ShowMessage('Sonuç: ' + V.AsInteger.ToString) end,
  procedure(E: Exception) begin ShowMessage('Hata: ' + E.Message) end);
```

**4. Kaydı kaldırma:**
```pascal
Cmds.UnregisterCommand('Topla');
Assert(not Cmds.Exists('topla'));
```

---

## Doğrulama Sonuçları

`Core\rad.cmd.pas` üzerindeki DIKKAT.md maddeleri RTL (`System.SysUtils.pas` `TStringHelper.ToLower`/`ToLowerInvariant`, `System.SyncObjs.pas` `TLightweightMREW`) ve mORMot (`mormot.core.base.pas` `DefaultHash`/`THasher`) kaynaklarıyla karşılaştırılarak doğrulandı.

### ✅ Doğrulandı ve düzeltildi

- **`Name.ToLower` locale bağımlılığı** — İddia edilenden ciddi: Türkçe locale'de "Turkish I" sorunu nedeniyle `'I'.ToLower <> 'i'` olabiliyor, farklı locale'li makineler arasında komut bulunamama riski. `Name.ToLowerInvariant`'a geçildi.
- **Hash fonksiyonu uyumsuzluğu** — DIKKAT.md'nin "opsiyonel iyileştirme" dediğinden daha ciddi: `@DefaultHash` (`function(RawByteString; crc): cardinal`), `TDynArrayHashed.Init`'in beklediği `TDynArrayHashOne` (`function(const Item; Hasher: THasher): cardinal`) ile tip uyumsuzdu — muhtemelen dosya hiç derlenmemişti (DIKKAT.md'nin kendi önerdiği düzeltme de aynı eksik-parametre hatasını taşıyordu, `rad.cache.pas`'ta bulduğumuzla aynı). **Kullanıcı kararıyla** `TDynArrayHashed` tamamen kaldırılıp `TDictionary<string, TCmd>`'ye geçildi (bkz. proje kararı: `TDynArrayHashed` artık kullanılmıyor).
- **`TThread.Queue(nil, ...)`** → `TThread.ForceQueue(nil, ...)` (`ExecuteAsync` içinde, `rad.thread.pas`'la tutarlı).

### ❌ Doğrulandı, yanlış bulundu

- **`TLightweightMREW` init/finalize kontrolü** — Yanlış kaygı. RTL kaynağında (`System.SyncObjs.pas:477`) `class operator Initialize(out Dest: TLightweightMREW);` var — otomatik çağrılıyor, manuel init gerekmiyor (`TRWLock`'ta gördüğümüzle aynı desen, farklı mekanizma). (Not: kullanıcı kararıyla sonradan `TLightweightMREW`'den `TRWLock`'a geçildi — aşağıya bkz.)

### ⚠️ Doğru gözlem, aksiyon alınmadı (opsiyonel/ergonomi)

- `TryExecute`'un hata mesajını yutması (sadece `Boolean` dönüyor) — doğru gözlem, API tasarım tercihi.
- `ExecuteAsync`'te `OnError` verilmezse hatanın sessiz kalması — doğru gözlem, global loglama eklenmesi ayrı bir karar.
- `ExecuteAsync`'in iptal/await desteği olmaması — yeni özellik talebi, kapsam dışı.

### 🔧 Ek: `TLightweightMREW` → `TRWLock` geçişi

Kullanıcı kararıyla `FLock` daha sonra `TLightweightMREW`'den mORMot `TRWLock`'a taşındı. Gerekçe: bu registry'i birçok component'in kullanması, komutların DataSet `BeforePost` gibi olaylardan zincirleme çağrılması (bir komutun başka bir komutu tetiklemesi) planlanıyor — `TLightweightMREW`'in reentrant olmayan `WriteLock`'ı bu senaryoda aynı thread'in kendi kendini kilitlemesine yol açabilirdi; `TRWLock`'un `WriteLock`'ı reentrant. `BeginRead`/`EndRead`/`BeginWrite`/`EndWrite` private wrapper metodları eklendi (`rad.cache.pas`'taki desenle aynı).

## Düzeltme Geçmişi (2026-07-09, "1.md"/"2.md" incelemesi)

`ExecuteAsync` içinde iki kritik use-after-free/AV riski ve normalizasyon/guard
eksiklikleri tespit edildi; hepsi gerçek `dcc32` derlemesi + scratch runtime
testleriyle doğrulanıp düzeltildi:

| # | Bulgu | Çözüm |
|---|---|---|
| 1 | `except on E: Exception do ... TThread.ForceQueue(nil, procedure begin OnError(E); end)` — RTL, except bloğundan çıkılınca `E`'yi otomatik `Free` eder; `ForceQueue` callback'i DAHA SONRA çalıştığı için `OnError(E)` dangling pointer okur (use-after-free) | `AcquireExceptionObject` ile sahiplik alınıp callback'in `finally`'sinde manuel `Free` edilir |
| 2 | `ExecuteAsync`'in `TTask.Run` closure'ı `Self`'i (ör. `Execute(...)` çağrısı üzerinden) interface refcount'a katılmayan ham referansla yakalıyordu — `CreateCmds.ExecuteAsync(...)` gibi geçici kullanımda task sürerken nesne `Free` edilip AV riski taşıyordu | `TTask.Run`'dan önce `LKeepAlive: ICmds := Self;` ile nesne task bitene kadar interface refcount üzerinden hayatta tutuluyor |
| 3 | Komut adı normalizasyonu sadece `ToLowerInvariant` kullanıyordu, baş/son boşluklar korunuyordu (`rad.eventbus.pas`'ın kanal adı normalizasyonuyla tutarsız) | `NormalizeName` (`Trim.ToLowerInvariant`) eklendi, `RegisterCommand`/`UnregisterCommand`/`Execute`/`Exists` hepsinde kullanılıyor |
| 4 | `RegisterCommand` boş isim veya nil fonksiyonu engellemiyordu | Her ikisi de artık `EArgumentException` fırlatıyor |
| 5 | `TryExecute` her exception'ı (komut-yok dahil) aynı `False`'a indirip hata bilgisini tamamen kaybediyordu | Kullanıcı kararıyla: hata artık `TSynLog.Add.Log(sllWarning, ...)` ile loglanıyor (dönüş değeri/API değişmedi — sadece `Boolean` döner, ama artık iz sürülebilir) |
| 6 | `ExecuteAsync`'te `OnDone`/`OnError` callback'inin KENDİSİ exception atarsa sarmalanmadan yayılıyordu | Kullanıcı kararıyla: ayrı bir `try/except` ile yakalanıp `TSynLog.Add.Log(sllError, ...)` ile loglanıyor, yutuluyor |

`TSynLog` kullanımı bu projede `rad.thread.pas`/`rad.worker.pas`'takiyle aynı
kanonik desen (`mormot.core.log`); yeni `uses mormot.core.base` (sllWarning/
sllError sabitleri + `TRWLock` inline expansion için) implementation'a eklendi.

## Test Kapsamı

`Core\rad.cmd.Tests.pas` — `TCmdsTestleri`, 15 test (Türkçe isimlendirme kuralına göre): `KomutKaydiVeSayisi`, `CalistirVeGuvenliCalistir`, `AnahtarBuyukKucukHarfDuyarsiz` (`[TestCase]` ile 3 senaryo — küçük/büyük/karışık harf), `KomutKaydiniSil`, `AsenkronCalistirBasariDurumu`, `AsenkronCalistirHataDurumu`, `EszamanliKayitCalistirSil` (6 thread, parametre-geçişli güvenli desenle — bkz. `rad.thread.md`/`rad.cache.md`'deki closure-in-loop dersi), ve 2026-07-09 incelemesinden eklenen 6 regresyon testi: `IsimBaslangicBitisBosluklariTrimlenir`, `BosIsimKaydiReddedilir`, `NilFonksiyonKaydiReddedilir`, `ExecuteAsyncDisReferansBirakilincaNesneYasar`, `ExecuteAsyncHataMesajiBozulmadanUlasir`, `OnDoneKendiExceptionAtsaProgramCokmez`.
