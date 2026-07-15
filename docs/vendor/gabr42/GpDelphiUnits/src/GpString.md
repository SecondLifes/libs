# GpString (gabr42 / GpDelphiUnits)
Eski/klasik (Clipper-dBase tarzı) delimited-string ayrıştırma ve birkaç
metin yardımcı fonksiyonu.
Kaynak: `src\vendor\gabr42\GpDelphiUnits\src\GpString.pas`
SHA256: `A91BF00C51908949A4E18E621472485D4E51EF4381FC1F1C5386F3BC7006B310`

## Ne İşe Yarar
`NthEl`/`FirstEl`/`LastEl`/`ButFirstEl`/`ButLastEl`/`SplitAtNthEl` ailesi,
dBase/Clipper'dan miras kalan, tek karakterli bir ayraçla (delimiter)
bölünmüş metinlerden N'inci elemanı çekmeye yarayan eski nesil bir API'dir.
Ayrıca yol/dosya adı escape'i (`MakeBackslash`/`StripBackslash`), basit bir
URL ayrıştırıcı (`GpParseURL`), hex/reverse-pos yardımcıları içerir.

## Gereksinimler
`System.SysUtils`.

## Temel Kullanım

| Fonksiyon | Ne İşe Yarar |
|---|---|
| `NthEl(x, elem, delim, checkQuote)` | Delimiter'la ayrılmış metinde N'inci elemanı döner |
| `Split(x, delim, checkQuote, elements)` | Metni bir `TElements` (`array of string`) dizisine böler |
| `TrimL`/`TrimR` | Sol/sağ boşluk kırpma (RTL `Trim`'den önceki eski API) |
| `ReplaceAll(x, chOrig, chNew)` | Tek karakter değiştirme |
| `First`/`Last`/`ButFirst`/`ButLast(x, num)` | İlk/son N karakter veya onlar hariç kalan |
| `PosR(subs, s)` | Sondan aramaya göre pozisyon (reverse `Pos`) |
| `HexStr(var num; byteCount)` | Ham bellek bloğunu hex metne çevirir |
| `MakeBackslash`/`StripBackslash` | Ters slaş escape/unescape |
| `GpParseURL(url, ...)` | Basit URL ayrıştırma (Proto/User/Pass/Host/Port/Path) |

## Örnek

```pascal
uses GpString;

var
  El: string;
  Parts: TElements;
begin
  El := NthEl('a,b,c', 2, ',', 0); // 'b'
  Split('a,b,c', ',', 0, Parts);   // Parts = ['a','b','c']
  ShowMessage(HexStr(SomeInt, SizeOf(SomeInt)));
end;
```

## Notlar
- `NthEl`/`Split`/`FirstEl`/`LastEl` ailesi, modern RTL'in `string.Split`
  (TArray<string> döner, tip-güvenli) fonksiyonuyla büyük ölçüde örtüşür —
  bu yüzden `help.str.pas`'a alınmadı (bkz. Rad Core'un
  [help.str.md](../../../../help.str.md) "Kapsam Dışı" bölümü).
- `GpParseURL` genel bir string helper'ın kapsamına girmiyor (ayrı bir domain,
  ileride bir `help.url.pas` adayı olabilir).
- `MakeBackslash`/`StripBackslash` path/dosya-yolu escape'ine özgü, genel
  string helper'dan çok bir `help.path.pas` adayı.
