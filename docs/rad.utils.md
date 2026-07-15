# rad.utils.pas — Kullanım Kılavuzu

## Ne İşe Yarar

`rad.utils.pas`, projeye özgü genel amaçlı (kategori-dışı) yardımcı tip ve fonksiyonları barındırır. Şu an iki bağımsız parça içerir:

- **`TResult<T>`** — bir işlemin başarı/hata sonucunu (exception fırlatmadan) taşıyan, allocation'sız (stack üzerinde çalışan) generic record.
- **`GenerateFluentCode`** — bir class'ı RTTI ile inceleyip, onu **fluent (zincirlenebilir) + interface tabanlı** bir sisteme çevirecek HAZIR PASCAL KAYNAK KODUNU (string olarak) üreten kod üretici (code generator).

## `TResult<T>`

Bir fonksiyonun sonucunu, exception fırlatmadan `IsSuccess`/`ErrorMsg`/`Value` ile taşımak için kullanılır.

```pascal
function BolmeYap(A, B: Integer): TResult<Integer>;
begin
  if B = 0 then
    Result := TResult<Integer>.Failure('Sıfıra bölme')
  else
    Result := TResult<Integer>.Success(A div B);
end;

var R := BolmeYap(10, 0);
if R.IsSuccess then
  WriteLn(R.Value)
else
  WriteLn('Hata: ' + R.ErrorMsg);
```

`Value` property'si, `IsSuccess=False` iken okunursa `EInvalidOpException` fırlatır — `TryGetValue` ile güvenli (exception'sız) okuma da mümkündür.

## `GenerateFluentCode` — RTTI Tabanlı Fluent/Interface Kod Üretici

### Ne Yapar, Ne Yapmaz

Verilen bir class'ı (`GenerateFluentCode(AClass: TClass)`) RTTI ile inceler ve onu sarmalayan bir **interface** + bu interface'i implemente eden bir **class** için Pascal kaynak kodunu **string olarak** döner.

**ÇALIŞTIRILMAZ/derlenmez** — yalnızca metindir. Kullanıcı, dönen string'i gözden geçirip projeye elle ekler.

### Kurallar

| Kaynak (AClass) | Üretilen |
|---|---|
| Class adı `TXxx` | Interface adı `IXxx` (T'siz + I önekiyle); `T` ile başlamıyorsa doğrudan `I` + ad. |
| — | İmplementasyon class adı: `TXxxFluent` (orijinal ad + `Fluent`). |
| Her zaman | `function AsInstance: TXxx;` — sarmalanan ham örneğe kaçış kapısı. |
| Doğrudan tanımlı (kalıtılmamış), public/published **basit property** (event property'ler dahil, ör. `TNotifyEvent`) | `function Set<Prop>(const a<Prop>: <Tip>): I<Isim>;` (fluent, zincire devam eder — yalnızca yazılabilirse) ve `function Get<Prop>: <Tip>;` (yalnızca okunabilirse). |
| Doğrudan tanımlı **indeksli (array) property** (ör. `property Items[Index: Integer]: T`) | `function Set<Prop>(<index parametreleri>; const aValue: <Tip>): I<Isim>;` ve `function Get<Prop>(<index parametreleri>): <Tip>;` |
| Doğrudan tanımlı public **method** (property accessor'ları hariç — onlar zaten private/protected olduğu için otomatik elenir) | AYNI isim ve imzayla **pass-through** (fluent DEĞİLDİR, orijinal dönüş tipini korur). Aynı isimde birden fazla (overload) metod varsa `overload;` otomatik eklenir. |

Üretilen constructor'a `AAutoFree: Boolean = False` parametresi eklenir; `True` verilirse üretilen destructor `FInstance.Free` çağırır (varsayılan `False` — sarmalanan örneğin ömrü çağıranın sorumluluğunda kalır, wrapper Free etmez).

### Kullanım Örneği

```pascal
type
  TSiparis = class
  private
    FMusteri: string;
    FOnTamamlandi: TNotifyEvent;
    function GetTutar: Currency;
    procedure SetTutar(const Value: Currency);
  public
    property Musteri: string read FMusteri write FMusteri;
    property Tutar: Currency read GetTutar write SetTutar;
    property OnTamamlandi: TNotifyEvent read FOnTamamlandi write FOnTamamlandi;
    procedure Onayla(const aNot: string);
  end;

// ...
var Kod := GenerateFluentCode(TSiparis);
WriteLn(Kod); // veya bir dosyaya yaz, incele, elle projeye ekle
```

`Kod` şuna benzer bir metin döner (özetlenmiş):

```pascal
  ISiparis = interface
    function AsInstance: TSiparis;

    function SetMusteri(const aMusteri: string): ISiparis;
    function GetMusteri: string;
    function SetTutar(const aTutar: Currency): ISiparis;
    function GetTutar: Currency;
    function SetOnTamamlandi(const aOnTamamlandi: TNotifyEvent): ISiparis;
    function GetOnTamamlandi: TNotifyEvent;

    procedure Onayla(const aNot: string);
  end;

  TSiparisFluent = class(TInterfacedObject, ISiparis)
  strict private
    FInstance: TSiparis;
    FAutoFree: Boolean;
  public
    constructor Create(AInstance: TSiparis; AAutoFree: Boolean = False);
    destructor Destroy; override;
    function AsInstance: TSiparis;
    function SetMusteri(const aMusteri: string): ISiparis;
    ...
  end;

// -- implementation bölümüne --
constructor TSiparisFluent.Create(AInstance: TSiparis; AAutoFree: Boolean = False);
begin
  inherited Create;
  FInstance := AInstance;
  FAutoFree := AAutoFree;
end;
...
```

Elle eklendikten sonra kullanım:

```pascal
var S: ISiparis := TSiparisFluent.Create(TSiparis.Create, True); // AAutoFree=True: S serbest kalınca TSiparis de Free edilir
S.SetMusteri('Ahmet').SetTutar(150.0).Onayla('Kapıda ödeme');
```

### Sınırlamalar / Dikkat Edilmesi Gerekenler

- **Tip adı üretimi RTTI (`TRttiType.Name`) tabanlıdır ve test edildi.** Generic bir tip (ör. `TArray<TValue>`) TAM NİTELİKLİ üretilir (`TArray<System.Rtti.TValue>`) — bu hâlâ geçerli/derlenebilir Pascal'dır, sadece kısaltılmamıştır (bkz. `GenerikArrayParametreliMetodDaUretilir` testi).
- **Class helper sızıntısı — RTTI seviyesinde DÜZELTİLEMEZ.** `AClass`'ın declare edildiği unit'te o an AKTİF bir class helper varsa (ör. `DUnitX.Utils`'taki `TObjectHelper = class helper for TObject` — bu proje test dosyalarında hep aktiftir), derleyici o helper'ın metodlarını `AClass`'ın RTTI'sine SANKİ DOĞRUDAN TANIMLIYMIŞ GİBİ gömer; `TRttiMethod.Parent` bile `AClass`'ı gösterir, bu yüzden çalışma zamanı RTTI'sinden ayıklanamaz (denendi, işe yaramadı — bkz. aşağıdaki "Gerçek Sorun" bölümü). **Üretilen kodu her zaman gözden geçirin; beklenmeyen fazladan metod görürseniz elle çıkarın** — bu, aracın doğal/kabul edilmiş bir sınırlamasıdır (kullanıcı kararı: "bu tip yapılarda fonksiyon üretilir, parametre olarak bilgi geçilir, elle düzeltilir — mecburen böyle olması gerekiyor").
- **Yalnızca DOĞRUDAN tanımlı üyeler** dikkate alınır (class helper sızıntısı hariç, yukarıya bkz.) — normal kalıtılan property/method'lar üretilen koda dahil EDİLMEZ.
- Property adları Pascal'da zaten tekil olmak zorunda olduğundan Set/Get'lerde `overload;` hiç gerekmez — bu yalnızca ham (property olmayan) public metodlar için üretilir.
- **Yalnızca `class` destekleniyor — `record` DEĞİL.** Bkz. aşağıdaki "Geliştirme Sırasında Bulunan Gerçek Sorun".

## Geliştirme Sırasında Bulunan Gerçek Sorunlar

### 1. Class Helper Sızıntısı (kabul edilen sınırlama)

İlk testte `TDenemeSinifi`'ye hiç yazılmamış `Log`/`Status`/`WriteLn` metodları üretilen koda karıştı. Sebep: test unit'i `DUnitX.TestFramework`'ü (dolayısıyla `DUnitX.Utils.TObjectHelper`'ı) `uses` ediyor; bu helper `TDenemeSinifi` derlenirken aktif olduğu için derleyici onu RTTI'ye gömdü. Düzeltme denemesi (`Meth.Parent <> RttiType` / `Prop.Parent <> RttiType` filtreleri — indeksli property'lerde zaten olan deseni metod/basit property'lere de uygulamak) **işe yaramadı**: `Meth.Parent` bu durumda da `TDenemeSinifi`'yi gösteriyor, ayırt edilemiyor. Filtreler kod kalitesi için (zararsız, savunma amaçlı) tutuldu ama sorunu ÇÖZMÜYOR. **Kabul edilen davranış:** üretilen kod her zaman gözden geçirilmeli.

### 2. Record Desteği Denendi, Kaldırıldı

İlk sürümde `GenerateFluentCode(ATypeInfo: PTypeInfo)` overload'uyla record desteği de vardı (`FInstance` alanı `^TXxx` pointer olarak tutulup `^.` ile erişilecekti, `AutoFree` record'da anlamsız olduğu için üretilmiyordu). Gerçek `dcc32` derlemesi + DUnitX çalıştırmasıyla test edilirken şu tespit edildi:

**Delphi 13.1 Athens'in (derleyici 37.0) `System.Rtti`'sinde record'lardaki property'ler `TRttiProperty` olarak HİÇ yansıtılmıyor** — `TRttiStructuredType.GetDeclaredProperties`, aynı desendeki (private accessor metodlu) bir property class'ta sorunsuz dönerken, birebir aynı property record'da BOŞ dönüyor. Sebep aranırken en geniş `{$RTTI EXPLICIT METHODS([vcPrivate,vcProtected,vcPublic,vcPublished]) PROPERTIES([...]) FIELDS([...])}` direktifi doğrudan test record'unun üzerine eklenip tekrar derlendi — **sonuç değişmedi**. Bu, kod tarafındaki bir filtreleme hatası değil, gerçek bir derleyici/RTTI sınırlaması.

**Karar:** Record desteği tamamen kaldırıldı, yalnızca `class` destekleniyor (kullanıcı kararı — "record olayını komple iptal edelim sadece class yeterli"). Bir record'u fluent/interface'e çevirmek isteyen, önce onu class'a taşımalı.

## Tipler ve Fonksiyonlar

| İsim | Parametreler | Ne işe yarar |
|---|---|---|
| `TResult<T>` | — | Exception'sız başarı/hata sonucu taşıyan record. |
| `GenerateFluentCode` | `AClass: TClass` | Bir class'ı fluent/interface kaynak koduna (string) çevirir. |

## Test Kapsamı

`src\test\unit\rad.utils.Tests.pas` — `TGenerateFluentCodeTestleri`, gerçek `dcc32` (MSBuild üzerinden `RunTests.dproj`, DEBUG) ile derlenip DUnitX konsol runner'ında çalıştırılarak doğrulandı (**12/12 test geçti**):

- `NilClassVerilirseExceptionFirlatir` — `AClass=nil` koruması.
- `InterfaceAdiTOnekiDusurulupIEklenerekUretilir`, `ImplementasyonClassAdiFluentEkiyleUretilir` — isimlendirme kuralları.
- `BasitPropertyIcinSetVeGetFluentImzasiUretilir` — doğrudan field'a bağlı property (Adi).
- `AccessorMetoduIleYazilmisPropertyDeUretilir` — private accessor metodlu property (Yasi) — class'ta bunun sorunsuz çalıştığı, record'daki arızanın (yukarıda) SEBEBİNİN "accessor'lı property" değil özel olarak "record" olduğunu doğrulayan test.
- `EventPropertyIcinDeSetVeGetUretilir` — event (`TNotifyEvent`) property.
- `PublicMetodAyniImzaIlePassThroughUretilir` — pass-through metod üretimi.
- `GenerikArrayParametreliMetodDaUretilir` — `TArray<TValue>`/`TValue` gibi generic bir imzanın (kullanıcının orijinal örneğiyle birebir) tam nitelikli ama derlenebilir üretildiğini doğrular.
- `AyniIsimliOverloadMetodlaraOverloadEklenir` — `overload;` işaretleme.
- `AsInstanceHerZamanUretilir` — kaçış kapısı metodu.
- `AutoFreeParametresiVeDestructorUretilir` (Kategori: `AutoFree`) — AutoFree/destructor üretimi.
- `IndeksliPropertyIcinIndexParametreliSetGetUretilir` (Kategori: `Indeksli Property`) — indeksli property desteği.

**Not 1:** İlk derleme+çalıştırma turunda `RecordPropertySetGetPointerErisimiIleUretilir` testi BAŞARISIZ olmuştu — bu, yukarıdaki "Gerçek Sorun #2" bölümünde açıklanan record/RTTI sınırlamasının bizzat kanıtıydı ve record desteğinin kaldırılması kararına yol açtı.

**Not 2:** Ayrıca bir `ClassHelperMetodlariSizmaz` testi denendi ve BAŞARISIZ oldu (yukarıdaki "Gerçek Sorun #1") — düzeltilemeyen, kabul edilen bir davranışı doğruladığı için test kaldırıldı (kalıcı başarısız test tutulmaz).
