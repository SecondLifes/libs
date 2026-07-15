Dosya isimlendirme standartları (rad.*, help.*, prov.* prefix'leri) framework kuralıdır ve uyulur.
Ancak class, record, interface gibi tip isimlerindeki convention (örn. TRad* prefix zorunluluğu) kullanıcının kendi kontrolündedir — AI bu konuda hata bildirmez veya değişiklik önermez.

**Why:** Kullanıcı tip isimlerini bilinçli olarak seçiyor (TSmartParam, TSmartCache gibi). Dosya prefix'i ile class prefix'ini ayrı standartlar olarak görüyor.

**How to apply:** Dosya adı kurallara uymuyorsa belirt. Class/record/interface isimlerine karışma.
