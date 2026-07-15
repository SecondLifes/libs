# JclStrings (JEDI JCL)
JCL'nin dev string/karakter işleme kütüphanesi — test, dönüşüm, arama,
çıkarma, doğal (natural) sıralama karşılaştırma ve bir `TStringBuilder`
implementasyonu içerir.
Kaynak: `src\vendor\project-jedi\jcl\jcl\source\common\JclStrings.pas`
SHA256: `7CCC2FEB553435DA5491BAF0746958F1C7F471CBFE212FBD7B63F65FE3A17DF1`

## Ne İşe Yarar
`help.date.pas`'ın kaynağı olan JclDateTime.pas gibi, bu da JCL'nin en
kapsamlı ve olgun birimlerinden biri — Delphi ekosisteminde string
işlemlerinin "de-facto" referans kütüphanesi sayılabilir. `Str*` (string),
`Char*` (tek karakter) ve `TStrings` (liste) hedefli üç ayrı katman içerir;
`help.str.pas` için sadece scalar `string` hedefli katman kullanıldı.

## Gereksinimler
`System.Classes`, `System.SysUtils`, `JclAnsiStrings`, `JclWideStrings`,
`JclBase` (JCL'nin kendi temel birimleri).

## Temel Kullanım (help.str.pas'a alınanlar)

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `StrEnsurePrefix`/`StrEnsureSuffix`/`StrEnsureNoPrefix`/`StrEnsureNoSuffix` | Önek/sonek garantisi (varsa dokunma, yoksa ekle/çıkar) |
| `StrCenter(S, L, C)` | Metni belirli bir uzunlukta ortalar (RTL'de karşılığı yok) |
| `StrIsAlpha`/`StrIsAlphaNum`/`StrIsDigit` | Karakter sınıfı testleri |
| `StrIsOneOf(S, List)` | S, verilen listedeki değerlerden biri mi |
| `StrHasPrefix`/`StrHasSuffix`/`StrIHasPrefix`/`StrIHasSuffix` | Dizi halinde önek/sonek testi (büyük/küçük harf duyarlı veya değil) |
| `StrSame(S1, S2, CaseSensitive)` | Büyük/küçük harf duyarlı(sız) eşitlik |
| `StrBefore`/`StrAfter`/`StrBetween` | Alt metne göre önce/sonra/arası çıkarma |
| `StrLeft`/`StrRight`/`StrMid`/`StrChopRight`/`StrRestOf` | Sınır-güvenli alt dizi çıkarma |
| `StrRepeat(S, Count)` | Metni N kez tekrarlar |
| `StrReverse(S)` | Karakterleri ters çevirir |
| `CompareNaturalStr`/`CompareNaturalText` | "Doğal" sıralama karşılaştırması ("dosya2" < "dosya10") — RTL'de karşılığı yok |
| `TJclStringBuilder` | .NET tarzı StringBuilder — modern Delphi'de zaten `System.SysUtils.TStringBuilder` var, kapsam dışı |

## Örnek

```pascal
uses JclStrings;

var
  S: string;
begin
  S := StrEnsureSuffix('.pas', 'help.string'); // 'help.str.pas'
  S := StrCenter('abc', 9);                    // '   abc   '
  if CompareNaturalStr('dosya2', 'dosya10') < 0 then
    ShowMessage('dogal siralamada dosya2 once gelir');
end;
```

## Kapsam Dışı Bırakılanlar (help.str.pas için, nedenle)
- `TJclStringBuilder`/`TStringBuilder` — ayrı bir sınıf, `string` scalar
  tipinin helper'ı değil; modern Delphi'de zaten RTL'in kendi
  `System.SysUtils.TStringBuilder`'ı var.
- `TJclTabSet`, `StrExpandTabs`/`StrOptimizeTabs` — konsol'a özgü tab-stop
  hesaplama, bu VCL projesinin kapsamı dışı.
- `StringsToPCharVector`/`MultiSzToStrings`/vb. — `TStrings`/Win32 API
  interop hedefli, scalar `string` değil.
- `StrToStrings`/`StringsToStr`/`TrimStrings`/`AddStringToStrings` — `TStrings`
  hedefli; ileride bir `help.strings.pas` (TStrings helper) adayı olabilir.
- `FileToString`/`StringToFile` — dosya sistemi hedefli, string helper'ın
  kapsamı dışı.
- `StrToken`/`StrTokens`/`StrWord`/`StrIdent` — kaynak string'i `var S: string`
  ile MUTATE eden (yıkıcı) tokenizer'lar; helper'ın "Self'i bozma, yeni değer
  döndür" felsefesiyle uyuşmuyor.
- `DotNetFormat` — RTL'in kendi `Format`'ı zaten aynı işi görüyor, farklı bir
  sözdizimi ("{argX}") öğretmenin ek değeri düşük görüldü.
- `StrPadLeft`/`StrPadRight` — modern RTL'in native `TStringHelper.PadLeft/
  PadRight`'ı ile aynı ergonomiyi zaten sağlıyor (bkz. help.str.pas
  başlığındaki mimari not) — tekrar sarmalamanın kazancı yok.
