Bu projede DUnitX testleri yazarken (yeni `.Tests.pas` dosyaları veya mevcutlara ekleme yaparken):

1. Birbirine çok benzeyen, sadece girdi/çıktısı değişen senaryolar için ayrı ayrı test prosedürleri yazmak yerine **data-driven test** (`[TestCase]`/`[AutoNameTestCase]`) tercih edilir.
2. **Her test senaryosunun bir ismi olmalı** — `[TestCase]` kullanılıyorsa isim elle verilir (birden fazla senaryo varsa sonuna sıra numarası eklenir: "... 1", "... 2" gibi); `[AutoNameTestCase]` kullanılıyorsa isim parametrelerden otomatik üretilir (elle isim verilmez, bu yüzden bu attribute tercih edilebilir).
3. **Prosedür adları, TestCase/AutoNameTestCase isimleri, Category isimleri ve parametre adları TÜRKÇE olmalı.** Parametreler `A` ön ekiyle Türkçe isimlendirilir (örn. `ATarihStr`, `ABeklenenCeyrek`, `ABeklenenSonuc`). Prosedür adı İngilizce "Test_" öneki YERİNE doğrudan Türkçe, anlamlı bir isim olur (örn. `CeyrekHesabi`, `HaftasonuTesti` — "Test_CeyrekHesabi" değil).
4. **Test eklerken eski testler SİLİNMEZ, sadece yenileri eklenir.** Mevcut bir `.Tests.pas` dosyasına yeni senaryolar/düzeltmeler için test eklerken, önceden var olan test prosedürleri (hâlâ geçerliyse) olduğu gibi korunur — üzerine yazılmaz, kaldırılmaz.

**Kanonik örnekler (kullanıcı tarafından verildi, birebir bu şekilde kullanılmalı):**

```pascal
[Test]
[TestCase('Ceyrek Dönem Kontrolü 1','15.01.2023,1')]
[TestCase('Ceyrek Dönem Kontrolü 2','15.05.2023,2')]
[TestCase('Ceyrek Dönem Kontrolü 3','15.08.2023,3')]
[TestCase('Ceyrek Dönem Kontrolü 4','15.11.2023,4')]
procedure CeyrekHesabi(const ATarihStr: string; const ABeklenenCeyrek: Integer);
```

```pascal
[Test(true)]
[AutoNameTestCase('22.06.2024,True')]
[AutoNameTestCase('23.06.2024,True')]
[AutoNameTestCase('24.06.2024,False')]
[Category('Hafta Sonu Testi')]
procedure HaftasonuTesti(const ATarihStr: string; const ABeklenenSonuc: Boolean);
```

**Why:** Kullanıcı, çok sayıda benzer senaryoyu (aynı mantık, farklı girdi/çıktı) tek bir parametreli test metoduyla kapsamayı, kod tekrarını azaltmayı, ve tüm test isimlerinin/kodun Türkçe ve okunaklı olmasını istiyor (proje geneli Türkçe).

**How to apply:** Yeni bir DUnitX test dosyası yazarken veya benzer-girdi/çıktılı çoklu senaryo eklerken önce `[TestCase]`/`[AutoNameTestCase]` ile parametreli tek bir Türkçe isimli test metodu yazmayı değerlendir. İlgisiz/karmaşık senaryolar (concurrency, exception-yolu testleri gibi tek-seferlik, parametrize edilemeyen durumlar) için hâlâ ayrı prosedürler yazmak uygun olabilir — ama o prosedürlerin adı da Türkçe olmalı. Mevcut İngilizce isimli testlerin (`rad.thread.Tests.pas`, `rad.cache.Tests.pas`, `rad.cmd.Tests.pas`) bu kurala göre geriye dönük düzenlenip düzenlenmeyeceği kullanıcıya soruldu/sorulmalı — otomatik toptan değişiklik yapılmaz.
