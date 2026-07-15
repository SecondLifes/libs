unit rad.cache.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Variants,
  Winapi.Windows,
  rad.cache;

type
  ISmartCacheTestArayuzu = interface
    ['{7E6C6C5A-9B3E-4B0A-9A3E-4C1E6F2D8A11}']
    function DegerAl: Integer;
  end;

  TSmartCacheTestArayuzuImpl = class(TInterfacedObject, ISmartCacheTestArayuzu)
  public
    function DegerAl: Integer;
  end;

  // 2026-07-09 incelemesi ("1.md"/"2.md", rad.cache.pas) sonrası eklendi:
  // yönetilen Variant sızıntısı regresyon testi için destructor'ı sayan bir arayüz/sınıf.
  ISizintiTestArayuzu = interface
    ['{4C2E7A1D-3F9B-4A2C-8E7D-2A1B3C4D5E6F}']
    procedure Ping;
  end;

  TSizintiTestNesnesi = class(TInterfacedObject, ISizintiTestArayuzu)
  public
    class var YokEdilmeSayisi: Integer;
    destructor Destroy; override;
    procedure Ping;
  end;

  [TestFixture]
  TSmartParamTestleri = class
  public
    [Test]
    procedure TemelTiplerGidisDonusu;

    [Test]
    procedure BosVeNullDegerler;

    [Test]
    procedure NesneReferansiGidisDonusu;

    [Test]
    procedure ArayuzDestegi;

    { 2026-07-09 incelemesi (1.md/2.md, rad.cache.pas) sonrası eklenen testler }

    [Test]
    procedure YonetilenDegerUzerineYazilinceSizdirmaz;

    [Test]
    procedure AsObjYanlisTipCanliNesneIcinNilDoner;

    [Test]
    procedure KindOzelligiDegerTipiniDogruYansitir;

    [Test]
    procedure TryAsMetotlariBasarisizDurumdaFalseDoner;

    [Test]
    procedure BosParamVarsayilanSozlesmesi;
  end;

  [TestFixture]
  TSmartCacheTestleri = class
  public
    [Test]
    procedure EkleVeOku;

    [Test]
    procedure SilmeIslemiDogruSonucDoner;

    [Test]
    procedure GenelOlayEkleIslemiIptalEdebilir;

    [Test]
    procedure GetOrAddSessizAddOrSetOlayTetikler;

    [Test]
    procedure TekHandlerKaldirma;

    [Test]
    [Category('Eşzamanlılık')]
    procedure EszamanliErisimdeCokmeOlmaz;

    [Test]
    [Category('Eşzamanlılık')]
    procedure GenelOlayEszamanliDegistirmedeYarisOlmaz;
  end;

implementation

{ TSmartCacheTestArayuzuImpl }

function TSmartCacheTestArayuzuImpl.DegerAl: Integer;
begin
  Result := 42;
end;

{ TSizintiTestNesnesi }

destructor TSizintiTestNesnesi.Destroy;
begin
  Inc(YokEdilmeSayisi);
  inherited;
end;

procedure TSizintiTestNesnesi.Ping;
begin
end;

{ TSmartParamTestleri }

procedure TSmartParamTestleri.TemelTiplerGidisDonusu;
var
  P: TSmartParam;
begin
  P.SetValue(123);
  Assert.AreEqual(123, P.AsInteger, 'Integer gidiş-dönüşü başarısız');

  P.SetValue(3.14);
  Assert.IsTrue(Abs(P.AsFloat - 3.14) < 0.0001, 'Double gidiş-dönüşü başarısız');

  P.SetValue('Merhaba Dünya');
  Assert.AreEqual('Merhaba Dünya', P.AsString, 'String gidiş-dönüşü başarısız');

  P.SetValue(True);
  Assert.IsTrue(P.AsBoolean, 'Boolean gidiş-dönüşü başarısız');

  var SimdikiZaman := Now;
  P.SetValue(SimdikiZaman);
  Assert.IsTrue(Abs(P.AsDateTime - SimdikiZaman) < 1 / (24 * 60 * 60), 'DateTime gidiş-dönüşü başarısız');
end;

procedure TSmartParamTestleri.BosVeNullDegerler;
var
  P: TSmartParam;
begin
  P.SetValue(5);
  Assert.IsFalse(P.IsNull, 'Değer atanmış param IsNull=True olmamalıydı');

  P.SetNull;
  Assert.IsTrue(P.IsNull, 'SetNull sonrası IsNull=True olmalıydı');
  Assert.AreEqual(Ord(varNull), Ord(P.vType), 'SetNull sonrası vType=varNull olmalıydı');
end;

procedure TSmartParamTestleri.NesneReferansiGidisDonusu;
var
  P: TSmartParam;
  Liste: TStringList;
  Sonuc: TStringList;
begin
  // Regresyon: AsObj<T> artık T: class kısıtlı ve doğrudan pointer cast kullanıyor
  // (eskiden kısıtsız Move ile büyük tiplerde stack sınırı aşılabiliyordu).
  Liste := TStringList.Create;
  try
    Liste.Add('Satır 1');
    Liste.Add('Satır 2');
    P.SetValue(Liste);
    Sonuc := P.AsObj<TStringList>;
    Assert.IsTrue(Sonuc = Liste, 'AsObj<T> orijinal nesne referansını döndürmedi');
    Assert.AreEqual(2, Sonuc.Count, 'AsObj<T> ile alınan nesnenin içeriği yanlış');
  finally
    Liste.Free;
  end;

  P.SetNull;
  Assert.IsTrue(P.AsObj<TStringList> = nil, 'Boş param için AsObj<T> nil dönmeliydi');
end;

procedure TSmartParamTestleri.ArayuzDestegi;
var
  P: TSmartParam;
  Impl: ISmartCacheTestArayuzu;
  Sonuc: ISmartCacheTestArayuzu;
begin
  Impl := TSmartCacheTestArayuzuImpl.Create;
  P.SetValue(Impl);

  Sonuc := P.AsIntf<ISmartCacheTestArayuzu>;
  Assert.IsTrue(Assigned(Sonuc), 'AsIntf<T> interface''i bulamadı');
  Assert.AreEqual(42, Sonuc.DegerAl, 'AsIntf<T> ile alınan interface yanlış nesneye işaret ediyor');
end;

procedure TSmartParamTestleri.YonetilenDegerUzerineYazilinceSizdirmaz;
var
  P: TSmartParam;
  Intf: ISizintiTestArayuzu;
begin
  // Regresyon: SetValue(Integer/Double/Boolean/TDateTime) eskiden doğrudan
  // TVarData'ya yazıp FValue'nun önceki yönetilen (managed) değerini (ör. bir
  // interface referansını) VarClear'sız eziyordu — bu, referans sayacının hiç
  // düşmemesine (sızıntı) yol açıyordu. Artık güvenli `FValue := V` ataması
  // kullanılıyor (2026-07-09 incelemesi #1, scratch testle doğrulandı).
  TSizintiTestNesnesi.YokEdilmeSayisi := 0;
  Intf := TSizintiTestNesnesi.Create;
  P.SetValue(Intf);
  Intf := nil;
  P.SetValue(123);
  Assert.AreEqual(1, TSizintiTestNesnesi.YokEdilmeSayisi, 'SetValue(Integer) eski interface''i sızdırdı');

  TSizintiTestNesnesi.YokEdilmeSayisi := 0;
  Intf := TSizintiTestNesnesi.Create;
  P.SetValue(Intf);
  Intf := nil;
  P.SetValue(3.14);
  Assert.AreEqual(1, TSizintiTestNesnesi.YokEdilmeSayisi, 'SetValue(Double) eski interface''i sızdırdı');

  TSizintiTestNesnesi.YokEdilmeSayisi := 0;
  Intf := TSizintiTestNesnesi.Create;
  P.SetValue(Intf);
  Intf := nil;
  P.SetValue(True);
  Assert.AreEqual(1, TSizintiTestNesnesi.YokEdilmeSayisi, 'SetValue(Boolean) eski interface''i sızdırdı');

  TSizintiTestNesnesi.YokEdilmeSayisi := 0;
  Intf := TSizintiTestNesnesi.Create;
  P.SetValue(Intf);
  Intf := nil;
  P.SetValue(Now);
  Assert.AreEqual(1, TSizintiTestNesnesi.YokEdilmeSayisi, 'SetValue(TDateTime) eski interface''i sızdırdı');
end;

procedure TSmartParamTestleri.AsObjYanlisTipCanliNesneIcinNilDoner;
var
  P: TSmartParam;
  Liste: TStringList;
  YanlisSonuc: TSmartCacheTestArayuzuImpl;
begin
  // Regresyon: AsObj<T> artık nesne HALEN CANLIYSA `is T` kontrolü yapıyor
  // (2026-07-09 incelemesi #3) — eskiden yanlış tipte istenirse kontrolsüz
  // cast ile "başarıyla" (ama yanlış tipte) dönerdi.
  Liste := TStringList.Create;
  try
    P.SetValue(Liste);
    YanlisSonuc := P.AsObj<TSmartCacheTestArayuzuImpl>;
    Assert.IsTrue(YanlisSonuc = nil, 'AsObj<T> yanlış tipte canlı nesne için nil dönmeliydi');
    Assert.IsTrue(P.AsObj<TStringList> = Liste, 'AsObj<T> doğru tipte hâlâ çalışmalıydı');
  finally
    Liste.Free;
  end;
end;

procedure TSmartParamTestleri.KindOzelligiDegerTipiniDogruYansitir;
var
  P: TSmartParam;
  Liste: TStringList;
  Intf: ISizintiTestArayuzu;
begin
  // 2026-07-09 incelemesi #6: TVarType yerine domain-odaklı Kind property'si.
  // Özellikle: SetValue(TObject) hep varInt64 kullanıyor (platformdan bağımsız,
  // bilinçli karar) — bu yüzden spObject, gerçek Integer değerlerinden
  // (spInteger, her zaman varInteger) hiçbir platformda karışmıyor.
  P.SetValue(42);
  Assert.IsTrue(P.Kind = spInteger, 'Kind=spInteger olmalıydı');

  var Ondalik: Double := 3.14;
  P.SetValue(Ondalik);
  Assert.IsTrue(P.Kind = spFloat, 'Kind=spFloat olmalıydı');

  P.SetValue('metin');
  Assert.IsTrue(P.Kind = spString, 'Kind=spString olmalıydı');

  P.SetValue(True);
  Assert.IsTrue(P.Kind = spBoolean, 'Kind=spBoolean olmalıydı');

  P.SetValue(Now);
  Assert.IsTrue(P.Kind = spDateTime, 'Kind=spDateTime olmalıydı');

  P.SetNull;
  Assert.IsTrue(P.Kind = spNull, 'Kind=spNull olmalıydı');

  Liste := TStringList.Create;
  try
    P.SetValue(Liste);
    Assert.IsTrue(P.Kind = spObject, 'Kind=spObject olmalıydı');
  finally
    Liste.Free;
  end;

  Intf := TSizintiTestNesnesi.Create;
  P.SetValue(Intf);
  Assert.IsTrue(P.Kind = spInterface, 'Kind=spInterface olmalıydı');
  Intf := nil;
end;

procedure TSmartParamTestleri.TryAsMetotlariBasarisizDurumdaFalseDoner;
var
  P: TSmartParam;
  I: Integer;
  F: Double;
  B: Boolean;
  D: TDateTime;
begin
  // 2026-07-09 incelemesi #5: exception fırlatmayan okuma API'si.
  P.SetValue(42);
  Assert.IsTrue(P.TryAsInteger(I) and (I = 42), 'TryAsInteger geçerli girdide başarısız oldu');

  P.SetValue('sayı-değil');
  Assert.IsFalse(P.TryAsInteger(I), 'TryAsInteger geçersiz girdide False dönmeliydi');

  var Ondalik: Double := 3.14;
  P.SetValue(Ondalik);
  Assert.IsTrue(P.TryAsFloat(F) and (Abs(F - 3.14) < 0.0001), 'TryAsFloat geçerli girdide başarısız oldu');

  P.SetValue(True);
  Assert.IsTrue(P.TryAsBoolean(B) and (B = True), 'TryAsBoolean geçerli girdide başarısız oldu');

  var SimdikiZaman := Now;
  P.SetValue(SimdikiZaman);
  Assert.IsTrue(P.TryAsDateTime(D) and (Abs(D - SimdikiZaman) < 1 / (24 * 60 * 60)), 'TryAsDateTime geçerli girdide başarısız oldu');
end;

procedure TSmartParamTestleri.BosParamVarsayilanSozlesmesi;
var
  P: TSmartParam;
begin
  // 2026-07-09 incelemesi #7: Default(TSmartParam)/lokal değişkenin ilk hali sözleşmesi.
  P := Default(TSmartParam);
  Assert.IsTrue(P.IsEmpty, 'Default(TSmartParam).IsEmpty=True olmalıydı');
  Assert.IsFalse(P.IsNull, 'Default(TSmartParam).IsNull=False olmalıydı');
end;

{ TSmartCacheTestleri }

procedure TSmartCacheTestleri.EkleVeOku;
var
  Cache: TSmartCache;
begin
  Cache := TSmartCache.Create;
  try
    Assert.IsTrue(Cache.AddOrSet('sayi', 10));
    Assert.AreEqual(10, Cache.Get('sayi', 0));

    Assert.IsTrue(Cache.AddOrSet('metin', 'abc'));
    Assert.AreEqual('abc', Cache.Get('metin', ''));

    Assert.IsFalse(Cache.ContainsKey('yok'), 'Var olmayan anahtar ContainsKey=True dönmemeliydi');
    Assert.AreEqual(99, Cache.Get('yok', 99), 'Var olmayan anahtar için varsayılan değer dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.SilmeIslemiDogruSonucDoner;
var
  Cache: TSmartCache;
begin
  // Regresyon: Remove artık anahtar gerçekten bulunup silindiyse True,
  // bulunamadıysa False dönüyor (eskiden her zaman True dönüyordu).
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('k1', 1);
    Assert.IsTrue(Cache.Remove('k1'), 'Var olan anahtar silinirken True dönmeliydi');
    Assert.IsFalse(Cache.Remove('k1'), 'Zaten silinmiş anahtar tekrar silinirken False dönmeliydi');
    Assert.IsFalse(Cache.Remove('hicYokBu'), 'Hiç var olmamış anahtar için False dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.GenelOlayEkleIslemiIptalEdebilir;
var
  Cache: TSmartCache;
begin
  Cache := TSmartCache.Create;
  try
    Cache.OnGlobalChange := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
      begin
        Result := False; // her değişikliği reddet
      end;

    Assert.IsFalse(Cache.AddOrSet('x', 10), 'Event False dönünce AddOrSet False dönmeliydi');
    Assert.IsFalse(Cache.ContainsKey('x'), 'Event iptal ettiği halde değer eklenmiş');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.GetOrAddSessizAddOrSetOlayTetikler;
var
  Cache: TSmartCache;
  TetiklenmeSayisi: Integer;
begin
  Cache := TSmartCache.Create;
  try
    TetiklenmeSayisi := 0;
    Cache.OnGlobalChange := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
      begin
        Inc(TetiklenmeSayisi);
        Result := True;
      end;

    Cache.GetOrAdd('yeniAnahtar', TSmartParam.New(42));
    Assert.AreEqual(0, TetiklenmeSayisi, 'GetOrAdd yeni kayıt eklerken event tetiklememeliydi');

    Cache.AddOrSet('yeniAnahtar', 99);
    Assert.AreEqual(1, TetiklenmeSayisi, 'AddOrSet değeri değiştirirken event tetiklemeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.TekHandlerKaldirma;
var
  Cache: TSmartCache;
  Tetik1, Tetik2: Integer;
  H1, H2: TParamChangeEvent;
begin
  Cache := TSmartCache.Create;
  try
    Tetik1 := 0;
    Tetik2 := 0;
    // Aynı closure referansı hem RegisterEvent'e hem UnregisterEvent'e verilmeli
    // (karşılaştırma referans eşitliğiyle yapılıyor).
    H1 := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
      begin
        Inc(Tetik1);
        Result := True;
      end;
    H2 := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
      begin
        Inc(Tetik2);
        Result := True;
      end;

    Cache.RegisterEvent('k', H1);
    Cache.RegisterEvent('k', H2);

    Cache.AddOrSet('k', 1);
    Assert.AreEqual(1, Tetik1, 'H1 ilk AddOrSet''ta tetiklenmeliydi');
    Assert.AreEqual(1, Tetik2, 'H2 ilk AddOrSet''ta tetiklenmeliydi');

    Assert.IsTrue(Cache.UnregisterEvent('k', H1), 'H1 kaldırılırken True dönmeliydi');
    Assert.IsFalse(Cache.UnregisterEvent('k', H1), 'Zaten kaldırılmış handler tekrar kaldırılırken False dönmeliydi');
    Assert.IsFalse(Cache.UnregisterEvent('baskaAnahtar', H2), 'Kayıtlı olmadığı anahtarda False dönmeliydi');

    Cache.AddOrSet('k', 2);
    Assert.AreEqual(1, Tetik1, 'H1 kaldırıldıktan sonra artık tetiklenmemeliydi');
    Assert.AreEqual(2, Tetik2, 'H2 hâlâ kayıtlı olduğu için tetiklenmeye devam etmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure OnbellekYukIsciBaslat(ACache: TSmartCache; AThreadNo, AIslemSayisi: Integer;
  AHatalar: PInteger; AOlay: TEvent);
begin
  // Tüm değişkenler parametre — closure'ın döngü değişkenine güvenmiyoruz.
  TThread.CreateAnonymousThread(procedure begin
    try
      for var j := 1 to AIslemSayisi do
      begin
        var LAnahtar := 'key' + IntToStr(AThreadNo) + '_' + IntToStr(j mod 10);
        ACache.AddOrSet(LAnahtar, j);
        ACache.Get(LAnahtar, 0);
        ACache.ContainsKey(LAnahtar);
      end;
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure TSmartCacheTestleri.EszamanliErisimdeCokmeOlmaz;
const
  ThreadSayisi = 4;
  IslemSayisi  = 200;
var
  Cache: TSmartCache;
  BittiOlaylar: array[0 .. ThreadSayisi - 1] of TEvent;
  Hatalar: Integer;
  i: Integer;
begin
  // Her thread kendi anahtar alanında çalışır (aynı anahtarlar için sürekli
  // add/remove churn'ü kasıtlı olarak yok — kilitlerin thread-safety'sini
  // test ediyoruz.
  Cache   := TSmartCache.Create(True);
  Hatalar := 0;
  try
    for i := 0 to ThreadSayisi - 1 do
      BittiOlaylar[i] := TEvent.Create(nil, True, False, '');
    try
      for i := 0 to ThreadSayisi - 1 do
        OnbellekYukIsciBaslat(Cache, i, IslemSayisi, @Hatalar, BittiOlaylar[i]);

      for i := 0 to ThreadSayisi - 1 do
        Assert.IsTrue(BittiOlaylar[i].WaitFor(20000) = wrSignaled, 'Thread zamanında bitmedi');
    finally
      for i := 0 to ThreadSayisi - 1 do
        BittiOlaylar[i].Free;
    end;

    Assert.AreEqual(0, Hatalar, 'Eşzamanlı erişimde exception/AV oluştu');
  finally
    Cache.Free;
  end;
end;

procedure GenelOlayYazariBaslat(ACache: TSmartCache; ABitisTick: UInt64; AHatalar: PInteger; AOlay: TEvent);
begin
  TThread.CreateAnonymousThread(procedure begin
    try
      while GetTickCount64 < ABitisTick do
        ACache.OnGlobalChange := function(AKey: string; AOldType: TVarType; AOld, ANew: Variant): Boolean
          begin Result := True; end;
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure EkleVeAyarlaCekiciBaslat(ACache: TSmartCache; ABitisTick: UInt64; AHatalar: PInteger; AOlay: TEvent);
begin
  TThread.CreateAnonymousThread(procedure begin
    try
      var n := 0;
      while GetTickCount64 < ABitisTick do
      begin
        Inc(n);
        ACache.AddOrSet('gkey', n);
      end;
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure TSmartCacheTestleri.GenelOlayEszamanliDegistirmedeYarisOlmaz;
const
  YazarThreadSayisi = 2;
  SureMs            = 200;
var
  Cache: TSmartCache;
  BittiOlaylar: array[0 .. YazarThreadSayisi] of TEvent; // 0 = OnGlobalChange değiştiren, 1..N = AddOrSet çağıran
  Hatalar: Integer;
  BitisTick: UInt64;
  i: Integer;
begin
  // Regresyon: FireEvents artık FGlobalEvent'i kilit altında yerel değişkene
  // kopyalıyor, OnGlobalChange property'si de artık kilitli getter/setter kullanıyor.
  Cache     := TSmartCache.Create(True);
  Hatalar   := 0;
  BitisTick := GetTickCount64 + SureMs;
  try
    for i := 0 to YazarThreadSayisi do
      BittiOlaylar[i] := TEvent.Create(nil, True, False, '');
    try
      GenelOlayYazariBaslat(Cache, BitisTick, @Hatalar, BittiOlaylar[0]);

      for i := 1 to YazarThreadSayisi do
        EkleVeAyarlaCekiciBaslat(Cache, BitisTick, @Hatalar, BittiOlaylar[i]);

      for i := 0 to YazarThreadSayisi do
        Assert.IsTrue(BittiOlaylar[i].WaitFor(20000) = wrSignaled, 'Thread zamanında bitmedi');
    finally
      for i := 0 to YazarThreadSayisi do
        BittiOlaylar[i].Free;
    end;

    Assert.AreEqual(0, Hatalar, 'OnGlobalChange eşzamanlı değiştirilirken exception/AV oluştu');
  finally
    Cache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSmartParamTestleri);
  TDUnitX.RegisterTestFixture(TSmartCacheTestleri);

end.
