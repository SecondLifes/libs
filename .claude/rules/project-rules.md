# AI Rule: Project Rules
Version: 1.10.0
Status: ACTIVE
Author: Delphi Expert
Son Güncelleme: 2026-07-09

## Kapsam
Tek bir mimari konuya (vendor, code-review vb.) özgü olmayan,
projede genel olarak uygulanacak operasyonel kurallar. Yeni genel kurallar
buraya, ayrı bir `##` başlığı altında eklenir.

## Dosya ve Fonksiyon İsimlendirme
1. İsimlendirmede snake_case kullanılır.

### Helper Dosyaları
> Yeni bir help.*.pas üretim süreci (referans dosya seçiminden test onayına
> kadar) için bkz. `.claude/skills/delphi-helper-builder/`.

## Test ve Dokümantasyon Zamanlaması
TestCase dosyası artık düzeltme/özellik uygulanırken (iş bitmeden) oluşturulur
veya güncellenir; ancak gerçek çalıştırma (`dcc32`/`run_tests.bat` ile fiilen
test etme) öncesi kullanıcı onayı alınır (2026-07-09 güncellemesi — bkz.
`ai/memory/conflict-report.md` ÇAKIŞMA 5). `docs\` kullanım kılavuzu için eski
kural geçerli: sadece tüm iş bittikten sonra, onay alınarak güncellenir.

## Yeni Kural Ekleme Süreci
Kullanıcı bir kural belirtip "kurallara ekle" dediğinde: kural **mutlaka**
optimize edilip kısaltılır (gereksiz tekrar, uzun cümle ve fazladan örnek
ayıklanır) — "mümkünse" değil, kesin bir adımdır; ardından bu dosyaya
(`project-rules.md`) uygun bir `##` başlığı altında eklenir. Kural zaten var
olan bir başlığa aitse o başlık güncellenir, yoksa yeni başlık açılır. Alt
konular numaralandırma (1.1, 1.2 …) yerine `###` alt başlıklarla ayrılır —
renumber riski taşımaz ve dosyanın geneliyle tutarlı kalır.

## Eleştiri Dosyası İnceleme Süreci
"Eleştiri dosyasını incele" komutu verildiğinde:
1. Belirtilen eleştiri (`.md`) dosyası ve ilgili kod incelenir.
2. Doğru bulunanlar, hatalı bulunanlar ve proje kuralları gereği zorunlu
   olanlar ayrı ayrı belirtilerek bir **plan** sunulur.
3. Kullanıcıdan onay alınmadan hiçbir değişiklik yapılmaz.
4. Onay sonrası, `docs\` klasöründe ilgili birime ait dokümantasyon kontrol edilir
   (ör. `help.db.pas` → `help.db.md`):
   - Doküman varsa: güncellenir, revize tarihi eklenir.
   - Doküman yoksa: class'lar, fonksiyonlar, parametreler kısa ve öz anlatılır;
     her biri için birer örnek eklenir.

## Vendor/Harici Dosya İnceleme Dokümantasyonu
Bir vendor/harici dosya incelenip ne işe yaradığı açıklandığında, `docs\` altında
bir `.md` dosyasına yazılır: proje içi dosyalarda (`src\vendor\...`) yol birebir
yansıtılır (ör. `...\GpTimestamp.pas` → `docs\vendor\...\GpTimestamp.md`); proje
dışı dosyalarda yol düzleştirilip `docs\vendor\<dosya_adı>.md` olarak yazılır.
İçerik: dosyanın amacı; class/fonksiyon/parametrelerin ne işe yaradığı kısa ve
anlaşılır anlatılır, her biri için birer örnek eklenir. Hedef `.md` zaten varsa/
çakışıyorsa kullanıcıya bildirilir, sessizce üzerine yazılmaz. Bu kural "Test ve
Dokümantasyon Zamanlaması" kuralından bağımsızdır — onay beklemeden yazılabilir.

## Genel Amaçlı Fonksiyonların Yeri
Belirli bir birime özgü olmayan, genel kullanılabilecek fonksiyon/procedure'ler
kendi biriminin global/private scope'una değil, `rad.utils.pas`'taki `TUtils`
sınıfına `class function`/`class procedure` olarak eklenir (ör.
`class procedure TUtils.InUI(AProc: TProc);`).

## Versiyon ve Revizyon Disiplini
Bir rules dosyasının içeriği değiştiğinde, dosya başındaki `Version` alanı
(minor bump, ör. 1.0.0 → 1.1.0) ve `Son Güncelleme` tarihi de birlikte
güncellenir. Sadece kural metni değişir, versiyon/tarih güncellenmezse
değişiklik eksik sayılır.
