`Core\rad.cache.pas`'ta mORMot `TDynArrayHashed`, 50k kayıtla yapılan benchmark'ta silme (Remove) sırasında ~22.361. kayıtta tutarlı şekilde Access Violation veriyordu (kök neden kesin doğrulanamadı — muhtemelen `TSmartCacheEntry → TSmartParam → Variant` gibi iki kat iç içe geçmiş managed alanların silme sırasındaki dizi sıkıştırma/rehash mantığıyla ilişkili). Ayrıca RTL `TDictionary` hem daha hızlı hem daha stabil çıktı (bkz. `rad.cache.md`).

Bu nedenle: **`TDynArrayHashed` yeni kodda kullanılmayacak; mevcut kod tabanında karşılaşıldığında kullanıcıya bildirilip `TDictionary`'ye geçilip geçilmeyeceğine birlikte karar verilecek** (otomatik/sessizce değiştirilmeyecek — mimari karar kullanıcıya ait, bkz. [[feedback_refactor_decisions]]).

Bilinen örnekler:
- `Core\rad.cache.pas` — zaten `TDictionary<string, TSmartParam>`'a taşındı (tamamlandı).
- `Core\rad.cmd.pas` — zaten `TDictionary<string, TCmd>`'ye taşındı (tamamlandı, 2026-07-09 itibarıyla `TDynArrayHashed` kalmadığı doğrulandı).

**Why:** Kanıtlanmış stabilite riski (AV) + ölçülmüş performans dezavantajı; RTL `TDictionary` bu projede varsayılan tercih haline geldi.

**How to apply:** Herhangi bir `.pas` dosyasında `TDynArrayHashed` kullanımına rastlanırsa kullanıcıya bildir, `TDictionary`'ye geçiş için onay iste — otomatik değiştirme.
