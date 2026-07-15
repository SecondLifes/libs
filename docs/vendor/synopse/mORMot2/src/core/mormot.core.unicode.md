# mormot.core.unicode — string/RawUtf8/WinAnsi Köprüsü Bölümü (Synopse mORMot2 core)
Kaynak: `src\vendor\synopse\mORMot2\src\core\mormot.core.unicode.pas`
SHA256: `BC474098458C539C6A7C0E3AC4A58E949A7F63CF3A97260291A0A67C2440024D` (tüm dosya)

> Not: `mormot.core.unicode.pas` çok geniş bir birimdir (encoding tabloları,
> UTF-8 düşük seviye pointer fonksiyonları, `TSynAnsiConvert` sınıf ailesi
> vb.). Bu doküman SADECE `help.str.pas` tasarımı sırasında incelenen
> **string ↔ RawUtf8/WinAnsiString dönüşüm ekseni** ve birkaç case-conversion
> fonksiyonunu kapsar — dosyanın tamamının analizi değildir.

## Ne İşe Yarar
Delphi'nin native Unicode `string`'i ile mORMot2'nin performans-kritik
`RawUtf8` (UTF-8 kodlu `RawByteString`) ve Windows'a özgü `WinAnsiString`
tipleri arasında dönüşüm sağlayan serbest fonksiyonlar. Bu proje mORMot2'yi
yoğun kullandığı için `help.str.pas`'ın en önemli "eksen" analizi budur.

## Temel Kullanım

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `StringToUtf8(const Text: string): RawUtf8` | `string` → `RawUtf8` (UTF-8) |
| `Utf8ToString(const Text: RawUtf8): string` | `RawUtf8` → `string` (ters yön) |
| `StringToWinAnsi(const Text: string): WinAnsiString` | `string` → Windows-1252 (WinAnsi) |
| `WinAnsiToUnicodeString(const WinAnsi: WinAnsiString): UnicodeString` | WinAnsi → `string` (ters yön) |
| `StringToAnsi7(const Text: string): RawByteString` | `string` → 7-bit ASCII (sadece ASCII karakterler için) |
| `Ansi7ToString(const Text: RawByteString): string` | 7-bit ASCII → `string` (ters yön) |
| `IsUpper(const S: RawUtf8): boolean` / `IsLower(...)` | RawUtf8 için büyük/küçük harf testi |
| `UpperCase`/`LowerCase(const S: RawUtf8): RawUtf8` | RawUtf8 için hızlı (pointer-tabanlı) büyük/küçük harf dönüşümü |
| `CamelCase`/`UnCamelCase`/`LowerCamelCase`/`TitleCaseSelf` | Identifier-tarzı camelCase dönüşümleri (RawUtf8 üzerinde) |
| `IsValidUtf8(const source: RawByteString): boolean` | Baytların geçerli UTF-8 olup olmadığını doğrular |

## Örnek

```pascal
uses mormot.core.unicode;

var
  S: string;
  U: RawUtf8;
begin
  S := 'Merhaba Dünya';
  U := StringToUtf8(S);           // RawUtf8'e (UTF-8) çevir
  S := Utf8ToString(U);           // geri çevir
  if IsValidUtf8(RawByteString(U)) then
    ShowMessage('Gecerli UTF-8');
end;
```

## Notlar
- `help.str.pas`'ın `_ToUtf8`/`_FromUtf8`/`_ToWinAnsi`/`_FromWinAnsi`
  metotları doğrudan bu fonksiyonların ince sarmalayıcısıdır.
- `CamelCase`/`UnCamelCase`/`TitleCaseSelf` incelendi ama `help.str.pas`'ın
  `_ToCamelCase`/`_ToPascalCase`/`_ToSnakeCase` metotlarına DOĞRUDAN
  sarmalanmadı — bu üçü yerine bağımsız bir sözcük-bölme algoritması
  yazıldı, çünkü mORMot2'nin identifier-özel varsayımlarının genel `string`
  girdisi için ne kadar öngörülebilir olduğu bu oturumda doğrulanmadı; kendi
  implementasyonumuz daha kolay test edilebilir/doğrulanabilir.
- Düşük seviye UTF-8 pointer fonksiyonları (`GetHighUtf8Ucs4`, `NextUtf8Ucs4`,
  `TUtf8Table` vb.) `help.str.pas`'ın ergonomik hedefine uymadığı için
  kapsam dışı bırakıldı.
