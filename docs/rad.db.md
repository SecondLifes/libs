---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\rad.db.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: e90ad0026f83a880e269d2288416d83062d53df11c176477bf38beca78b02580
---

# rad.db
UniDAC veritabanı katmanı. `TRadConnection` + `TRadQuery` + yardımcı bileşenler.

`Help.DB.pas` helper'ları (`_DoEof`, `_ToJSONArrayALL`, `_W`, `_F`, `_V`, `_Post` vb.) TRadQuery üzerinde **otomatik** çalışır.

> `rad.db.unidac.pas` (TAksa* bileşenleri) bu dosyaya birleştirildi ve silindi.

## Gereksinimler

`Uni`, `UniProvider`, `DBAccess`, `UniScript`, `MemDS`,
`mormot.core.variants`, `mormot.core.unicode`, `mormot.db.core`,
`Help.DB`, `rad.permission`, `rad.thread`

> Async metodlar için UniDAC **connection pooling** aktif olmalıdır.

---

## Enum & Tip Tanımları

| Tip | Değerler |
|---|---|
| `TRadFilterType` | `rfAnd, rfNotAnd, rfOr, rfNotOr` |
| `TRadFilterOp` | `foEqual..foEndsWith` (14 operatör) |
| `TRadDSEventKind` | `evLoaded, evBeforeOpen..evError` |
| `TRadAuditType` | `auNone, auChange, auFull` |
| `TRadWorkAction` | `waInsert, waUpdate, waDelete, waExecSQL` |
| `TRadQueryCmd` | `rcNoInsert, rcNoEdit, rcNoDelete, rcSoftDelete, rcDetailsOpen, rcDetailsPost, rcMasterEdit, rcMasterInsertID` |
| `TRadIDGenerator` | `function(scope, inc): Variant of object` |
| `TRadCmdExecutor` | `function(cmd, dataset, args): Variant of object` |

---

## TRadEventHandler

Birden fazla query'nin paylaşabileceği event handler component'i.

| Property | Açıklama |
|---|---|
| `Enabled` | Aktif/pasif |
| `Events: TRadDSEventKinds` | Hangi event'leri dinleyeceği |
| `OnEvent: TRadDSNotifyEvent` | Callback — `(event, dataset, args)` |

`TRadEventHandlers` collection'ına `TRadEventHandlerItem` ile eklenir.

---

## TRadAutoValueItem

Event tetiklenince otomatik alan doldurma.

| Property | Açıklama |
|---|---|
| `Events` | Hangi event'lerde çalışacak |
| `FieldName` | Doldurulacak alan |
| `Value` | Sabit değer |
| `Command` | `TRadCmdExecutor` ile çalıştırılacak komut |

`Command` doldurulursa `Value` yerine `CmdExecutor` çağrılır.

---

## TRadFilterItem

Design-time filtre tanımı. `FiltreApply(value)` ile WHERE üretir.

| Property | Açıklama |
|---|---|
| `FilterField` | Alan adı (Alias ön eki ile) |
| `Operation` | `TRadFilterOp` — `foEqual`, `foLike`, `foBetween` vb. |
| `FilterType` | `rfAnd / rfOr` vb. |
| `Filter1/Filter2` | Between için alt/üst değer |
| `FieldType` | Alan tipi (bilinmiyorsa `ftUnknown` — runtime'da çözülür) |

---

## TRadQuerySetting

| Metod | Açıklama |
|---|---|
| `IsCommand(cmd)` | Komut aktif mi |
| `SetCommand(cmd, b)` | Fluent komut set/kaldır |
| `LoadPermission(scope, perm)` | `IPermission`'dan add/edit/delete komutlarını yükle |

| Property | Açıklama |
|---|---|
| `EventHandlers` | `TRadEventHandlers` |
| `AutoValues` | `TRadAutoValues` |
| `Filters` | `TRadFilterCollection` |
| `Commands` | `TRadQueryCmds` set |
| `DeleteConfirm` | Silme onayı |

---

## TRadUnitOfWork

Birden fazla dataset işlemini tek transaction'da toplar.

| Metod | Açıklama |
|---|---|
| `RegisterDataSet(ds, action)` | Dataset'i kayıt altına al |
| `RegisterSQL(sql)` | Ham SQL ekle |
| `Commit: Boolean` | Hepsini tek transaction'da uygula |
| `Rollback` | İptal et |
| `Clear` | Listeyi temizle |

| Property | Açıklama |
|---|---|
| `Connection` | `TRadConnection` |
| `InWork` | Kayıt var mı |
| `InCommit` | Commit sürüyor mu |

---

## TRadConnectionSetting

| Property | Açıklama |
|---|---|
| `DBSettingTable` | Versiyon tablosu adı |
| `DBVersionField` | Versiyon field adı |
| `DBMinVersion` | Minimum beklenen versiyon |
| `DBVersion` | Mevcut DB versiyonu (read-only, lazy) |
| `Audit` | `auNone / auChange / auFull` |
| `SQLLogType` | `slNone / slLast / slFull` |

| Metod | Açıklama |
|---|---|
| `MigrateDBFolder(folder)` | Klasördeki `.sql` migration dosyalarını sırayla çalıştır |

---

## TRadConnection

### Fluent Config

| Metod | Açıklama |
|---|---|
| `Provider / Server / Database / Username / Password / SetPort / Pool` | Zincir kurulum |

### Bağlantı

| Metod | Açıklama |
|---|---|
| `TryConnect: Boolean` | Exception yutarak bağlan |
| `Ping: Boolean` | Sağlık kontrolü |
| `ServerType: TSqlDBDefinition` | `dMSSQL / dPostgreSQL / dMySQL / dFirebird` vb. |
| `ServerMacroLoad` | Provider'a göre `now` makrosu yükle |
| `TableExists(name): Boolean` | Tablo var mı |
| `QueryScalar(sql, default): Variant` | Tek değer sorgu |

### Audit

| Metod | Açıklama |
|---|---|
| `AuditCapture(ds, op): string` | mORMot2 snapshot → `sys_audit_log` INSERT SQL'i |

### Query Factory & RAII

| Metod | Lifecycle |
|---|---|
| `NewQuery / NewQuery(sql)` | Caller free eder |
| `WithQuery(proc) / WithQuery(sql, proc)` | Otomatik free |

### Quick Exec

| Metod | Açıklama |
|---|---|
| `Exec(sql) / Exec(sql, params)` | `ExecSQL` wrapper |
| `ExecBatch([sql1,sql2]) / ExecBatch([sql], [params])` | Tek transaction |
| `ExecAsync(sql, [params]): TRadTask` | Background exec, pool connection |

### Connection-Level Scalar (önerilen — leak yok)

| Metod | Açıklama |
|---|---|
| `QueryInt/Int64/Str/Float/Bool/Var/Exists` | Parametresiz ve `(sql, params, default)` overload |

### Transaction

| Metod | Açıklama |
|---|---|
| `InTransaction(proc) / InTransaction(func): Boolean` | Otomatik commit/rollback |
| `WithSavepoint(name, proc)` | İç içe transaction |

### Published Properties

| Property | Açıklama |
|---|---|
| `Setting: TRadConnectionSetting` | Audit, versiyon, migration |
| `IDGenerator: TRadIDGenerator` | ID üretici delegate |
| `CmdExecutor: TRadCmdExecutor` | AutoValue komut çalıştırıcı |
| `GlobalEvent: TRadDSNotifyEvent` | Tüm query'lere yayılan event |

---

## TRadQuery

### Auto-Transaction

`Post`, `InternalDelete`, `ApplyUpdates` — `UnitOfWork` yoksa otomatik transaction/savepoint açar.
`UnitOfWork` atanmışsa sadece kayıt eder, `UnitOfWork.Commit` ile toplu işlenir.

### Transaction Metodları

| Metod | Açıklama |
|---|---|
| `_BeginWork` | Transaction veya Savepoint başlat |
| `_CommitWork` | Commit veya ReleaseSavepoint |
| `_RollbackWork` | Rollback veya RollbackToSavepoint |
| `_ExecuteSQLCommands` | Audit SQL'lerini çalıştır |
| `_AddWorkAction(action)` | UoW'a kaydet + audit |
| `_Transaction: TUniTransaction` | Aktif transaction |

### ID & Detail

| Metod | Açıklama |
|---|---|
| `_GenID(scope): Variant` | `Connection.IDGenerator` delegate'i çağır |
| `_LastInsertId: Largeint` | Eklenen kaydın ID'si |
| `_DetailSets: TList<TDataSet>` | Detail dataset listesi |
| `_DetailsOpen / _DetailsPost` | `rcDetailsOpen/Post` komutuna göre tetikle |

### Fluent Kurulum

| Metod | Açıklama |
|---|---|
| `Text(sql)` | `SQL.Text` ata |
| `Param(name, value)` | `ParamByName(name).Value` |
| `ParamNull(name, type)` | NULL parametre |
| `BindDoc(doc)` | `TDocVariantData`'dan param bağla |
| `CachedMode(b)` | `CachedUpdates + DMLRefresh` |

### Filtre

| Metod | Açıklama |
|---|---|
| `FiltreApply(value)` | `Setting.Filters` üzerinden `FilterSQL` üret |
| `FiltreClear` | Filtreyi temizle |

### Iterasyon & Çıktı

| Metod | Açıklama |
|---|---|
| `Each(proc)` | `DisableControls` korumalı döngü |
| `ToDocList: IDocList` | mORMot2 doc listesi |
| `_ToList(lst, fields, fmt)` | TStrings'e doldur |
| `OpenSelf: TRadQuery` | `Open` + `Self` döner (caller free eder) |

### Scalar (terminal — otomatik free)

| Metod | Açıklama |
|---|---|
| `ScalarInt/Int64/Str/Float/Bool/Var` | Aç, oku, kapat, free |

### Async

| Metod | Açıklama |
|---|---|
| `OpenAsync: TRadTask` | Pool connection ile background open |
| `ExecAsync: TRadTask` | Pool connection ile background execute |

### Published Properties

| Property | Açıklama |
|---|---|
| `Setting: TRadQuerySetting` | Event, auto-value, filtre, komutlar |
| `UnitOfWork: TRadUnitOfWork` | Bağlı UoW (nil = standalone transaction) |
| `LastEvent: TRadDSEventKind` | Son tetiklenen event |
| `LastFilter: Variant` | Son uygulanan filtre değeri |

---

## Memory Yönetimi

| Pattern | Lifecycle |
|---|---|
| `Conn.NewQuery(...)` | Caller free eder |
| `Conn.NewQuery(...).ScalarXxx` | Otomatik free (terminal) |
| `Conn.WithQuery(sql, proc)` | Otomatik free |
| `Conn.QueryInt/Str/...` | Otomatik free |

---

## Örnek

```pascal
uses rad.db;

// Bağlantı kurulum
var Conn := TRadConnection.Create(nil);
Conn.Provider('MySQL').Server('localhost').Database('erp')
    .Username('sa').Password('1234').Pool(2, 10).Connect;
Conn.ServerMacroLoad;

// DB migration
Conn.Setting.DBSettingTable := 'sys_settings';
Conn.Setting.DBVersionField := 'db_version';
Conn.Setting.Audit          := auChange;
Conn.Setting.MigrateDBFolder('C:\Migrations');

// Audit için ID üretici
Conn.IDGenerator := function(scope, inc): Variant begin
  Result := Conn.QueryScalar('SELECT NEWID()');
end;

// Scalar
var cnt  := Conn.QueryInt('SELECT COUNT(*) FROM Orders WHERE Status = :S', [1]);
var name := Conn.QueryStr('SELECT Name FROM Users WHERE ID = :ID', [42]);
if Conn.QueryExists('SELECT 1 FROM Users WHERE Email = :E', ['ali@x.com']) then
  raise Exception.Create('Email zaten kayıtlı');

// RAII
Conn.WithQuery('SELECT * FROM Orders WHERE Status = :S', procedure(q: TRadQuery) begin
  q.Param('S', 1).Open;
  q.Each(procedure begin ProcessOrder(q.FieldByName('ID').AsInteger) end);
end);

// Auto-transaction — Post kendisi transaction açar
var Qry := Conn.NewQuery('SELECT * FROM Stock');
try
  Qry.CachedMode.Open;
  Qry.Edit;
  Qry.FieldByName('Qty').AsInteger := Qry.FieldByName('Qty').AsInteger - 5;
  Qry.Post;   // ← savepoint açar, kaydeder, kapatır
finally
  Qry.Free;
end;

// Unit of Work — iki query tek transaction'da
var UoW := TRadUnitOfWork.Create(nil);
UoW.Connection := Conn;
try
  Qry1.UnitOfWork := UoW;
  Qry2.UnitOfWork := UoW;
  Qry1.Post;
  Qry2.Post;
  UoW.Commit;   // ← tek seferde
finally
  UoW.Free;
end;

// Filtre
// Design-time'da Setting.Filters'a item eklenmiş olmalı
Qry.FiltreApply('Ahmet');  // → FilterSQL otomatik oluşur

// Permission yükleme
Qry.Setting.LoadPermission('STOK', AppPermission);
// → rcNoInsert/rcNoEdit/rcNoDelete Permission'a göre set edilir

// Async
Conn.NewQuery('SELECT * FROM Orders WHERE Date > :D')
    .Param('D', Date - 30)
    .OpenAsync
    .OnSuccess(procedure(t) begin Grid.Refresh end)
    .OnError(procedure(t) begin ShowMessage(t.ErrorMsg) end)
    .Start;

// Batch
Conn.ExecBatch(['DELETE FROM TmpData', 'UPDATE Stats SET LastClean = %now%']);
```
