---
name: delphi-helper-builder
description: Rad Core (Delphi/Pascal) projesinde bir vendor/referans .pas dosyasından yeni bir help.*.pas helper birimi üretme sürecini adım adım işletir. Kullanıcı bir dosya yolu verip "bunu helper'a çevirelim", "yeni bir helper tasarlayalım", "help.xxx.pas yazalım" dediğinde MUTLAKA bu skill kullanılmalı. Süreç bu dosyada tanımlıdır — adım adım, kullanıcıya sorarak uygular; tek seferde büyük bir plan/kod dökmez.
---

# Helper Tasarım Süreci

Aşağıdaki süreci ADIM ADIM uygula. Her adımdan sonra kullanıcıya dön, bir
sonrakine otomatik geçme.

## Akış

1. **Referans dosya VEYA tip listesi**: Kullanıcı iki şekilde başlatabilir:
   - **Dosya yolu/yolları** (klasik yol): Yol proje dışında olabilir — kesin
     path olarak al, var olduğunu doğrula.
   - **Class/record isim listesi** (ör. "TDateTime, TDate, TTime"): Dosya
     yolu vermek yerine hedef tip(ler)i verirse, dosyaya bakmadan önce
     Grep ile her tip adını `src\vendor` ağacında ara (bkz. `vendor-first.md`
     → "Yeni Fonksiyon/Algoritma Yazmadan Önce Arama"). Arama sonuçlarını
     (hangi unit'te, hangi class/record'da, nasıl bir imzayla geçtiği) adım
     4'teki "oku ve özetle"nin YERİNE kullan — sonuçlarda çıkan unit'lerden
     hangi dosyaları daha derinlemesine okumaya değer olduğunu (ör. en çok
     isabet alan 2-3 unit) kullanıcıya sunup onaydan sonra o dosyaları oku.

2. **Amaç doğrulaması**: "Bu dosya hangi helper amaçları için kullanılacak?"
   diye sor. Bu netleşmeden dosyayı okumaya geçme.

3. **İsim önerisi**: Amaç + kaynak dosya adına göre 2-4 tane `help.<scope>.pas`
   adı öner (AskUserQuestion ile, "Other" seçeneği dahil — kullanıcı kendi
   ismini de yazabilsin). Versiyon segmenti KULLANMA (`help.datetime.pas`,
   `help.datetime.1.pas` değil).

4. **Oku ve özetle**: Dosyanın `interface` bölümünü eksiksiz oku (satır
   sayısından bağımsız — `token-strategy.md`). Ne işe yaradığını kısaca
   özetle, kullanıcının onayına sun. Bir tipin/yorumun başka bir dosyaya
   referans verdiğini görürsen (ör. "bkz. TSynTimeZone" gibi), o dosyayı da
   takip et — asıl değerli bulgular çoğu zaman bu ikinci sıçramada çıkar.

   **Tip ailesi ve eksen analizi (ZORUNLU):** Hedef tip belirlenince (ör.
   `TDateTime`), sadece o dosyada bulduklarınla yetinme — hedef tipin
   İLGİLİ TİP AİLESİNİ (TDateTime için: `TDate`, `TTime`, `TTimeStamp`) ve
   standart dönüşüm eksenlerini (`string`, `RawUtf8`, `UnixTime`, `Variant`,
   `Integer`, `Double`) bir kontrol listesi gibi baştan tara. Bu, adım 5'teki
   "ters yön" disiplininin daha proaktif hali — dosyaya bakmadan ÖNCE hangi
   eksenlerin var olabileceğini bil, sonra dosyada/dosyalarda bunlardan
   hangilerinin karşılığı olduğunu ara.

5. **Fonksiyon önerileri**: Adaya alınabilecek fonksiyon/tipleri çoklu seçim
   olarak sun. Her öneri şunları içermeli:
   - Orijin dosya
   - Teknik isim (`_` önekli)
   - Türkçe açıklama (kısa, öz)
   - Örnek kullanım
   - Performans/güvenilirlik notu
   - Türkçe isim önerisi (opsiyonel alternatif)

   **Eksiksizlik disiplini (bir oturumda gerçekten kaçırıldığı için buraya
   eklendi):** Sadece "mevcut bir değer üzerinde çalışan instance method"
   şeklinde düşünme — bu, TERS YÖNDEKİ (metinden/başka tipten hedef tipe
   PARSE EDEN) fonksiyonları gözden kaçırmana sebep olur. Kaynak dosyada
   `X_TipToY` şeklinde bir dönüşüm bulursan, `YToX_Tip` şeklindeki TERSİNİ de
   mutlaka ara ve listeye ekle (class function/factory olarak, ör.
   `TDateTime._FromISO8601(...)`). "Now"-tabanlı (parametresiz, o anki değeri
   döndüren) fonksiyonlar da aynı şekilde class function olarak geçerli
   adaylardır, atlama. Listeyi bitirdiğinde kendine sor: "Bu dosyada X↔Y
   dönüşümü olan ama sadece tek yönünü sunduğum bir şey var mı?" — varsa ekle.

   Kapsam dışı bıraktığın (gerçekten kaçırma değil, bilinçli hariç tutma)
   her şeyi de kısa bir nedenle ayrıca listele (ör. "bir TTextWriter hedefine
   ihtiyaç duyuyor, TDateTime değeri üzerinde çalışmıyor" gibi) — sessizce
   atlama, kullanıcı görüp itiraz edebilsin.

   **GEÇERSİZ dışlama gerekçesi (bir oturumda gerçekten yapıldığı için buraya
   eklendi):** "Bu iş zaten RTL'de/başka bir yerde var" tek başına bir eleme
   nedeni DEĞİLDİR. Bir class/record helper'ın var olma sebebi zaten çoğu
   zaman TAM OLARAK BU — mevcut bir RTL fonksiyonunu (ör. `FormatDateTime`,
   `MonthsBetween`) `ADt._Format(...)` gibi akıcı/dot-syntax'a taşımak; bu
   `Help.DB.pas`'taki `TDataSetHelper._Close`'un `Close`'u sarmalamasıyla
   aynı mantık — yeni yetenek eklemiyor, sadece ergonomik hale getiriyor.
   "RTL'de zaten var" gördüğünde bunu OTOMATİK OLARAK Kesin/Olabilir listesine
   bir aday (ince wrapper olarak) yaz, Gerek Yok'a atma. Geçerli dışlama
   nedenleri bunun yerine: gerçekten eski/kullanılmayan teknoloji (ör. DOS
   FAT zaman damgası karşılaştırması), listede zaten daha iyi bir eşdeğeri
   olan (ör. 32-bit Unix time yerine 64-bit'i) veya hedef tipe gerçekten
   uygulanamayan (bir TTextWriter/dosya sistemi hedefi gerektiren) şeyler.

   **Yeni fonksiyon icadı:** Listeyi sadece kaynak dosyalarda BULUNANLARLA
   sınırlama — "dünya hayatı ihtiyaçları" kategorilerine göre, hiçbir
   referans dosyada olmayan ama gerçek kullanımda değerli olacak fonksiyonlar
   da tasarla: Güvenlik/Guards (`TryParse`, `IsValid`, `EnsureWithinRange`,
   `DefaultIfInvalid`), Normalizasyon (`Normalize`, `Clamp`,
   `ToStartOfBusinessDay`), Pratiklik (`NextBusinessDay`, `Age`),
   Akıcılık (zincirlenebilir fluent varyantlar). Bu şekilde icat ettiğin her
   fonksiyonu listede "(icat)" diye işaretle — kullanıcı hangisinin dosyadan
   çıkarıldığını, hangisinin senin tasarımın olduğunu görsün.

   **Sunum formatı — 3 liste:** Toplanan adayları TEK bir karışık liste
   olarak değil, güven seviyene göre 3 ayrı listeye böl (bulunan VE icat
   edilen adaylar aynı listelerin içinde, "(icat)" etiketiyle ayırt edilerek
   yer alır):
   1. **Kesin önerdiklerin** ("dünya gerçeği" — yaygın, kanıtlanmış,
      neredeyse her projede işine yarayacağından emin olduğun adaylar).
   2. **Olabilir dediklerin** (faydalı olabilir ama niş/opsiyonel/riskli
      olduğu için kararı kullanıcıya bırakman gereken adaylar).
   3. **Gerek yok dediklerin** (kapsam dışı bıraktıkların — yukarıdaki
      "kısa nedenle listele" kuralı burada karşılanır).
   Her liste, 4 veya daha az öğe içeriyorsa AskUserQuestion'ı `multiSelect:
   true` ile kullanarak gerçek çoklu-seçim sun. 4'ten fazla öğesi olan bir
   liste varsa (AskUserQuestion tek soruda en fazla 4 seçenek destekler),
   o listeyi tablo olarak yaz ve kullanıcıdan numara/isim bazlı seçim iste
   — ama yine de 3 liste ayrımını koru, hepsini birden karıştırma.

6. **Özel fonksiyon sorusu**: Dosya-analizi tabanlı listeyi sunduktan SONRA,
   plana/üretime geçmeden önce MUTLAKA sor: "Bunlara ek olarak eklemek
   istediğin, kaynak dosyalarda olmayan özel/custom bir fonksiyon var mı?"
   Kullanıcı bu adıma kadar sessiz kalsa bile bu soru atlanmaz — dosya
   analizinden çıkan liste asla kullanıcının kendi ihtiyaçlarının tam
   yerine geçmez.

7. **Tasarım şekli**: Çoğunlukla `class helper for X` / `record helper for X`
   düşün — mevcut bir tipe (TDateTime, TDataSet vb.) davranış eklemek bu
   şekilde daha ergonomik olur (bkz. `Help.DB.pas`'taki `TDataSetHelper`
   örneği). Sadece gerçekten bağımsız/çok-parametreli bir işlemse serbest
   fonksiyon yaz — mümkünse onu da bir helper metodundan çağrılan ince bir
   referans olarak sun. Büyük/karmaşık fonksiyonlar statik core fonksiyon
   (implementation içinde) + ince helper wrapper modeliyle yazılır;
   performans için `inline`/`constref` değerlendirilir. String döndüren
   fonksiyonlarda `string` mi `RawUtf8` mi kullanılacağını projenin o an
   hangi kütüphanelere (mORMot2 vb.) bağımlı olduğuna ve performans
   ihtiyacına göre seç — otomatik/varsayılan bir tercih yapma.

8. **"DEVAM ET" onayı**: Adım 7'ye kadarki her şey netleştiyse, üretime
   geçmeden önce kullanıcıdan "DEVAM ET" onayını bekle.

9. **Üretim** (test hariç). Yazmadan ÖNCE: `help.<scope>.pas` zaten varsa
   kullanıcıya bildir ve üzerine yazmadan önce onay al — sessizce
   üzerine yazma. Şu dosyaları yaz:
   - `help.<scope>.pas` — ana helper birimi.
   - `help.<scope>.md` — kullanım rehberi (örnekler, teknik notlar).
   - `docs\vendor\<dosyaadi>.md` — referans dosyanın dokümanı + SHA256
     checksum (PowerShell `Get-FileHash` ile hesaplanabilir). Bu doküman
     zaten varsa: dosyanın güncel hash'ini eskisiyle KARŞILAŞTIR (ucuz,
     her zaman yapılır) — farklıysa vendor dosyasının son incelemeden beri
     değiştiğini kullanıcıya bildir ve tam yeniden okuma gerekip
     gerekmediğini sor (hash aynıysa tam yeniden okumaya gerek yok).

   Benchmark testleri bu adımda AYRI bir dosya olarak üretilmez — adım
   10'da onay alınırsa `help.<scope>.Tests.pas` içine dahil edilir (bkz.
   adım 10). Ayrı bir `.test.bench.pas` dosyası/derleme birimi
   OLUŞTURULMAZ — DUnitX'in RTTI tabanlı fixture keşfi (`runner.UseRTTI`)
   sayesinde `[TestFixture]` olmayan bağımsız bir `RunAll` prosedürü zaten
   hiç çalıştırılmaz, bu yüzden ayrı dosya hem gereksiz hem de sessizce
   ölü kod üretir.

10. **Test onayı**: Üretimden SONRA "DUnitX testi hazırlansın mı?" diye
    sor — otomatik/anında değil. Evet denirse TEK bir `help.<scope>.Tests.pas`
    dosyası yazılır, içinde İKİ ayrı `[TestFixture]` class olur:
    - Doğruluk testleri (`dunitx_test_style.md`'ye %100 uyan, `[Test]`/
      `[TestCase]`/`[AutoNameTestCase]` ile data-driven).
    - Benchmark testleri: TStopwatch tabanlı, her metot `[Test]` +
      `[Category('Benchmark')]` ile işaretlenir (böylece ikisi aynı unit'te
      yaşar, sadece Category/grup ismiyle ayrılır — ayrı dosya değil).
      Benchmark metotları içinde konsola yazdırmak için `Writeln` YERİNE
      DUnitX'in `Status(...)` metodu kullanılır (DUnitX.Utils.TObjectHelper
      üzerinden her test sınıfında hazır gelir). Her benchmark metodu
      ölçümün SONUNDA en az bir anlamlı `Assert.*` çağrısı içermeli (ör.
      son hesaplanan değerin boş/sıfır/aralık-dışı olmadığını doğrulamak) —
      bu projenin DUnitX ortamında assertion'sız bir test "No assertions
      were made during the test" hatasıyla BAŞARISIZ sayılıyor
      (`runner.FailsOnNoAsserts` ayarından bağımsız olarak gözlemlendi).
    Her iki class da `initialization` bölümünde ayrı ayrı
    `TDUnitX.RegisterTestFixture(...)` ile kaydedilir. Derleme/otomatik
    çalıştırma ve `RunTests.dpr`/`.dproj`'a kayıt bu skill'in kapsamında
    DEĞİL — sadece test dosyasını yaz, proje dosyalarına dokunma (kullanıcı
    kendi ortamında derleyip test edecek, bkz. `reference_test_runner.md`).

    **Adil kıyas kuralı (bir oturumda gerçekten hatalı yazıldığı için
    buraya eklendi):** Bir benchmark iki yolu "A vs B" diye kıyaslıyorsa,
    ikisi GERÇEKTEN BAĞIMSIZ/FARKLI birer implementasyon olmalı. Eğer
    helper metodu (`_Xxx`) zaten içeride tam olarak o RTL/vendor fonksiyonu
    çağırıyorsa (ör. `_Year` zaten `DecodeDate` çağırıyor), o ikisini "hız
    kıyası" diye yan yana koyma — anlamsızdır, sadece aynı şeyi iki kere
    ölçersin (yalnızca Decode'un KENDİSİ farklı bir algoritmaya sahip
    olsaydı anlamlı olurdu). Ayrıca bir tarafın N kere, diğerinin 1 kere
    aynı alt-işlemi (ör. DecodeDate) çağırıp çağırmadığını her zaman
    kontrol et — çağrı sayısı eşit değilse kıyas hatalıdır, ya çağrı
    sayılarını eşitle ya da ne ölçtüğünü ("3 ayrı çağrı maliyeti" gibi)
    etiket/yorumda açıkça belirt.

## Nelere Dikkat

- Bir adımda büyük bir mimari sıçrama çıkarsa (ör. daha önce onaylanmış bir
  kararı değiştiren yeni bir vendor keşfi), sessizce devam etme — mutlaka
  durup sor.
- Helper çakışma kontrolü YAPILMAZ (kullanıcı tercihi) — ama aynı scope'ta
  birden fazla helper aktifse sadece EN YAKINI geçerli olur (Delphi dil
  kuralı); bu riski kullanıcıya bir kez hatırlat, ısrarcı olma.
- Kod içi tüm açıklamalar ve hata mesajları Türkçe.
