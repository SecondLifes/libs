# help.str — string Helper
`string` için genel amaçlı, `_` önekli metotlarla donatılmış `record helper`.
Kaynak: `src\core\help.str.pas`. Testler: `src\test\unit\help.str.Tests.pas`.

> **Dosya adı notu (2026-07-09):** Bu ünite önceden `help.string.pas`
> (`unit help.string;`) idi — bu, gerçek bir dcc32 derleme hatasıydı:
> `string` Delphi'de ayrılmış (reserved) bir kelime olduğu için noktalı
> unit adının bileşeni olamıyor (`E2029 Identifier expected but 'STRING'
> found`). Ünite hiçbir projeye bağlı olmadığı için bu şimdiye kadar hiç
> fark edilmemişti. `help.str` olarak yeniden adlandırıldı (bu doküman da
> `help.string.md` → `help.str.md` olarak taşındı) — bkz.
> `project_delphi_compiler_quirks.md`.

> **Mimari not — helper gölgelemesi (2026-07-09 düzeltildi):** RTL'in
> `System.SysUtils.TStringHelper`'ı `string` için zaten native `Trim`/
> `ToUpper`/`ToLower`/`Split`/`StartsWith`/`EndsWith`/`PadLeft`/`PadRight`/
> `Contains` gibi metotlar sağlıyor. Bu helper'daki HER metot `_` önekiyle
> isimlendirildi, AMA gerçek derlemeyle doğrulandı ki bu TEK BAŞINA
> yeterli değildi: Delphi'de bir tip için birden fazla helper aktifken
> sadece EN YAKINI kullanılabiliyor ve bu "en yakınlık" helper'ın görünür
> olduğu TÜM unit boyunca geçerli — yani `TRadStringHelper` görünürse,
> native `TStringHelper`'ın `_` önekli OLMAYAN metotları (`AStr.Trim`,
> `AStr.StartsWith` vb.) o unit'in her yerinde derleme hatası (E2003)
> verir. Bu yüzden `help.str.pas`'ın implementasyonu artık native helper
> metotlarına HİÇ dot-syntax ile dokunmuyor; onun yerine extension
> olmayan düz RTL fonksiyonlarını kullanıyor (`System.SysUtils.Trim`,
> `System.StrUtils.StartsStr/EndsStr/ContainsStr`, yerel `SplitBySubstring`).
> **Çağıran kod için sonuç:** bu unit'i `uses` eden bir yerde native
> `TStringHelper` metotlarına da (`AStr.Trim` gibi) dot-syntax ile ihtiyaç
> varsa ve `TRadStringHelper` orada daha yakın helper ise, aynı gölgeleme
> geçerlidir — native ihtiyaç için düz `Trim(S)`/`StrUtils` fonksiyonu
> kullanılmalı, `AStr.Trim` değil.

> Kaynaklar için bkz. `docs\vendor\...`: GpString, JclStrings,
> mormot.core.unicode.

## RawUtf8 / mORMot2 köprüsü

```pascal
var U: RawUtf8; B: TBytes;
U := 'Merhaba'._ToUtf8;
S := TRadStringHelper._FromUtf8(U);
B := 'Merhaba'._ToBytesUtf8;
S := TRadStringHelper._FromBytesUtf8(B);
```

## Türkçe-duyarlı büyük/küçük harf

RTL'in `ToUpper`/`ToLower`'ı Unicode invariant-case kullanır ve Türkçe 'i'
harfini 'İ' değil düz 'I' yapar — klasik Türkçe Delphi hatası. Bu üç metot
bunu düzeltir:

```pascal
ShowMessage('istanbul'._ToUpperTR);   // 'İSTANBUL'
ShowMessage('İZMİR'._ToLowerTR);      // 'izmir'
ShowMessage('merhaba dünya'._ToTitleCase); // 'Merhaba Dünya'
ShowMessage('merhaba-dunya'._ToTitleCase); // 'Merhaba-Dunya' (boşluk-dışı sınır da yakalanır)
ShowMessage('kullanici_adi'._ToCamelCase);  // 'kullaniciAdi'
ShowMessage('kullanici_adi'._ToPascalCase); // 'KullaniciAdi'
ShowMessage('KullaniciAdi'._ToSnakeCase);   // 'kullanici_adi'
ShowMessage('HTTPServer'._ToSnakeCase);     // 'http_server' (acronym sınırı)
ShowMessage('SHA256Hash'._ToSnakeCase);     // 'sha256_hash' (rakam→BÜYÜK harf sınırı)
```

> `SplitIntoWords` (dahili) üç sınır tanır: (1) camelCase küçük→BÜYÜK geçişi,
> (2) rakamdan BÜYÜK harfe geçiş, (3) ardışık BÜYÜK harflerden küçüğe geçiş
> (acronym sonu — son BÜYÜK harf bir sonraki sözcüğe kalır).

## Kırpma / Doldurma / Ortalama

```pascal
ShowMessage('abc'._Center(9));            // '   abc   '
ShowMessage('Çok uzun bir metin'._Truncate(10)); // 'Çok uzu...'
ShowMessage('1234567890123456'._Mask(4, 4));     // '1234********3456'
ShowMessage('123456'._Mask(-1, -1));       // '******' (negatif parametreler 0'a clamp edilir)
ShowMessage('ab'._RepeatText(3));         // 'ababab' (Move tabanlı, tek allocation)
ShowMessage('ab'._RepeatText(0));         // '' (0 veya negatif ACount -> boş)
ShowMessage('abc'._Reverse);              // 'cba'
```

## Guard / Ensure

```pascal
ShowMessage('help'._EnsureSuffix('.pas'));    // 'help.pas'
ShowMessage('help.pas'._EnsureSuffix('.pas')); // 'help.pas' (dokunmadı)
ShowMessage(''._DefaultIfEmpty('(boş)'));      // '(boş)'
ShowMessage('   '._DefaultIfWhiteSpace('(boş)')); // '(boş)'
```

## Sayısal/Boolean güvenli dönüşüm

```pascal
var N: Integer;
N := 'abc'._ToIntOrDefault(-1); // -1
if '42'._TryToInt(N) then ; // N=42
```

## Test / Karşılaştırma

```pascal
if 'Ahmet'._IsOneOf(['Ahmet','Mehmet']) then ;
if 'test.pas'._HasSuffixOf(['.pas','.dpr']) then ;
if 'Merhaba'._EqualsIgnoreCase('MERHABA') then ;
var Fark := 'dosya2'._CompareNatural('dosya10'); // < 0 (doğal sıralama)
var Fark2 := 'dosya999999999999999999999999'._CompareNatural('dosya2'); // > 0 (Int64 sınırını aşan rakam bloklarında da doğru, overflow yok)
var Mesafe := 'kitten'._LevenshteinDistance('sitting'); // 3
var Benzerlik := 'kitten'._SimilarityRatio('sitting'); // ~0.57
if 'help.pas'._IsWildcardMatch('*.pas') then ;
```

## Çıkarma (Extraction)

```pascal
ShowMessage('Merhaba'._Left(3));           // 'Mer'
ShowMessage('Merhaba'._Right(3));          // 'aba'
ShowMessage('Merhaba'._Right(-1));         // '' (negatif/sıfır ACount -> boş)
ShowMessage('a=1;b=2'._Before(';'));       // 'a=1'
ShowMessage('a=1;b=2'._After(';'));        // 'b=2'
ShowMessage('<v>42</v>'._Between('<v>', '</v>')); // '42'
var Parcalar := 'a, b , ,c'._SplitTrimmed(','); // ['a','b','c'] (boşlar atıldı, çoklu karakterli ayraç desteklenir)
```

## Diziler ile ilişki

```pascal
ShowMessage(TRadStringHelper._Join('-', ['2026','07','04'])); // '2026-07-04'
```

## Sınırlamalar (bilinçli, belgelendi)
- **Surrogate pair:** `_Reverse`, `_ToUpperTR`, `_ToLowerTR` UTF-16 code unit
  bazlı çalışır — emoji gibi surrogate pair (2 code unit) veya combining mark
  içeren metinlerde Unicode grapheme farkındalığı YOKTUR (`_Reverse` iki code
  unit'i ters çevirip geçersiz bir dizi üretebilir). Çoğunlukla ASCII/Türkçe
  alfabe metinleri için tasarlandı.
- `_Mask`/`_Right` negatif parametrelerde güvenli şekilde 0'a/boşa clamp
  edilir (yukarıdaki örneklere bkz.); `_SplitTrimmed` boş ayraçta tüm
  string'i tek (kırpılmış) eleman olarak döner.

## Kapsam Dışı (bilinçli, nedenle)
- RTL'in native `Trim`/`ToUpper`/`ToLower`/`PadLeft`/`PadRight`/`Split`/
  `StartsWith`/`EndsWith` — zaten aynı ergonomiyle native olarak var, ince
  `_` sarmalayıcının gerçek kazancı yok (yukarıdaki helper-gölgeleme notuna
  bkz. — bu, aslında ZORUNLU bir ayrım, tercih değil).
- GpString.pas'ın `NthEl`/`FirstEl`/`LastEl`/... ailesi — modern RTL `Split`
  ile örtüşüyor, gereksiz duplikasyon.
- `TJclStringBuilder`, `TJclTabSet`, `TStrings` hedefli fonksiyonlar, dosya
  sistemi hedefli fonksiyonlar, mutasyonlu (`var S: string`) tokenizer'lar —
  ayrıntı için `docs\vendor\project-jedi\jcl\jcl\source\common\JclStrings.md`.

## Notlar
- `_CompareNatural`/`_LevenshteinDistance`/`_SimilarityRatio` gibi algoritmik
  metotlar bağımsız yazıldı (vendor kaynağı yok) — "icat" kategorisinde.
  `_CompareNatural` rakam bloklarını artık `StrToInt64` yerine string olarak
  (sıfır kırpma + uzunluk + leksik) karşılaştırır — uzun rakam dizilerinde
  (Int64 sınırını aşan) `EConvertError` riski ortadan kalktı.
- `_ToCamelCase`/`_ToPascalCase`/`_ToSnakeCase`, mORMot2'nin `CamelCase`/
  `UnCamelCase`'inden ilham aldı ama kendi sözcük-bölme algoritmasını
  kullanır (bağımsız implementasyon, bkz. mormot.core.unicode.md notları).
- Interface `uses` listesi sadeleştirildi: sadece `System.SysUtils` (TBytes
  için) ve `mormot.core.base` (RawUtf8/WinAnsiString için) interface'te
  kalıyor; `System.Character`/`System.Math`/`System.Masks`/
  `System.Generics.Collections`/`mormot.core.unicode` implementation'a
  taşındı (sadece orada kullanılıyorlardı).
- Bu dosya gerçek `dcc32` ile derlendi ve doğrulandı; kalıcı DUnitX testleri
  (`help.str.Tests.pas`, `Rad_Test_GUI` üzerinden) 55/55 başarıyla geçti
  (2026-07-09).

## Düzeltme Geçmişi (2026-07-09, "1.md"/"2.md" incelemesi)
| # | Bulgu | Çözüm |
|---|---|---|
| 1 | Helper gölgelemesi — dosyanın kendi implementasyonu native `TStringHelper` metotlarını (`StartsWith`/`EndsWith`/`Trim`/`Contains`/`Split`/`string.Join`) dot-syntax ile çağırıyordu; gerçek derleme bunun E2003 hatasına yol açtığını kanıtladı (12 çağrı noktası) | Düz RTL fonksiyonlarına geçildi: `StartsStr`/`EndsStr`/`ContainsStr` (`System.StrUtils`), `System.SysUtils.Trim`, yerel `SplitBySubstring`, yerel `_Join` döngüsü. Ayrıca mORMot'un `overload` işaretsiz `Trim(RawUtf8)`'ının `System.SysUtils.Trim`'i tamamen gölgelediği ek bir gerçek sorun bulunup nitelenmiş çağrıyla (`System.SysUtils.Trim`) düzeltildi |
| 2 | `_CompareNatural` uzun rakam bloklarında `StrToInt64` overflow (`EConvertError`) riski taşıyordu | Rakam blokları string olarak (sıfır kırpma + uzunluk + leksik) karşılaştırılıyor |
| 3 | `SplitIntoWords` digit→BÜYÜK harf (`SHA256Hash`) ve ardışık BÜYÜK→küçük/acronym (`HTTPServer`) sınırlarını kaçırıyordu | İki yeni sınır koşulu eklendi |
| 4 | `_ToTitleCase` sadece boşluğu kelime sınırı sayıyordu | Sınır `IsLetterOrDigit` olmayan her karaktere genişletildi |
| 5 | `_RepeatText` döngüsel string concat kullanıyordu (performans) | `Move` tabanlı tek allocation |
| 6 | Interface `uses` listesi gereğinden genişti | Sadece interface'te gerekli olanlar (`System.SysUtils`, `mormot.core.base`) kaldı, geri kalanı implementation'a taşındı |
| 7 | `_Reverse`/`_ToUpperTR`/`_ToLowerTR` surrogate pair farkındalığı yok | Sınırlama belgelendi (kod değişikliği istenmedi) |
| 8 | `_Mask`/`_Right` negatif parametre sözleşmesi belirsizdi | Negatif değerler 0'a/boşa clamp edildi |
