---
uid: Aurelius.Mapping
---

# Mapping

This chapter explains how to map your Delphi classes to a relational database using TMS Aurelius. Mapping can be as simple as a single [Automapping](#automapping) attribute, or fully configured for complex scenarios using explicit attributes for every column, association, and index.

The main mapping mechanism uses **attributes** declared directly in the class source code, so you can see how each class is mapped without leaving the editor.

## Attributes Overview

All mapping attributes are declared in unit Aurelius.&#8203;Mapping.&#8203;Attributes. The table below lists the available attributes grouped by category. Click each attribute name to see full API reference documentation.

**Basic Mapping**

- EntityAttribute — marks the class as a persistable entity
- AbstractEntity&#8203;Attribute — marks the class as an abstract entity (not persisted, but provides mapping to descendants)
- IdAttribute — specifies the identifier field and its generation strategy
- TableAttribute — maps the class to a named database table
- ColumnAttribute — maps a field or property to a named table column
- SequenceAttribute — defines the database sequence used for Id generation
- UniqueKeyAttribute — defines a unique index on one or more columns
- EnumerationAttribute — specifies how an enumerated type is saved to the database

**Association Mapping**

- AssociationAttribute — defines a many-to-one association (reference to another entity)
- JoinColumnAttribute — specifies the foreign key column for a many-to-one association

**Many-Valued Association Mapping**

- ManyValuedAssociation&#8203;Attribute — defines a one-to-many association (collection of child entities)
- ForeignJoinColumn&#8203;Attribute — specifies the foreign key column in the child table for a unidirectional one-to-many association

**Behavior Mapping**

- WhereAttribute — adds a SQL filter to entity retrieval or a many-valued association
- OrderByAttribute — defines the default ordering for a many-valued association collection

**DB Structure Mapping**

- DBIndexAttribute — defines a non-unique database index
- ForeignKeyAttribute — sets a custom name for a generated foreign key constraint

**Inheritance Mapping**

- InheritanceAttribute — designates a class as the root of a mapped inheritance hierarchy
- Discriminator&#8203;Column&#8203;Attribute — specifies the discriminator column for single-table inheritance
- Discriminator&#8203;Value&#8203;Attribute — specifies the discriminator value that identifies a class
- PrimaryJoinColumn&#8203;Attribute — defines the primary key column in a child table for joined-tables inheritance

**Automapping**

- AutomappingAttribute — enables automatic mapping for the class
- TransientAttribute — excludes a field from automapping

**Concurrency Control**

- VersionAttribute — marks the field used for optimistic concurrency version tracking

**Other**

- ModelAttribute — assigns the entity to a named [mapping model](xref:Aurelius.Model)
- DescriptionAttribute — attaches a descriptive text to a class, field, or property

## Using Attributes

Attributes are added directly above the class declaration or above a field or property:

```delphi
  [Entity]
  [Table('Customer')]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TCustomerFull = class
  private
    [Column('CUSTOMER_ID', [TColumnProp.Required, TColumnProp.NoUpdate])]
    FId: Integer;
    [Column('CUSTOMER_NAME', [TColumnProp.Required], 100)]
    FName: string;
  public
    property Id: Integer read FId;
    property Name: string read FName write FName;
  end;
```

Aurelius accepts mapping attributes on either fields or properties, but not both for the same member. **Fields are recommended** because they are kept in the private section, clearly represent object state, and are required for some features such as lazy-loaded associations using Proxy\<T\>.

## Basic Entity Mapping

### Marking a Class as an Entity

Every class you want to persist must carry the EntityAttribute attribute. Without it, Aurelius ignores the class entirely.

```delphi
  [Entity]
  TCustomer = class(TObject)
  end;
```

### Mapping to a Table

Use TableAttribute to specify the table name. Optionally include a schema name:

```delphi
  [Entity]
  [Table('Customers')]
  TCustomerTable = class(TObject)
  end;

  [Entity]
  [Table('Orders', 'dbo')]
  TOrder = class(TObject)
  end;
```

### Defining the Identifier

Use IdAttribute to identify the field or property that uniquely identifies each object. Choose a generation strategy that matches your database:

```delphi
  [Entity]
  [Table('CUSTOMERS')]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TCustomerWithId = class
  private
    [Column('CUSTOMER_ID', [TColumnProp.Required, TColumnProp.NoUpdate])]
    FId: Integer;
  public
    property Id: Integer read FId;
  end;
```

Common TIdGenerator strategies:

| Strategy                          | Description                                    |
| --------------------------------- | ---------------------------------------------- |
| `TIdGenerator.IdentityOrSequence` | Uses a database sequence or identity column    |
| `TIdGenerator.Guid`               | Generates a GUID value                         |
| `TIdGenerator.SmartGuid`          | Sequential GUID, minimizes index fragmentation |
| `TIdGenerator.None`               | Application assigns the Id manually            |

To control the sequence name and parameters, add SequenceAttribute:

```delphi
  [Sequence('SEQ_CUSTOMERS')]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TCustomerSeq = class
  private
    FId: Integer;
  public
    property Id: Integer read FId;
  end;
```

### Mapping Columns

Use ColumnAttribute to map a field or property to a specific column. Column options control nullability, uniqueness, and insert/update behavior:

```delphi
  [Column('CUSTOMER_NAME', [TColumnProp.Required], 100)]
  FName: string;
  [Column('BIRTHDAY', [])]
  FBirthday: Nullable<TDate>;
  [Column('SCORE', [], 18, 4)]
  FScore: Currency;
```

Key column options from TColumnProp:

| Option     | Effect                                                           |
| ---------- | ---------------------------------------------------------------- |
| `Required` | Column is NOT NULL                                               |
| `Unique`   | Column has a unique index                                        |
| `NoInsert` | Column excluded from INSERT statements                           |
| `NoUpdate` | Column excluded from UPDATE statements                           |
| `Lazy`     | Blob column is lazy-loaded (TBlob fields only) |

### Enumerated Types

Use EnumerationAttribute on the enumeration type declaration to control how enum values are stored:

```delphi
  [Enumeration(TEnumMappingType.emChar, 'M,F')]
  TSex = (tsMale, tsFemale);
```

```delphi
  [Enumeration(TEnumMappingType.emInteger)]
  TStatus = (sActive, sInactive, sPending);
```

When `emChar` or `emString` is used, the mapped values must be comma-separated and match the order of the enumeration values.

### Unique Keys and Indexes

To create a unique constraint across multiple columns, use UniqueKeyAttribute on the class:

```delphi
  [UniqueKey('INVOICE_TYPE, INVOICENO')]
  TTC_Invoice = class
  end;
```

For a non-unique index to improve query performance, use DBIndexAttribute:

```delphi
  [DBIndex('IDX_INVOICE_DATE', 'ISSUEDATE')]
  TTC_InvoiceIdx = class
  end;
```

## Automapping

Automapping lets Aurelius infer the mapping from the class structure, reducing the number of attributes you need to declare. Add AutomappingAttribute to the class:

```delphi
  [Entity]
  [Automapping]
  TCountry = class
  private
    FId: Integer;
    FName: string;
    FContinent: string;
  public
    property Id: Integer read FId;
    property Name: string read FName write FName;
    property Continent: string read FContinent write FContinent;
  end;
```

With automapping active, the following defaults apply:

<!-- prettier-ignore -->
| Aspect        | Default rule                                                                                 |
| ------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Table name    | Class name without leading `T`, converted to `UPPER_CASE` (e.g. `TMyInvoice` → `MY_INVOICE`) |
| Column name   | Field name without leading `F`, converted to `UPPER_CASE` (e.g. `FFirstName` → `FIRST_NAME`) |
| Nullability   | Nullable\<T\> fields → nullable column; all others → NOT NULL |
| Identifier    | Field named `FID` is used as identifier                                                      |
| Sequence name | `SEQ_` + table name                                                                          |
| Properties    | Not mapped — only fields are automapped                                                      |
| Associations  | Object-type fields → many-to-one; `TList<T>` fields → many-valued                            |
| Enumerations  | Not automapped unless global config uses `Full` mode                                         |
| Inheritance   | Not automapped — must be declared explicitly                                                 |

<!-- prettier-ignore-end -->

Automapping is not all-or-nothing. You can override any individual mapping by adding the corresponding attribute:

```delphi
  [Entity]
  [Automapping]
  [Table('CUST')]
  TCustomerAuto = class(TObject)
  private
    FId: Integer;
    [Column('CUST_NAME', [TColumnProp.Required], 200)]
    FName: string;
    [Transient]
    FTempScore: Integer;
  public
    property Id: Integer read FId;
    property Name: string read FName write FName;
  end;
```

### Customizing Automapping Rules

You can provide a custom automapping engine to change naming conventions globally for a class. Inherit from TAutomappingEngine and override the relevant methods, then pass it to the attribute:

```delphi
  [Entity]
  [Automapping(TMyAutomapping)]
  TMyEntity = class
  private
    FId: Integer;
    FName: string;
  public
    property Id: Integer read FId;
    property Name: string read FName write FName;
  end;
```

```delphi
  TMyAutomapping = class(TAutomappingEngine)
  strict protected
    function FieldNameToSql(const Value: string): string; override;
  public
    function GetTableName(Clazz: TClass): string; override;
    function GetSequenceName(Clazz: TClass): string; override;
  end;
```

### Abstract Entities

AbstractEntity&#8203;Attribute lets a non-persisted base class contribute mapping information to concrete descendants. Use it to share column mappings, identifier definitions, associations, and attribute-based events or validation across a class hierarchy without requiring a joined-table or single-table inheritance strategy.

```delphi
  [AbstractEntity]
  [Automapping]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TBaseEntity = class
  strict private
    FId: Integer;
    FCreatedAt: TDateTime;
    FUpdatedAt: Nullable<TDateTime>;
  public
    property Id: Integer read FId;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: Nullable<TDateTime> read FUpdatedAt write FUpdatedAt;
  end;

  [Entity]
  [Automapping]
  TCustomerAbstract = class(TBaseEntity)
  strict private
    FName: string;
  public
    property Name: string read FName write FName;
  end;
```

`TCustomer` inherits all mapping from `TBaseEntity` — identifier, columns, and any event or validation attributes — without requiring its ancestor to be persisted.

**Supported in abstract entities:** column mapping, identifier (IdAttribute), associations, attribute-based events and validation, global filter attributes.

**Not supported in abstract entities:** TableAttribute, SequenceAttribute, UniqueKeyAttribute, DBIndexAttribute, ForeignKeyAttribute, inheritance strategy attributes.

## Nullable Fields

Use Nullable\<T\> (declared in unit Bcl.Types.Nullable) to map a field to a nullable database column. Without it, primitive types cannot represent `NULL`.

```delphi
  [Column('BIRTHDAY', [])]
  FBirthday: Nullable<TDate>;
```

Reading and writing:

```delphi
  FBirthday: Nullable<TDate>;
begin
  // Assign a value
  FBirthday := EncodeDate(2000, 1, 1);

  // Check for null
  if FBirthday.IsNull then
    Exit;  // no birthday set

  // Set to null
  FBirthday := SNull;
```

In automapping, any Nullable\<T\> field becomes a nullable column automatically. Non-nullable primitive fields become NOT NULL columns.

## Blob Fields

Map binary large object columns using either `TArray<Byte>` or the TBlob type. Using TBlob is recommended because it supports lazy loading and provides helper methods.

```delphi
  [Column('Photo', [])]
  FPhoto: TBlob;
```

### Lazy-Loading Blobs

By default, blob content is loaded with the entity. To defer loading until the blob is accessed, set the `Lazy` column property. This requires the field to be of type TBlob:

```delphi
  [Column('Photo', [TColumnProp.Lazy])]
  FPhoto: TBlob;
```

When the entity is loaded, the `Photo` column is skipped. The first access to the blob content triggers a separate SELECT to retrieve it.

See the TBlob API reference for all methods and properties available to read, write, stream, and check the blob content.

## Associations

Aurelius supports two types of associations between entities: many-to-one (a reference to another entity) and one-to-many (a collection of child entities).

### Many-to-One (Association)

Use AssociationAttribute together with JoinColumnAttribute to map a reference to another entity:

```delphi
  [Association([], CascadeTypeAllButRemove)]
  [JoinColumn('ID_COUNTRY', [])]
  FCountry: TCountry;
```

The `Cascade` parameter controls which operations propagate to the associated object. CascadeTypeAll&#8203;ButRemove is the recommended default for many-to-one associations.

> [!Important]
> 
> Do **not** create or destroy the associated object in the parent class constructor or destructor. Aurelius manages the lifetime of associated objects. Instantiating the association in the constructor will cause it to be overwritten when the entity is loaded, and destroying it in the destructor risks a double-free.


### Lazy-Loading an Association

To defer loading of the associated object, declare the field as Proxy\<T\> and use the `Lazy` association property:

```delphi
    [Association([TAssociationProp.Lazy], CascadeTypeAllButRemove)]
    [JoinColumn('ID_ARTIST', [])]
    FArtist: Proxy<TArtist>;
    function GetArtist: TArtist;
    procedure SetArtist(const Value: TArtist);
  public
    property Artist: TArtist read GetArtist write SetArtist;
...
function TMediaFileAssoc.GetArtist: TArtist;
begin
  Result := FArtist.Value;
end;

procedure TMediaFileAssoc.SetArtist(const Value: TArtist);
begin
  FArtist.Value := Value;
end;
```

Expose the association through a typed property using the proxy's `Value` property. The associated object is only loaded from the database when that property is first accessed.

Use Proxy\<T\>.Available to check whether the proxy is already loaded without triggering a database load.

### One-to-Many (Many-Valued Association)

Use ManyValuedAssociation&#8203;Attribute to declare a collection of child entities. There are two approaches.

**Bidirectional** (recommended): the child class has an AssociationAttribute back to the parent. Use the `MappedBy` parameter to reference it:

```delphi
// Child class:
  TMediaFileChild = class
  private
    [Association([TAssociationProp.Lazy], CascadeTypeAllButRemove)]
    [JoinColumn('ID_ALBUM', [])]
    FAlbum: Proxy<TAlbumRef>;
  end;

// Parent class:
  TAlbumRef = class
  private
    FId: Integer;
    FMediaFilesRef: TList<TMediaFileChild>;
  public
    [ManyValuedAssociation([], CascadeTypeAllRemoveOrphan, 'FAlbum')]
    property MediaFiles: TList<TMediaFileChild> read FMediaFilesRef;
  end;
```

**Unidirectional**: the child class has no back-reference. Use ForeignJoinColumn&#8203;Attribute to define the foreign key that Aurelius will manage in the child table:

```delphi
  [Entity]
  [Automapping]
  TInvoiceItem = class
  private
    FId: Integer;
  public
    property Id: Integer read FId;
  end;

  [Entity]
  [Automapping]
  TInvoice = class
  private
    FId: Integer;
    [ManyValuedAssociation([], CascadeTypeAllRemoveOrphan)]
    [ForeignJoinColumn('INVOICE_ID', [TColumnProp.Required])]
    FItems: TList<TInvoiceItem>;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    property Id: Integer read FId;
    property Items: TList<TInvoiceItem> read FItems;
  end;
```

For many-valued associations, CascadeTypeAll or CascadeTypeAll&#8203;Remove&#8203;Orphan are the typical cascade choices. `RemoveOrphan` causes child objects removed from the list to also be deleted from the database.

The `TList<T>` instance used for a many-valued association must be created in the parent class constructor and destroyed in the destructor. Aurelius populates the list but does not own it. The list must **not** own its items — do not use `TObjectList<T>` with `OwnsObjects = True`, as Aurelius manages the lifetime of child objects independently.

> [!Important]
> 
> Only the `TList<T>` **container** itself is created and destroyed by the parent class — not the child objects inside it. Do not instantiate or free the child entity objects directly. Aurelius is responsible for creating, loading, and destroying all associated entity instances.


```delphi
  TAlbum = class
  private
    FMediaFiles: TList<TMediaFile>;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    [ManyValuedAssociation([], CascadeTypeAllRemoveOrphan, 'FAlbum')]
    property MediaFiles: TList<TMediaFile> read FMediaFiles;
  end;
...
constructor TAlbum.Create;
begin
  FMediaFiles := TList<TMediaFile>.Create;
end;

destructor TAlbum.Destroy;
begin
  FMediaFiles.Free;
  inherited;
end;
```

### Lazy-Loading a Collection

Declare the list field as `Proxy<TList<T>>`. Initialize and destroy the list in the constructor and destructor:

```delphi
  TInvoiceLazy = class
  private
    [ManyValuedAssociation([TAssociationProp.Lazy], CascadeTypeAll)]
    [ForeignJoinColumn('INVOICE_ID', [TColumnProp.Required])]
    FItems: Proxy<TList<TInvoiceItemLazy>>;
    function GetItems: TList<TInvoiceItemLazy>;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    property Items: TList<TInvoiceItemLazy> read GetItems;
  end;
...
constructor TInvoiceLazy.Create;
begin
  FItems.SetInitialValue(TList<TInvoiceItemLazy>.Create);
end;

destructor TInvoiceLazy.Destroy;
begin
  FItems.DestroyValue;
  inherited;
end;

function TInvoiceLazy.GetItems: TList<TInvoiceItemLazy>;
begin
  Result := FItems.Value;
end;
```

Use Proxy\<&#8203;T\>&#8203;.Set&#8203;Initial&#8203;Value and Proxy\<&#8203;T\>&#8203;.Destroy&#8203;Value to manage the list lifetime — do not access `Value` directly in the constructor or destructor.

### Ordering a Collection

Use OrderByAttribute to define the default sort order for a many-valued association. Reference member names (not column names), optionally with `DESC`:

```delphi
  [OrderBy('Product.Name, Category DESC')]
  FItems: TList<TInvoiceItem>;
```

### Filtering a Collection or Entity

WhereAttribute adds a SQL filter clause. Applied to a many-valued association, it filters that collection. Applied to the class, it filters every retrieval of that entity type — including when it appears as an association in another entity:

```delphi
// Only retrieve active customers
  [Entity, Automapping]
  [Where('{Active} = 1')]
  TActiveCustomer = class
  private
    FId: Integer;
    FActive: Integer;
    FNewCustomers: TList<TActiveCustomer>;
  public
    // Only include new items in this list
    [ManyValuedAssociation([], CascadeTypeAll)]
    [Where('{Status} = ''New''')]
    property NewCustomers: TList<TActiveCustomer> read FNewCustomers;
  end;
```

Use curly brackets to reference member names — Aurelius resolves them to the correct `alias.column` format in the generated SQL.

### Custom Foreign Key Names

Use ForeignKeyAttribute to assign a specific name to the constraint Aurelius generates. When omitted, Aurelius chooses the name automatically:

```delphi
  [Association([TAssociationProp.Lazy], CascadeTypeAllButRemove)]
  [ForeignKey('FK_SONG_ARTIST')]
  [JoinColumn('ID_ARTIST', [])]
  FArtist: Proxy<TArtist>;
```

## Inheritance Strategies

When you have a class hierarchy and want to persist all classes, Aurelius supports two strategies. Add InheritanceAttribute to the root class of the hierarchy.

### Single-Table Strategy

All classes in the hierarchy are saved in one table. A discriminator column identifies the concrete class for each row.

<img alt = "inheritance singletable" src = "../images/inheritance-singletable.png" width = "556" height = "252"/>

```delphi
  [Entity]
  [Table('MEDIA_FILES_ST')]
  [Inheritance(TInheritanceStrategy.SingleTable)]
  [DiscriminatorColumn('MEDIA_TYPE', TDiscriminatorType.dtString)]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TMediaFileST = class
  private
    FId: Integer;
    FMediaName: string;
  public
    property Id: Integer read FId;
    property MediaName: string read FMediaName write FMediaName;
  end;

  [Entity]
  [DiscriminatorValue('SONG')]
  TSong = class(TMediaFileST)
  private
    [Column('DURATION', [])]
    FDuration: Nullable<Integer>;
  public
    property Duration: Nullable<Integer> read FDuration write FDuration;
  end;

  [Entity]
  [DiscriminatorValue('VIDEO')]
  TVideo = class(TMediaFileST)
  private
    [Column('RESOLUTION', [], 20)]
    FResolution: Nullable<string>;
  public
    property Resolution: Nullable<string> read FResolution write FResolution;
  end;
```

Columns belonging only to child classes must be nullable, since rows for other sibling classes will not populate them.

**Advantage:** Simple schema, no joins needed.
**Disadvantage:** Child-class columns cannot be NOT NULL at the database level.

### Joined-Tables Strategy

Each class has its own table. Child tables share the same primary key as the parent table and reference it with a foreign key.

<img alt = "inheritance joinedtables" src = "../images/inheritance-joinedtables.png" width = "556" height = "286"/>

```delphi
  [Entity]
  [Table('ANIMAL')]
  [Inheritance(TInheritanceStrategy.JoinedTables)]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TAnimal = class
  private
    FId: Integer;
    FAnimalName: string;
  public
    property Id: Integer read FId;
    property AnimalName: string read FAnimalName write FAnimalName;
  end;

  [Entity]
  [Table('BIRD')]
  [PrimaryJoinColumn('ANIMAL_ID')]
  TBird = class(TAnimal)
  private
    FWingSpan: Nullable<Double>;
  public
    property WingSpan: Nullable<Double> read FWingSpan write FWingSpan;
  end;

  [Entity]
  [Table('MAMMAL')]
  [PrimaryJoinColumn('ANIMAL_ID')]
  TMammal = class(TAnimal)
  private
    FHasFur: Boolean;
  public
    property HasFur: Boolean read FHasFur write FHasFur;
  end;
```

You can omit PrimaryJoinColumn&#8203;Attribute — the child table will then use the same column name as the parent's primary key column.

**Advantage:** Normalized schema; all columns are relevant to every row.
**Disadvantage:** Loading an object requires multiple joins, which affects performance.

## Composite Identifiers

Aurelius supports composite primary keys, though a single auto-generated identifier is strongly preferred. Use composite Ids only when required by a legacy schema.

Declare multiple IdAttribute attributes on the class. For associations that are part of a composite Id, declare the corresponding number of JoinColumnAttribute attributes:

```delphi
  TPerson = class
  private
    FLastName: string;
    FFirstName: string;
  end;

  [Entity]
  [Table('APPOINTMENT')]
  [Id('FAppointmentDate', TIdGenerator.None)]
  [Id('FPatient', TIdGenerator.None)]
  TAppointment = class
  strict private
    [Column('APPOINTMENT_DATE', [TColumnProp.Required])]
    FAppointmentDate: TDateTime;
    [Association([TAssociationProp.Required], [TCascadeType.Merge, TCascadeType.SaveUpdate])]
    [JoinColumn('PATIENT_LASTNAME', [TColumnProp.Required])]
    [JoinColumn('PATIENT_FIRSTNAME', [TColumnProp.Required])]
    FPatient: TPerson;
  public
    property AppointmentDate: TDateTime read FAppointmentDate write FAppointmentDate;
    property Patient: TPerson read FPatient write FPatient;
  end;
```

> [!Note]
> 
> Associations that are part of a composite Id are always loaded in eager mode, even if declared as lazy.


When using composite Ids with `Find` or `IdEq`, provide values as a variant array (`VarArrayCreate`) with one element per underlying primary key column.

## Mapping Examples

### Basic Automapped Entity

```delphi
  [Entity]
  [Automapping]
  TCountryExample = class
  private
    FId: Integer;
    FName: string;
    FCode: string;
  public
    property Id: Integer read FId;
    property Name: string read FName write FName;
    property Code: string read FCode write FCode;
  end;
```

### Explicit Mapping with Associations

```delphi
  [Entity]
  [Table('ARTISTS')]
  [Sequence('SEQ_ARTISTS')]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TArtistFull = class
  private
    [Column('ID', [TColumnProp.Required, TColumnProp.NoUpdate])]
    FId: Integer;
    [Column('ARTIST_NAME', [TColumnProp.Required], 100)]
    FArtistName: string;
    [Column('GENRE', [], 100)]
    FGenre: Nullable<string>;
  public
    property Id: Integer read FId;
    property ArtistName: string read FArtistName write FArtistName;
    property Genre: Nullable<string> read FGenre write FGenre;
  end;
```

```delphi
  [Entity]
  [Table('MEDIA_FILES')]
  [Sequence('SEQ_MEDIA_FILES')]
  [Inheritance(TInheritanceStrategy.SingleTable)]
  [DiscriminatorColumn('MEDIA_TYPE', TDiscriminatorType.dtString)]
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  TMediaFileFull = class
  private
    [Column('ID', [TColumnProp.Required, TColumnProp.NoUpdate])]
    FId: Integer;
    [Column('MEDIA_NAME', [TColumnProp.Required], 100)]
    FMediaName: string;
    [Association([TAssociationProp.Lazy], CascadeTypeAllButRemove)]
    [JoinColumn('ID_ARTIST', [])]
    FArtist: Proxy<TArtistFull>;
    function GetArtist: TArtistFull;
    procedure SetArtist(const Value: TArtistFull);
  public
    property Id: Integer read FId;
    property MediaName: string read FMediaName write FMediaName;
    property Artist: TArtistFull read GetArtist write SetArtist;
  end;

  [Entity]
  [DiscriminatorValue('SONG')]
  TSongFull = class(TMediaFileFull)
  private
    [Column('DURATION', [])]
    FDuration: Nullable<Integer>;
  public
    property Duration: Nullable<Integer> read FDuration write FDuration;
  end;
...
function TMediaFileFull.GetArtist: TArtistFull;
begin
  Result := FArtist.Value;
end;

procedure TMediaFileFull.SetArtist(const Value: TArtistFull);
begin
  FArtist.Value := Value;
end;
```

## Registering Entity Classes

Aurelius discovers entity classes at runtime through RTTI. However, the Delphi linker removes classes that are not referenced anywhere in code, which means Aurelius will not find them.

To prevent this, call RegisterEntity (declared in Aurelius.&#8203;Mapping.&#8203;Attributes) in the `initialization` section of the unit where your classes are defined:

```delphi
initialization
  RegisterEntity(TCustomer);
  RegisterEntity(TCountry);
  RegisterEntity(TInvoice);
```

This is particularly important in server applications (such as XData services) where entity classes may not be directly instantiated in application code.
