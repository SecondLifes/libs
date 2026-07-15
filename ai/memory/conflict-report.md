# Çakışma Raporu (Conflict Report) - FİNALİZE EDİLDİ

> `ai/memory/global.yaml: governance.conflict_policy` ("Expert wins, AI suggests
> alternatives") gereği çözülmüş mimari çakışmaların kaydı.

## ÇÖZÜLDÜ - ÇAKISMA 1 & 2: Mimari ve Vendor Kullanımı
**Eski karar:** Hibrit Mimari. Genel durum: Doğrudan vendor kullanımı. Özel durum: Contract-Provider-API soyutlaması.
**Güncel karar (2026-07-03):** Contract-Provider-API soyutlaması (özel durum) kaldırıldı. Artık tüm durumlarda doğrudan vendor kullanımı esastır; interface/mocking katmanı zorunlu değildir. `contract-first.md` kuralı bu nedenle kaldırıldı, `vendor-first.md` tek yetkili dosya oldu; README'deki "Contract-First" ve "Contract-Driven" ilkeleri buna göre güncellendi.
**Gerekçe:** Delphi Expert kararı (`ai/memory/global.yaml: governance.conflict_policy`: "Expert wins, AI suggests alternatives").

## ÇÖZÜLDÜ - ÇAKISMA 3: Veri Yapısı (rad.cache / rad.cmd / rad.thread)
**Karar:** `TDictionary` + `TRWLock` kanonik yapı olarak seçildi.
**Gerekçe:** `TDynArrayHashed` yapısının yüksek veri yükünde (>50k kayıt) tespit edilen Access Violation (AV) hatası nedeniyle mORMot2'den Delphi RTL Dictionary yapısına geçilmesi kararlaştırıldı.

## ÇÖZÜLDÜ - ÇAKISMA 4: Delphi Sürümü
**Karar:** Yazılım vizyonu 'Delphi 13.1 Athens', fiziksel derleyici 'Compiler Version 37.0' olarak eşleştirildi.

## ÇÖZÜLDÜ - ÇAKISMA 5: Test Dosyası Oluşturma Zamanlaması
**Eski kural (`contract-first.md`):** İmplementasyondan önce DUnitX test iskeleti hazırlanır (test-first).
**Ara karar (`project-rules.md` → "Test ve Dokümantasyon Zamanlaması"):** TestCase dosyası ve `docs\` kullanım kılavuzu, kod/yapı üzerindeki tüm işlemler bitmeden oluşturulmaz/güncellenmez; ikisi de iş tamamlandıktan sonra onay alınarak yapılır.
**Güncel karar (2026-07-09):** TestCase dosyası artık iş bitmeden, düzeltmelerle birlikte oluşturulur/güncellenir; sadece fiili çalıştırma (`dcc32`/`run_tests.bat`) öncesi kullanıcı onayı alınır. `docs\` kısmı ara karardaki gibi kalır (iş bitince, onayla, toplu).
**Gerekçe:** Delphi Expert kararı (`ai/memory/global.yaml: governance.conflict_policy`: "Expert wins, AI suggests alternatives").
