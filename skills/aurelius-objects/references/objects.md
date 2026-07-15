---
uid: Objects
---

# Manipulating Objects

This chapter explains how to save, update, delete, find, and query entity objects using
TObjectManager. It assumes you have already
[connected to the database](xref:Aurelius.Database) and
[configured the mapping](xref:Aurelius.Mapping).
Querying objects using criteria and projections is covered in the
[Queries](xref:Aurelius.Queries) chapter.

## Object Manager

TObjectManager, declared in unit Aurelius.&#8203;Engine.&#8203;Object&#8203;Manager, is the
central layer between your application and the database. It provides methods for saving,
loading, updating, and querying entity objects, and it handles:

- **Identity mapping** — only one instance of each entity exists per manager; two queries
  returning the same primary key return the same object reference.
- **Change tracking** — property changes are detected automatically; a single call to
  TObjectManager.Flush persists all accumulated changes.
- **Object ownership** — by default, all managed entities are destroyed when the manager
  is destroyed (controlled by TObjectManager.&#8203;Owns&#8203;Objects).

Create a TObjectManager by passing an
[IDBConnection](xref:Aurelius.Database#idbconnection-interface):

```delphi
  Manager := TObjectManager.Create(MyConnection);
  try
    // perform operations
  finally
    Manager.Free;
  end;
```

To use a [mapping model](xref:Aurelius.Model) other than the default, pass a
TMappingExplorer as the second argument:

```delphi
  Manager := TObjectManager.Create(MyConnection, TMappingExplorer.Get('MyModel'));
```

Refer to the TObjectManager API reference for the full list of methods
and properties.

## TAureliusManager Component

TAureliusManager is a non-visual design-time component that wraps a
TObjectManager instance. It lets you drop a manager onto a form or
data module, connect it to a
[TAureliusConnection](xref:Aurelius.Database#taureliusconnection-component) component,
and start working without writing construction code.

Everything described in this chapter applies equally to TAureliusManager.
All persistence methods (Save, Flush, Remove, etc.) are delegated directly to the
internal TObjectManager, which is also accessible through the
TAureliusManager.&#8203;Obj&#8203;Manager property when you need a method or property
that has no direct wrapper:

```delphi
AureliusManager1.Save(Customer);           // same as:
AureliusManager1.ObjManager.Save(Customer);
```

The internal TObjectManager instance is created on demand (not at
component construction time). If the `Connection` or `ModelName` property is changed at
runtime, the existing instance — and all entities it manages — is destroyed and a fresh
one is created when next needed.

## Memory Management

Entity objects retrieved from the database or passed to persistence methods are _managed_
by the TObjectManager. You do not need to free managed objects — the
manager destroys them when it is destroyed (as long as
TObjectManager.&#8203;Owns&#8203;Objects is `True`, which is the default).

### Transient vs. Persistent

An object is **persistent** (or _managed_, _cached_) when the manager is aware of it.
This includes objects loaded from the database and objects explicitly registered via
Save, Update, or Merge.

An object is **transient** when the manager is not aware of it, regardless of whether
a corresponding row exists in the database.

### Object Lists

When a query returns a list of entities, the _list_ object must be destroyed by your
code, but the _entities inside_ must not — they remain managed by the manager:

```delphi
  Results := Manager.Find<TCustomer>
    .Where(Linq['Name'] = 'TMS Software')
    .List;
  try
    // use Results
  finally
    Results.Free; // destroy the list, not the TCustomer instances inside it
  end;
```

Projection queries (those using ListValues) return non-entity result objects. In that
case the returned list has `OwnsObjects = True`, so destroying the list also destroys
the items.

### Unique Instances

The manager's identity map guarantees a single instance per entity per manager. If you
execute two separate queries that both return the entity with the same primary key, the
returned references will be identical:

```delphi
  Customer1 := Manager.Find<TCustomer>(CustomerId);
  Customer2 := Manager.Find<TCustomer>(CustomerId);
  // Customer1 = Customer2 — same object instance
```

### Transferring Ownership Early

TObjectManager.Save takes ownership of the entity only when it
succeeds. If Save raises an exception, the entity is not owned and you would need to
free it manually. To ensure the manager always destroys the object regardless of outcome,
call TObjectManager.&#8203;Add&#8203;Ownership before Save:

```delphi
  Customer := TCustomer.Create;
  Manager.AddOwnership(Customer);   // manager will destroy it no matter what
  Manager.Save(Customer);
```

### Keeping Objects Alive After Manager Destruction

Set TObjectManager.&#8203;Owns&#8203;Objects to `False` before destroying the
manager to keep entity instances alive:

```delphi
  Manager.OwnsObjects := False;
  Results := Manager.Find<TCustomer>.List;
  Manager.Free;
  // TCustomer instances in Results are still valid
```

## Saving Objects

Use TObjectManager.Save to insert a new entity into the database.
The entity must not have an identifier value set (unless the generator is
TIdGenerator.`None`).

```delphi
  Customer := TCustomer.Create;
  Manager.AddOwnership(Customer);
  Customer.Name := 'John Smith';
  Customer.Birthday := EncodeDate(1986, 1, 1);
  Manager.Save(Customer);
  // Customer is now managed; do not free it manually
```

Use TObjectManager.&#8203;Save&#8203;OrUpdate when the entity may already have an
identifier: Aurelius calls Update internally if an id is present, Save otherwise.

### Saving Objects with Associations

In Aurelius, a relationship between two entities is expressed as an **object reference**,
not as a foreign key column value. When you want `Invoice` to belong to a `Customer`,
you assign the `Customer` object to `Invoice.Customer` — Aurelius writes the foreign key
column automatically.

> [!Important]
> 
> Do not set foreign key columns directly. The association property (e.g. `Invoice.Customer`)
> is the relationship. Setting a hypothetical `Invoice.CustomerId` field would bypass the
> ORM and lead to inconsistencies.


**Assigning an existing entity as an association:**

```delphi
  // Load the existing customer first
  Customer := Manager.Find<TCustomer>(CustomerId);

  Invoice := TInvoice.Create;
  Manager.AddOwnership(Invoice);
  Invoice.Number := 1001;
  Invoice.IssueDate := Date;
  Invoice.Customer := Customer;  // assign the object, not an ID value
  Manager.Save(Invoice);
```

**Saving a new parent and new child together:**

When AssociationAttribute is declared with
CascadeTypeAll&#8203;ButRemove, saving the child cascades to the parent
automatically — no need to save the parent separately:

```delphi
  Customer := TCustomer.Create;
  Manager.AddOwnership(Customer);
  Customer.Name := 'Acme Corp';

  Invoice := TInvoice.Create;
  Manager.AddOwnership(Invoice);
  Invoice.Number := 1002;
  Invoice.Customer := Customer;  // new, unsaved customer

  Manager.Save(Invoice);
  // Both Invoice and Customer are inserted with a single Save call
```

**Adding items to a collection:**

For one-to-many associations, add child objects to the parent's list before (or after)
saving the parent. With CascadeTypeAll on the many-valued association,
all list items are saved when the parent is saved:

```delphi
  Invoice := TInvoice.Create;
  Manager.AddOwnership(Invoice);
  Invoice.Number := 1003;

  Item1 := TInvoiceItem.Create;
  Item1.Description := 'Widget';
  Item1.Quantity := 5;
  Item1.Invoice := Invoice;  // bidirectional: set the back-reference too
  Invoice.Items.Add(Item1);

  Item2 := TInvoiceItem.Create;
  Item2.Description := 'Gadget';
  Item2.Quantity := 2;
  Item2.Invoice := Invoice;
  Invoice.Items.Add(Item2);

  Manager.Save(Invoice);
  // Invoice, Item1, and Item2 are all inserted
```

> [!Note]
> 
> Coming from SQL? While you can, you do not necessarily need to execute `INSERT INTO InvoiceItems` manually. You add
> `TInvoiceItem` objects to `Invoice.Items` and Aurelius generates the
> correct INSERT statements, including the foreign key value, when Save (or Flush)
> is called.


## Updating Objects

Aurelius tracks changes to all managed entities automatically. After loading an object
and modifying its properties, call TObjectManager.Flush to persist all
accumulated changes:

```delphi
  Customer := Manager.Find<TCustomer>(CustomerId);
  Customer.Email := 'new@example.com';
  Manager.Flush;
  // Aurelius issues: UPDATE Customer SET Email = ... WHERE Id = ...
```

Only the columns that actually changed are included in the UPDATE statement; unmodified
columns are not touched.

To persist changes to a single entity without iterating the entire manager cache, use
the single-object overload:

```delphi
  Customer1 := Manager.Find<TCustomer>(Id1);
  Customer2 := Manager.Find<TCustomer>(Id2);
  Customer1.Email := 'a@example.com';
  Customer2.Email := 'b@example.com';

  Manager.Flush(Customer1);
  // Only Customer1 is updated; Customer2 changes remain in memory
```

> [!Important]
> 
> Always prefer to flush a single object than calling Flush with no arguments. The latter iterates the entire manager cache and flushes every dirty object, which can be slow if you have many objects in memory.


To attach and update a **transient** object (one not loaded through the manager), use
TObjectManager.&#8203;Update: the manager adopts the object and will persist
all its properties on the next Flush:

```delphi
  // Object obtained from outside the manager (e.g. after manager was freed)
  Customer.Name := 'Mary';
  Manager2.Update(Customer);
  Manager2.Flush;
```

> [!Note]
> 
> When you call `Update`, the manager has no knowledge of the entity's original state —
> it has no snapshot to diff against. On the next Flush, **all** persistent properties
> are written to the database, not just the ones you changed.


### Updating Associations

**Replacing an association:**

Assign a different object to the association property, then flush. Aurelius updates the
foreign key column in the database:

```delphi
  Invoice := Manager.Find<TInvoice>(InvoiceId);
  NewCustomer := Manager.Find<TCustomer>(NewCustomerId);
  Invoice.Customer := NewCustomer;
  Manager.Flush;
  // UPDATE Invoice SET CustomerId = :newId WHERE Id = :invoiceId
```

**Adding an item to a collection:**

Load the parent, create the new child, add it to the collection, then flush:

```delphi
  Invoice := Manager.Find<TInvoice>(InvoiceId);

  NewItem := TInvoiceItem.Create;
  NewItem.Description := 'Extra service';
  NewItem.Quantity := 1;
  NewItem.Invoice := Invoice;      // set back-reference (bidirectional mapping)
  Invoice.Items.Add(NewItem);

  Manager.Flush;
  // Aurelius inserts the new InvoiceItem row with the correct foreign key
```

**Removing an item from a collection:**

```delphi
  Invoice := Manager.Find<TInvoice>(InvoiceId);
  ItemToRemove := Invoice.Items[2];
  Invoice.Items.Remove(ItemToRemove);
  Manager.Flush;
```

What happens to the removed item depends on the cascade type declared in
ManyValuedAssociation&#8203;Attribute:

- With CascadeTypeAll (no orphan removal): the item's foreign key is
  set to `NULL` in the database. The row remains; the item becomes an orphan.
- With CascadeTypeAll&#8203;Remove&#8203;Orphan: the item is deleted from the
  database when the parent is flushed.

> [!Important]
> 
> Choose CascadeTypeAll&#8203;Remove&#8203;Orphan when child entities only make sense
> in the context of their parent (e.g. invoice line items). This prevents orphaned rows
> and avoids the need to call Remove explicitly on every child.


### Merging

If you call TObjectManager.&#8203;Update with an object whose identifier is
already attached to the manager under a different instance, an exception is raised. Use
TObjectManager.Merge instead: it copies the transient object's data
into the existing persistent instance and returns the persistent object:

```delphi
  TransientCustomer := TCustomer.Create;
  TransientCustomer.Id := ExistingId;
  TransientCustomer.Name := 'New Name';

  PersistentCustomer := Manager.Merge<TCustomer>(TransientCustomer);
  Manager.Flush;
  // TransientCustomer is still transient — free it yourself
```

TObjectManager.&#8203;Replicate behaves identically but, when no matching
object exists in the database, it inserts a new record rather than raising an exception.

## Finding Objects

Use TObjectManager.Find with an identifier to load a single entity.
If the object is already in the manager cache it is returned immediately; otherwise
Aurelius loads it from the database. Returns `nil` if no record exists with that id:

```delphi
  Customer := Manager.Find<TCustomer>(CustomerId);
```

To retrieve multiple objects with criteria, call Find without an argument to obtain
a fluent query builder:

```delphi
  // All customers
  Customers := Manager.Find<TCustomer>.List;

  // First 10 customers ordered by name
  Customers := Manager.Find<TCustomer>
    .OrderBy('Name')
    .Take(10)
    .List;
```

Refer to the [Queries](xref:Aurelius.Queries) chapter for filtering, ordering,
projections, and paging.

### Querying Through Associations

You can filter and navigate through associations in queries by using dot-notation in
property paths. Aurelius generates the necessary JOINs automatically:

```delphi
  // Find all invoices belonging to a customer by name
  Invoices := Manager.Find<TInvoice>
    .Where(Linq['Customer.Name'] = 'Acme Corp')
    .List;
```

For deeper navigation or when referencing the same association more than once in a
query, create an alias with CreateAlias:

```delphi
  Invoices := Manager.Find<TInvoice>
    .CreateAlias('Customer', 'c')
    .Where((Linq['c.City'] = 'London') and (Linq['c.Active'] = True))
    .OrderBy('c.Name')
    .List;
```

**Navigating associations on loaded entities:**

Whether an association is eager or lazy, you access it through the property declared on
the entity class. For eager associations the data is already in memory; for lazy
associations Aurelius issues a SELECT the first time the property is read:

```delphi
  Invoice := Manager.Find<TInvoice>(InvoiceId);

  // Access a many-to-one association — loads Customer if lazy
  Writeln(Invoice.Customer.Name);

  // Access a primary key value of an associated entity without a full load
  // (works when the property is already populated or eager)
  Writeln(Invoice.Customer.Id);

  // Iterate a one-to-many collection — loads Items if lazy
  for Item in Invoice.Items do
    Writeln(Item.Description + ': ' + IntToStr(Item.Quantity));
```

> [!Note]
> 
> When you access a lazy-loaded association property on a managed entity, Aurelius issues
> a SELECT to load it on demand. The manager must still be alive at that point. Do not
> destroy the manager while you still hold references to managed entities whose lazy
> associations you intend to access.


## Refreshing Objects

TObjectManager.&#8203;Refresh reloads an entity's properties from the
database, discarding any in-memory changes. Unlike Find, which leaves an already-cached
instance untouched, Refresh always executes the SELECT:

```delphi
  Manager.Refresh(Customer);
  // Customer's properties now reflect the current state in the database
```

Transient associations replaced in memory are not destroyed by Refresh — you are
responsible for freeing them:

```delphi
  Customer := Manager.Find<TCustomer>(1);
  NewCountry := TCountry.Create;
  Customer.Country := NewCountry;    // transient instance

  Manager.Refresh(Customer);
  // Customer.Country now points to the original loaded TCountry again.
  // NewCountry is not freed — free it yourself.
```

Associated objects and collection items are refreshed when the cascade on the mapping
attribute includes TCascadeType.`Refresh`.

## Removing Objects

Use TObjectManager.&#8203;Remove to delete an entity from the database. The
object must be attached to the manager:

```delphi
  Customer := Manager.Find<TCustomer>(CustomerId);
  Manager.Remove(Customer);
  // DELETE FROM Customer WHERE Id = :id
```

By default the object is destroyed immediately. Set
TObjectManager.&#8203;Defer&#8203;Destruction to `True` to hold it in memory until
the manager is destroyed — useful when you still hold references to it elsewhere (e.g.
in a dataset or a list).

### Removing a Parent with Children

When cascade includes TCascadeType.`Remove`, child entities are
deleted from the database along with the parent. With
CascadeTypeAll&#8203;Remove&#8203;Orphan on the many-valued association, children
that were previously removed from the collection are also deleted.

If no remove cascade is configured, you must either:

1. Remove each child explicitly with `Manager.Remove(child)` before removing the parent, or
2. Rely on the database's own `ON DELETE CASCADE` constraint.

```delphi
  // Remove a child item directly
  Invoice := Manager.Find<TInvoice>(InvoiceId);
  ItemToDelete := Manager.Find<TInvoiceItem>(ItemId);
  Manager.Remove(ItemToDelete);
  Manager.Flush; // or just let the transaction close
```

## Evicting Objects

Use TObjectManager.Evict to detach an entity from the manager without
deleting it from the database. Changes to an evicted object are no longer tracked.

```delphi
  Manager.Evict(Customer);
```

After evicting, the object is transient again. You become responsible for freeing it
unless you re-attach it to a manager via Update. Associated objects are also evicted
if their cascade includes TCascadeType.`Evict`.

## Transaction Usage

Transactions are controlled through the
[IDBConnection](xref:Aurelius.Database#idbconnection-interface) interface.
Call `BeginTransaction` to start one; the returned IDBTransaction
interface provides `Commit` and `Rollback`:

```delphi
  Transaction := Manager.Connection.BeginTransaction;
  try
    Manager.Save(Customer);
    Manager.Save(Invoice);
    Transaction.Commit;
  except
    Transaction.Rollback;
    raise;
  end;
```

Aurelius supports nested transactions. Committing or rolling back an inner transaction
has no immediate effect — only the outermost transaction's `Commit` or `Rollback`
is executed against the database.

## Concurrency Control

### Changed Fields

When flushing, Aurelius detects which properties changed since the entity was loaded and
includes only those columns in the UPDATE statement. Two users modifying different fields
of the same row will not overwrite each other's changes.

### Entity Versioning

For situations where you must guarantee that no other user has modified a record since
you loaded it, add an integer property annotated with VersionAttribute:

```delphi
  [Entity, Automapping]
  TVersionedCustomer = class
  private
    FId: Integer;
    FName: string;
    [Version]
    FVersion: Integer;
    // ...
  end;
```

Aurelius adds `AND Version = :oldVersion` to every UPDATE and DELETE for that entity. If
another user committed a change in the meantime, the version will not match, no rows will
be affected, and Aurelius raises an `EVersionedConcurrencyControl` exception. You can
then decide how to handle the conflict — typically by refreshing the object and retrying.

## Cached Updates

By default, each Save, Flush, and Remove call executes SQL immediately. Setting
TObjectManager.&#8203;Cached&#8203;Updates to `True` defers all SQL execution until
TObjectManager.&#8203;Apply&#8203;Updates is called:

```delphi
  Manager.CachedUpdates := True;

  Manager.Save(Customer);
  Invoice.Status := isPaid;
  Manager.Flush(Invoice);
  Manager.Remove(OldCity);

  Manager.ApplyUpdates;
  // All three SQL statements execute here, in order
```

Use TObjectManager.&#8203;Cached&#8203;Count to check how many actions are pending.

> [!Note]
> 
> When an entity uses identity-based id generation (the database generates the id during
> INSERT), the INSERT is executed immediately even when `CachedUpdates` is `True`, because
> the generated id is needed to continue. Sequence-based ids are fetched immediately but
> the INSERT itself is still deferred.


## Batch (Bulk) Updates

Batch updates reduce the number of SQL round-trips when modifying many records. Enable
TObjectManager.&#8203;Cached&#8203;Updates and set
TObjectManager.&#8203;Batch&#8203;Size to the maximum number of records per batch:

```delphi
  Manager.BatchSize := 100;
  Manager.CachedUpdates := True;

  CustomerA := Manager.Find<TCustomer>(1);
  CustomerB := Manager.Find<TCustomer>(2);
  CustomerC := Manager.Find<TCustomer>(3);

  CustomerA.City := 'New York';
  Manager.Flush(CustomerA);
  CustomerB.City := 'Berlin';
  Manager.Flush(CustomerB);
  CustomerC.City := 'London';
  Manager.Flush(CustomerC);

  Manager.ApplyUpdates;
  // A single UPDATE statement is sent with all three city values at once
```

Batching groups consecutive operations that produce the same SQL template. Interleaving
different operation types (e.g. insert, then update, then insert) breaks the batch; group
similar operations together to maximize efficiency.

The batch mechanism is supported natively by the Native Aurelius connectivity, FireDAC,
and UniDAC drivers. For other drivers Aurelius simulates it by reusing a prepared
statement, which still reduces overhead compared to individual statements.
