# TSmartParam Kod Incelemesi

Kaynak: `src/core/rad.cache.pas`  
Odak: `TSmartParam` record'u ve `TSmartCache` icindeki kullanimlari  
Ilgili testler: `src/test/unit/rad.cache.Tests.pas`  
Ilgili dokuman: `docs/rad.cache.md`

## Genel Degerlendirme

`TSmartParam`, proje icinde `Variant` tabanli esnek deger tasiyici olarak pratik bir rol ustleniyor. Integer, Double, string, Boolean, DateTime, `TObject` ve `IInterface` icin tek tip container saglamasi `TSmartCache` API'sini sade tutuyor.

Mevcut testler temel gidis-donus, null, object referansi ve interface destegini kapsiyor. Daha onceki `AsObj<T>` guvenlik problemi de `T: class` kisiti ve dogrudan pointer cast ile buyuk olcude temizlenmis.

Yine de record'un icinde `Variant` yonetilen alan oldugu icin dogrudan `TVarData(FValue)` yazan bolumlerde ciddi yasam dongusu riski var. En onemli bulgu bu.

Bu inceleme statiktir; bu oturumda Delphi derlemesi veya DUnitX test calistirmasi yapilmadi.

## Bulgular

### 1. Yuksek: `TVarData(FValue)` ile dogrudan yazmadan once eski managed `Variant` temizlenmiyor

Konumlar:

- `src/core/rad.cache.pas:125` - `SetValue(Integer)`
- `src/core/rad.cache.pas:132` - `SetValue(Double)`
- `src/core/rad.cache.pas:145` - `SetValue(Boolean)`
- `src/core/rad.cache.pas:152` - `SetValue(TDateTime)`
- `src/core/rad.cache.pas:171` - `SetValue(TObject)`

Bu metotlar `FValue` icindeki `Variant` alanina `TVarData` uzerinden dogrudan yaziyor:

```pascal
FvType := varInteger;
TVarData(FValue).VType    := varInteger;
TVarData(FValue).VInteger := V;
```

Eger `FValue` daha once string, interface, array veya baska managed bir `Variant` tasiyorsa, bu dogrudan yazma eski degerin referans sayacini dusurmeden `VType` alanini ezebilir. Bu bellek sizintisi veya interface/string omur hatasina yol acabilir.

Oneri:

- En sade ve guvenli cozum: manuel `TVarData` yazmak yerine `FValue := V` kullan.
- Mutlaka manuel yazilacaksa once `VarClear(FValue)` cagrilmali.
- `SetValue(TObject)` icin de once `VarClear(FValue)` yapilmali, sonra pointer saklanmali.

Guvenli yon:

```pascal
procedure TSmartParam.SetValue(const V: Integer);
begin
  FValue := V;
  FvType := TVarData(FValue).VType;
end;
```

Ek test:

```pascal
P.SetValue('uzun metin');
P.SetValue(42);
Assert.AreEqual(42, P.AsInteger);

P.SetValue(SomeInterface);
P.SetValue(1);
```

Bu test tek basina leak'i yakalamayabilir; FastMM leak report veya referans sayaci gozlemiyle desteklenmeli.

### 2. Yuksek: `SetValue(TObject)` ham pointer sakliyor; `AsObj<T>` freed object'i ayirt edemez

Konumlar:

- `src/core/rad.cache.pas:171`
- `src/core/rad.cache.pas:240`
- `docs/rad.cache.md:61`
- `docs/rad.cache.md:137`

`SetValue(TObject)` nesneyi sahiplenmeden sadece adresini `Variant` icinde `varInt64` olarak sakliyor. Bu tasarim dokumanda belirtilmis, fakat risk buyuk: nesne free edildikten sonra `AsObj<T>` ayni adresi donebilir ve kullanimda AV uretebilir.

Oneri:

- Bu davranis korunacaksa `AsObj<T>` metodu icin "raw borrowed pointer" notu public dokumanda daha sert vurgulanmali.
- Alternatif API eklenebilir:
  - `SetObjectRef` / `AsObjectRef<T>` adlariyla tehlike daha gorunur olur.
  - Sahiplenen kullanim gerekiyorsa ayri bir container veya `IInterface` tabanli yasam dongusu tercih edilmeli.
- `AsObj<T>` icinde en azindan runtime type check yapilabilir:

```pascal
var Obj := TObject(Pointer(NativeInt(FValue)));
if Obj is T then
  Result := T(Obj)
else
  Result := nil;
```

Bu freed-object riskini cozmez, ama yanlis tipe cast riskini azaltir.

### 3. Orta: `AsObj<T>` yanlis class tipi istendiginde kontrolsuz cast yapiyor

Konum: `src/core/rad.cache.pas:240`

`T: class` kisiti iyi bir iyilestirme, fakat saklanan nesne `TStringList` iken `AsObj<TComponent>` gibi uyumsuz bir tip istenirse metot yine pointer'i `T` olarak cast eder. Bu hemen patlamayabilir ama sonraki method/property erisiminde bellek hatasi uretebilir.

Oneri:

- Yukaridaki `Obj is T` kontrolu eklenmeli.
- Yanlis tipte `nil` donmek mi, exception firlatmak mi istendigi testle sabitlenmeli.

Ek test:

```pascal
P.SetValue(TStringList.Create);
Assert.IsTrue(P.AsObj<TComponent> = nil);
```

### 4. Orta: `AsIntf<T>` her cagrida RTTI context ve type lookup yapiyor

Konum: `src/core/rad.cache.pas:248`

`AsIntf<T>` her cagrida `TRttiContext.Create`, `GetType(TypeInfo(T))`, `TRttiInterfaceType(...).GUID` yapiyor. Tekil kullanimda sorun degil, fakat cache icinde sik cagrilan interface degerlerinde gereksiz maliyet yaratir.

Oneri:

- `GetTypeData(TypeInfo(T))^.Guid` ile RTTI context olusturmadan GUID alinabilir.
- Ya da generic olmayan bir overload eklenebilir:

```pascal
function AsIntf(const AGuid: TGUID; out AValue): Boolean;
```

Performans notu:

- Bu optimizasyon dogruluk kadar kritik degil, ama cache/command/event gibi sicak yollarda RTTI allocation ve lookup maliyetini azaltir.

### 5. Orta: `AsInteger`, `AsFloat`, `AsBoolean`, `AsDateTime` donusumleri exception firlatabilir; Try* API yok

Konumlar:

- `src/core/rad.cache.pas:198`
- `src/core/rad.cache.pas:204`
- `src/core/rad.cache.pas:218`
- `src/core/rad.cache.pas:224`

Tip uyusmazsa metotlar `Variant` cast'e dusuyor:

```pascal
else Result := Integer(FValue);
```

Bu tasarim hizli ve kisa, ama `TSmartCache.Get('x', 0)` gibi yerde beklenmeyen string veya null varsa exception firlayabilir. Cache kullaniminda "varsayilan don" beklentisi olabilecegi icin bu durum dokumante edilmeli veya Try API eklenmeli.

Oneri:

```pascal
function TryAsInteger(out AValue: Integer): Boolean;
function TryAsFloat(out AValue: Double): Boolean;
function TryAsBoolean(out AValue: Boolean): Boolean;
function TryAsDateTime(out AValue: TDateTime): Boolean;
```

### 6. Orta: `IsEmpty` yalniz `FvType = varEmpty` kontrol ediyor; record initialization sozlesmesi testlenmeli

Konum: `src/core/rad.cache.pas:193`

`TSmartParam` managed field iceren bir record oldugu icin Delphi normal lokal degiskenlerde alanlari initialize eder. Yine de `IsEmpty` kontrati testlerde dogrudan yok. `Default(TSmartParam).IsEmpty` veya yeni local record'un davranisi sabitlenmeli.

Oneri:

```pascal
var P: TSmartParam;
Assert.IsTrue(P.IsEmpty);
Assert.IsFalse(P.IsNull);
```

Eger bu davranis her derleyici hedefinde garanti edilmek istenirse `class function Empty: TSmartParam` eklemek daha acik olur.

### 7. Dusuk: `TSmartParam.Test` production unit icinde kalmis

Konum: `src/core/rad.cache.pas:56`, `src/core/rad.cache.pas:313`

`TSmartParam.Test` production unit icinde mini assertion testi gibi duruyor. Bu artik `src/test/unit/rad.cache.Tests.pas` tarafinda daha temiz kapsaniyor. Production API yuzeyinde test metodu kalmasi gereksiz ve kullanicinin kafasini karistirabilir.

Oneri:

- `Test` metodu public API'den kaldirilsin.
- Icerigindeki senaryolar DUnitX testlerine tasinsin veya mevcut testlerle zaten kapsaniyorsa silinsin.

### 8. Dusuk: `TVarType` ile `Variant` tipi her zaman ayni semantigi anlatmiyor

Konum: `src/core/rad.cache.pas:16`, `src/core/rad.cache.pas:17`

`vType` property ham `TVarType` donduruyor. Bu yararli ama `TObject` icin `varInt64` kullanilmasi gibi durumlarda tip bilgisi semantik olarak "object" demiyor. Event tarafinda `AOldType: TVarType` aliciya geliyor; `varInt64` goren handler bunun object pointer mi normal Int64 mu oldugunu ayirt edemez.

Oneri:

- Ayrica semantik bir enum eklenebilir:

```pascal
TSmartParamKind = (spEmpty, spNull, spInteger, spFloat, spString, spBoolean, spDateTime, spObject, spInterface, spVariant);
```

- `vType` backward compatible kalabilir; yeni `Kind` property daha anlamli olur.

## Performans Notlari

### Manuel `TVarData` yazimi hiz kazandirabilir ama guvenlik maliyeti yuksek

Integer/Double/Boolean/DateTime icin dogrudan `TVarData` yazimi micro-optimization gibi gorunuyor. Ancak eski managed variant temizlenmedigi surece bu optimizasyon guvenli degil. Once dogruluk duzeltilmeli; performans gerekiyorsa `VarClear + TVarData` ile `FValue := V` gercek benchmark ile karsilastirilmali.

### `AsIntf<T>` RTTI maliyeti azaltilabilir

Interface lookup sicak yolda kullaniliyorsa `TRttiContext` yerine `TypeInfo/GetTypeData` yaklasimi daha ucuz olur.

### `TObject` icin `Variant` kullanmak gereksiz agir

Object pointer saklamak icin `Variant(varInt64)` kullaniminda hem semantik karisiyor hem de cast maliyeti var. Eger `TSmartParamKind` eklenirse object pointer ayri bir `NativeInt` alanda saklanabilir. Bu daha temiz ve hizli olur, ama record layout/API degisimi oldugu icin kontrollu yapilmali.

## Ekleme Onerileri

### 1. `Clear` veya `SetEmpty`

`SetNull` var ama "hic deger yok" durumuna geri donmek icin acik bir API yok.

```pascal
procedure Clear;
```

Bu `FValue := Unassigned; FvType := varEmpty;` gibi davranabilir.

### 2. `Kind` property

`TVarType` yerine daha domain odakli bir tip bilgisi:

```pascal
property Kind: TSmartParamKind read FKind;
```

Bu ozellikle event handler'larinda object pointer ile Int64 ayrimini netlestirir.

### 3. `TryAs*` metotlari

Exception'siz okuma isteyen cache kullanimlari icin:

```pascal
function TryAsString(out AValue: string): Boolean;
function TryAsInteger(out AValue: Integer): Boolean;
```

### 4. Owned object tasarimi ayri tutulmali

`TSmartParam` mevcut haliyle object'i sahiplenmiyor. Eger sahiplenme gerekecekse ayni metoda boolean parametre eklemek yerine ayri bir tip veya acik adli factory daha guvenli olur:

```pascal
class function NewObjectRef(const V: TObject): TSmartParam;
class function NewOwnedObject(const V: TObject): TSmartParam;
```

Owned varyant icin record copy semantigi cok dikkatli tasarlanmalidir; aksi halde double-free riski dogar.

## Test Onerileri

- `SetValue(string)` sonra `SetValue(Integer)` tekrarli dongude leak uretmiyor mu.
- `SetValue(IInterface)` sonra scalar deger ataninca interface referans sayaci dogru dusuyor mu.
- `Default(TSmartParam).IsEmpty` beklenen sonucu veriyor mu.
- `AsObj<T>` yanlis class tipi istenince beklenen davranis neyse testlenmeli.
- Freed object referansi dokumante edilen sekilde tehlikeli; en azindan bu davranis test adiyla gorunur hale getirilebilir.
- `AsIntf<T>` desteklenmeyen interface icin `nil` donuyor mu.
- `AsInteger/AsDateTime` uyumsuz tipte exception davranisi dokumante/test edilmeli veya `TryAs*` eklenmeli.

## Oncelikli Aksiyon Plani

1. `SetValue` scalar/object overload'larinda eski `Variant` degerinin dogru temizlenmesini sagla.
2. `AsObj<T>` icine runtime type check ekle veya kontrolsuz cast sozlesmesini cok acik dokumante et.
3. `TSmartParam.Test` metodunu production API'den kaldir.
4. `TryAs*` metotlarini ekle veya mevcut exception davranisini test/dokumanla sabitle.
5. `AsIntf<T>` RTTI maliyetini azalt.
6. Uzun vadede `TVarType` yanina `TSmartParamKind` ekleyerek object/interface semantigini netlestir.

## Kisa Sonuc

`TSmartParam` pratik ve kullanisli bir container, fakat `Variant` managed alan oldugu icin `TVarData(FValue)` dogrudan yazimlari dikkat istiyor. En kritik duzeltme, eski string/interface/managed variant degerlerinin scalar veya object atamalarinda temizlenmesini garanti etmek. Bu cozuldugunde kalan maddeler daha cok guvenlik, okunabilirlik ve performans iyilestirmesi niteliginde.
