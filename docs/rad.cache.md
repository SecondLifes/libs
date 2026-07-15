---
original_path: "D:\dev\Delphi\00-Lib\rad.cache.md"
source: 00-lib
copied_at_utc: 2026-07-02T17:23:22Z
sha256: 4e8fc2682a27f5e4359f385d264a54e8382541f3875aacd95eaffae4664be040
---

# rad.cache.pas — `TSmartParam` / `TSmartCache` Kullanım Kılavuzu ve İnceleme Sonucu
> Revize: 2026-07-09 (bkz. "Düzeltme Geçmişi (2026-07-09)" bölümü — kritik yönetilen-Variant sızıntısı düzeltmesi + `Kind`/`TryAs*` yeni özellikleri).

## Ne İşe Yarar

- **`TSmartParam`**: `Variant` üzerine kurulu, tip-esnek bir değer taşıyıcı (record). Integer/Double/string/Boolean/DateTime/`TObject`/`IInterface` saklayabilir, `Get*`/implicit operatörlerle geri okunur.
- **`TSmartCache`**: `TSmartParam` değerlerini string anahtarla saklayan, thread-safe (`TRWLock`), değişiklik olaylarını (`OnGlobalChange` + anahtar-bazlı `RegisterEvent`) destekleyen bir cache/dictionary sınıfı. İç depolama `System.Generics.Collections.TDictionary<string, TSmartParam>`.

## `TSmartParam` Metodları

| Metod | Parametreler | Ne işe yarar |
|---|---|---|
| `SetValue(V)` (overload'lar) | Integer/Double/string/Boolean/TDateTime/Variant/TObject/IInterface | Değeri atar, `vType`'ı otomatik ayarlar (güvenli `FValue := V` ataması — bkz. Düzeltme Geçmişi #1). `TObject` verilirse sadece **adresi** saklanır (sahiplenmez — bkz. aşağıdaki uyarı), platformdan bağımsız her zaman `varInt64` kullanılır. |
| `New(V)` (class, overload'lar) | Aynı tipler | `SetValue` çağıran kısayol factory: `TSmartParam.New(42)`. |
| `AsInteger`/`AsFloat`/`AsString`/`AsBoolean`/`AsDateTime`/`AsDate`/`AsTime` | — | Saklanan değeri istenen tipte döndürür (tip uyuşmuyorsa `Variant` dönüşümü dener, uyumsuzsa exception fırlatabilir — exception istenmiyorsa `TryAs*` kullanın). |
| `TryAsInteger`/`TryAsFloat`/`TryAsBoolean`/`TryAsDateTime` | `out AValue` | `As*`'ın exception fırlatmayan hâli — dönüşüm başarısızsa `False` döner, `AValue` ilgili tipin sıfır değerine ayarlanır. |
| `AsObj<T: class>` | `T` bir class tipi olmalı | Saklanan pointer'ı `T` tipine cast eder (`SetValue(TObject)` ile konan nesneler için). Nesne **hâlâ canlıysa** `is T` kontrolü yapar, yanlış tipte `nil` döner (freed-object/dangling-pointer riski bununla çözülmez — bkz. aşağıdaki uyarı). |
| `AsIntf<T>` | `T` bir interface tipi | Saklanan `IInterface`'i `GetTypeData` ile okunan GUID üzerinden `T`'ye `Supports` eder (RTTI context oluşturmadan — performans). |
| `IsNull` / `IsEmpty` | — | Sırasıyla `SetNull` çağrılmış mı / hiç değer atanmamış mı. |
| `SetNull` | — | Değeri `Null`'a çevirir (`vType = varNull`). |
| `Kind` | — | `TSmartParamKind` (`spEmpty/spNull/spInteger/spFloat/spString/spBoolean/spDateTime/spObject/spInterface/spVariant`) — ham `vType`'ın domain-odaklı yorumu; `TObject` (`spObject`) ile gerçek `Integer` (`spInteger`) değerlerini platformdan bağımsız ayırt eder. |
| `Implicit` operatörleri | — | `Integer(Param)`, `Param.AsString` yerine doğrudan `string(Param)` gibi örtük dönüşüm sağlar. |

## `TSmartCache` Metodları

| Metod | Parametreler | Ne işe yarar |
|---|---|---|
| `Create(AThreadSafe)` | Boolean (vars. `True`) | `False` verilirse kilitleme tamamen devre dışı kalır (tek-thread senaryosunda performans için). |
| `AddOrSet(AKey, V)` (overload'lar) | string, TSmartParam/Integer/Double/string/Boolean/TDateTime/Variant/TObject/IInterface | Değeri ekler/günceller; **değişiklik olaylarını tetikler**, bir handler `False` dönerse işlem iptal olur ve `AddOrSet` de `False` döner. |
| `Get(AKey, ADefault)` (overload'lar) | string, varsayılan değer | Anahtar yoksa `ADefault` döner; event tetiklemez. |
| `GetOrAdd(AKey, AParam)` | string, TSmartParam | Anahtar varsa mevcut değeri döner; yoksa **sessizce** (event tetiklemeden) ekler ve `AParam`'ı döner — "tembel başlatma" (lazy-init) için. |
| `TryGetValue(AKey, out AParam)` | string, çıktı parametresi | `Exception` fırlatmadan var/yok kontrolü + okuma. |
| `ContainsKey(AKey)` | string | Anahtar var mı. |
| `Remove(AKey)` | string | Anahtarı siler, gerçekten silindiyse `True` döner (yoksa `False`). |
| `Clear` | — | Tüm anahtarları ve kayıtlı event'leri temizler. |
| `Count` | — | Kayıt sayısı. |
| `RegisterEvent(AKey, AEvent)` | string, `TParamChangeEvent` | Belirli bir anahtar değiştiğinde çağrılacak bir handler ekler (aynı anahtara birden fazla eklenebilir). |
| `UnregisterEvent(AKey, AEvent)` | string, `TParamChangeEvent` | `RegisterEvent`'e verilenle **aynı closure referansını** vererek sadece o handler'ı kaldırır (`True`/`False` döner). |
| `UnregisterEvents(AKey)` | string | O anahtara kayıtlı **tüm** handler'ları kaldırır. |
| `ForEach(AProc)` | `TProc<string, TSmartParam>` | Tüm kayıtlar üzerinde (kilit dışında, anlık bir kopya üzerinden) gezinir. |
| `OnGlobalChange` (property) | `TParamChangeEvent` | Cache genelinde HER `AddOrSet` çağrısında tetiklenen tekil handler. |
| `OnError` (property) | `TSmartCacheErrorEvent` | Bir event handler exception fırlatırsa çağrılır. |

`TParamChangeEvent = TFunc<string, TVarType, Variant, Variant, Boolean>` — imza: `function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean`. `False` dönerse değişiklik iptal edilir.

## Kullanım Örnekleri

**1. `TSmartParam` temel kullanım:**
```pascal
var P: TSmartParam;
P.SetValue(42);
Assert(P.AsInteger = 42);
P := TSmartParam.New('merhaba');
Assert(P.AsString = 'merhaba');
```

**2. `TObject`/`IInterface` saklama (sahiplenme yok!):**
```pascal
var List := TStringList.Create;
var P := TSmartParam.New(List);
var Geri := P.AsObj<TStringList>;  // Geri = List (aynı referans)
// P, List'in SAHİBİ DEĞİL — List'i sen Free etmelisin.
List.Free;
```

**3. Basit cache kullanımı:**
```pascal
var Cache := TSmartCache.Create;
try
  Cache.AddOrSet('kullaniciAdi', 'ahmet');
  ShowMessage(Cache.Get('kullaniciAdi', ''));       // 'ahmet'
  ShowMessage(Cache.Get('yokBoyle', 'varsayilan')); // 'varsayilan'
finally
  Cache.Free;
end;
```

**4. `GetOrAdd` (sessiz lazy-init) vs `AddOrSet` (event tetikler):**
```pascal
var FireCount := 0;
Cache.OnGlobalChange := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
  begin Inc(FireCount); Result := True; end;

Cache.GetOrAdd('ayar', TSmartParam.New(10));  // FireCount hala 0 — sessiz ekleme
Cache.AddOrSet('ayar', 20);                    // FireCount = 1 — bilinçli değişiklik
```

**5. Değişiklikleri dinleme ve iptal etme:**
```pascal
Cache.RegisterEvent('bakiye', function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
  begin
    Result := ANew >= 0; // negatif bakiyeye izin verme
  end);
Cache.AddOrSet('bakiye', -50); // Result=False → AddOrSet de False döner, değer değişmez
```

**6. Tek bir handler'ı kaldırma:**
```pascal
var Handler: TParamChangeEvent := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
  begin Result := True; end;
Cache.RegisterEvent('k', Handler);
Cache.UnregisterEvent('k', Handler); // sadece bu handler kalkar, aynı anahtara başka handler eklenmişse etkilenmez
```

## ✅ Doğrulandı ve düzeltildi

### 2. `AsObj<T>` güvenlik sorunu
Doğrulandı — iddia edilenden de ciddiydi: kısıtsız `Move(LAddr, Result, SizeOf(Result))` çağrısı, `T` pointer boyutundan büyük bir tip olursa stack sınırlarının dışına taşıp rastgele bellek okuyabiliyordu (UB). `function AsObj<T: class>: T;` kısıtı eklendi, `Move` yerine doğrudan pointer cast (`T(Pointer(NativeInt(FValue)))`) kullanılıyor.

### 3. `Remove` her zaman `True` dönüyordu
Doğrulandı. Artık `FindHashedAndDelete`'in dönüş değerine (bulunamazsa negatif index) göre gerçek sonucu veriyor — DIKKAT.md'nin önerdiği ayrı `FindHashed` + `FindHashedAndDelete` (2 lookup) yerine tek çağrı ile.

### 4. `FireEvents`'te `FGlobalEvent` kilit dışında okunuyordu
Doğrulandı, gerçek bir race condition. `FGlobalEvent` artık `BeginRead` kilidi altında yerel değişkene kopyalanıyor; ayrıca `OnGlobalChange` property'sinin getter/setter'ı da (`GetGlobalEvent`/`SetGlobalEvent`) kilitli hale getirildi — sadece okumayı kilitlemek yeterli değildi, yazma tarafı da kilitsizdi.

### (DIKKAT.md'de olmayan) `HashSmartCacheEntry` derleme hatası
İnceleme sırasında bulundu: `THasher` imzası `function(crc: cardinal; buf: PAnsiChar; len: cardinal): cardinal;` (3 parametre), kod ise `Hasher(pointer(Key), Length(Key))` diye 2 parametreyle çağırıyordu (E2033). `Hasher(0, pointer(Key), Length(Key))` olarak düzeltildi.

### (Kullanıcı isteğiyle) `UnregisterEvent` eklendi
`UnregisterEvents` bir anahtara kayıtlı TÜM handler'ları siliyordu; artık `UnregisterEvent(AKey, AEvent)` ile referans eşitliğine göre tek bir handler kaldırılabiliyor.

---

## ❌ Doğrulandı, yanlış/gereksiz bulundu — aksiyon alınmadı

### 6. `TRWLock` başlatma kontrolü
Yanlış kaygı. mORMot2 kaynağında (`mormot.core.os.pas:4474-4476`) açıkça: *"Init not needed if TRWLock is part of a class (filled with 0)"*. `FLock` zaten bir class field'ı, otomatik sıfırlanıyor.

---

## ⚠️ Doğru gözlem, mimari karar (kullanıcıya bırakıldı) — değişiklik yapılmadı

### 1. Obje sahipliği / dangling pointer
Doğru — `SetValue(TObject)` adresi sahiplenmeden saklıyor. Opsiyonel `OwnsObjects` bayrağı eklenip eklenmeyeceği mimari bir tercih.

### 5. `RawUtf8` vs `string` anahtar tutarsızlığı
Doğru gözlem ama fonksiyonel hata değil, sadece performans/bellek nüansı.

### GetOrAdd event tetiklememesi
`GetOrAdd` yeni kayıt eklerken event tetiklemiyor, `AddOrSet` her zaman tetikliyor. Kullanıcı onayıyla: bu davranış doğru (ekleme ≠ değer değişimi), değişiklik yapılmadı.

---

## Düzeltme Geçmişi (2026-07-09, "1.md"/"2.md" incelemesi)

`TSmartParam`'da kritik bir yönetilen-Variant sızıntısı ve birkaç güvenlik/
performans/API iyileştirmesi tespit edildi; hepsi gerçek `dcc32` derlemesi +
scratch runtime testleriyle (instrumented interface destructor sayacı,
`GetTypeData` GUID karşılaştırması dahil) doğrulanıp düzeltildi:

| # | Bulgu | Çözüm |
|---|---|---|
| 1 | `SetValue(Integer/Double/Boolean/TDateTime/TObject)` doğrudan `TVarData(FValue)` alanlarına yazıyordu — `FValue` daha önce string/interface gibi yönetilen bir değer tutuyorsa, bu eski değerin referans sayacı hiç düşürülmüyordu (gerçek sızıntı, instrumented interface destructor'ı hiç çağrılmadığı scratch testle **kanıtlandı**) | Tüm bu overload'lar güvenli `FValue := V; FvType := TVarData(FValue).VType;` desenine (zaten `SetValue(string)`/`SetValue(Variant)`'ta kullanılan desen) geçirildi — derleyici atama öncesi eski değeri otomatik temizliyor |
| 2 | (1.md'nin ayrı bulgusu) `SetValue(TObject)` platformdan bağımsız hep `varInt64` kullanıyordu ("yer israfı" olarak eleştirildi) | **Bilinçli olarak korundu** — bir Variant'ın boyutu `VType`'tan bağımsız zaten sabit olduğu için gerçek bir israf yok; platforma göre değişseydi (`NativeInt`) 32-bit'te gerçek `Integer` değerleriyle aynı `vType`'ı paylaşıp yeni `Kind` özelliğini (#8) belirsizleştirirdi |
| 3 | `AsObj<T>` yanlış class tipi istendiğinde (nesne hâlâ canlıyken) kontrolsüz cast yapıyordu | Nesne canlıysa `is T` kontrolü eklendi, yanlış tipte `nil` döner (freed-object riski bununla çözülmedi — madde 1'deki mimari karar olarak kalıyor) |
| 4 | `AsIntf<T>` her çağrıda `TRttiContext` oluşturup tip ağacı taraması yapıyordu (gereksiz heap allocation) | `GetTypeData(TypeInfo(T))^.Guid` ile RTTI context'siz doğrudan GUID okunuyor — GUID eşitliği scratch testle doğrulandı, davranış aynı |
| 5 | `AsInteger/AsFloat/AsBoolean/AsDateTime` tip uyuşmazlığında exception fırlatabiliyordu, exception'sız API yoktu | `TryAsInteger/TryAsFloat/TryAsBoolean/TryAsDateTime` eklendi (mevcut `As*` davranışı değişmedi) |
| 6 | `TSmartParam.Test` production unit içinde kalmış mini assertion testiydi | Kaldırıldı — projede hiçbir çağıran yoktu (grep ile doğrulandı), zaten `rad.cache.Tests.pas` tarafından kapsanıyor |
| 7 | `IsEmpty`/`Default(TSmartParam)` sözleşmesi testlerde doğrudan yoktu | Regresyon testi eklendi (kod değişikliği gerekmedi — davranış zaten doğruydu) |
| 8 | `vType` (ham `TVarType`) `TObject` gibi durumlarda semantik olarak "object" demiyordu | `TSmartParamKind` enum + `Kind` property eklendi; ayrıca doğrulama sırasında ek bulgu: ondalıklı **literal**ler (`SetValue(3.14)`) overload çözümlemesinde `SetValue(Variant)`'a bağlanıp `varCurrency` üretebiliyor (`varDouble` değil) — `Kind` bunu da `spFloat` sayacak şekilde genişletildi |

## 🧪 Test Kapsamı

`Core\rad.cache.Tests.pas` — `TSmartParamTestleri` (9 test: temel tip round-trip,
null/empty, nesne referansı round-trip, arayüz desteği, ve 2026-07-09
incelemesinden eklenen 5 regresyon testi — yönetilen değer sızdırmadan üzerine
yazma, `AsObj<T>` yanlış tip güvenliği, `Kind` property, `TryAs*` metotları,
boş param varsayılan sözleşmesi) + `TSmartCacheTestleri` (7 test: `AddOrSet`/`Get`
round-trip, `Remove` regresyonu, global event ile iptal, `GetOrAdd`/`AddOrSet`
event farkı, `UnregisterEvent`, ve iki eşzamanlılık testi). Toplam 16 test,
hepsi geçiyor.

**Not (teşhis süreci):** Eşzamanlılık testleri ilk yazıldığında sürekli "zaman aşımı" hatası veriyordu. Uzun bir teşhis sürecinden sonra (önce `TRWLock`→`TCriticalSection` denendi, sorunu çözmedi) gerçek sebep bulundu: test kodunda klasik `for i := 0 to N do begin var ev := Array[i]; TThread.CreateAnonymousThread(...) end;` deseninde, döngü içindeki inline `var`'ın thread closure'ı tarafından her iterasyonda taze yakalanması bu ortamda güvenilir değildi — tüm thread'ler aynı (sondaki) event'i sinyalliyordu. Çözüm: döngü closure'ına güvenmek yerine her thread'in verisini bir yardımcı prosedüre parametre olarak geçirmek. `rad.cache.pas`'ın kendisinde bu sorunla ilgili hiçbir hata yoktu; `TRWLock` masumdu ve geri alındı.

---

## 🔬 Ek: `TDynArrayHashed` → RTL `TDictionary` mimari değişikliği

Kullanıcı isteğiyle `Core\rad.cache.Benchmark.Tests.pas` yazıldı: `TSmartCache` (mORMot `TDynArrayHashed`), RTL `System.Generics.Collections.TDictionary`, ve `Dext.Collections.Dict.TDictionary` (`vendor\cesarliws\dext`) 50.000 kayıtla (Ekleme/Bulma/Silme + veri doğruluğu) karşılaştırıldı.

**Bulgu — kritik stabilite sorunu:** `TSmartCache`, silme fazında ~22.361. kayıtta tutarlı şekilde **Access Violation** ile çöküyordu (Ekleme ve Bulma sorunsuzdu). Kök neden mORMot'un `TDynArrayHashed`'inin, `TSmartCacheEntry → TSmartParam → Variant` şeklinde iki kat iç içe geçmiş yönetilen (managed) alanı, silme sırasındaki dizi sıkıştırma/collision-chain yeniden-hashleme mantığında düzgün yönetememesi (kesin kök neden mORMot'un asm-ağırlıklı iç kodunda, doğrulanamadı — yama da yapılmadı).

**Performans (çökme öncesi kısmi veriler dahil):**

| Yapı | Ekleme (50k) | Bulma (50k) | Silme (50k) | Bellek |
|---|---|---|---|---|
| `TSmartCache` (`TDynArrayHashed`) | 16-20 ms | 9-10 ms | **ÇÖKÜYORDU** | +3057 KB |
| RTL `TDictionary` | 5 ms | 2 ms | 5 ms | +3711 KB |
| Dext `TDictionary` | 8 ms | 3 ms | 3 ms | +4287 KB |

RTL `TDictionary` hem en hızlı hem de kararlı çıktı — `TSmartCache`'in Ekleme/Bulma'sı bile RTL'den 2-3 kat yavaştı.

**Karar (kullanıcı onayıyla):** `TSmartCache.FDic`, `TDynArrayHashed`'den `System.Generics.Collections.TDictionary<string, TSmartParam>`'a taşındı.
- `TSmartCacheEntry`/`TSmartCacheEntryArray`/`HashSmartCacheEntry`/`CompareSmartCacheEntry` kaldırıldı.
- `mormot.core.base`/`mormot.core.data`/`mormot.core.unicode` bağımlılıkları gitti; sadece `mormot.core.os` (`TRWLock` için) kaldı.
- Yan fayda: anahtarlar artık her yerde düz `string` — madde 5'teki (RawUtf8 vs string) tutarsızlık da otomatik çözüldü.
- Public API (metod imzaları) değişmedi; migrasyon sonrası tüm testler ve 50k benchmark'ı sorunsuz geçti.
