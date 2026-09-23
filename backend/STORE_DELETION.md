# Store deletion

## Upgrade

Back up the target database. Apply `database/migrations/004_store_deletion.sql`
with an administrator connection, then run `npm run db:check` and restart the API.
The application account needs no additional privileges. The migration can be rerun.
Fresh databases created with the current schema already have `stores.deleted_at`.

## API

`DELETE /api/merchant/stores/:id` requires the owning merchant's bearer token.
Returns the updated merchant account with its remaining stores. Invalid IDs return
400; missing/foreign stores return 404; member tokens cannot perform this action.
Repeating a successful deletion with the same owner and store ID returns 200.

One transaction locks the active merchant and owned store, pauses every product
regardless of its prior status, advances product revisions and marks the store deleted.
Failure rolls back both changes. Existing product and order rows are retained for
historical references. This is logical deletion, not physical database erasure.
There is no restore endpoint. A newly created store can reuse the name/address but
receives a new ID and does not inherit deleted products.

Deleted stores/products are excluded from merchant management, public catalogues,
favorites and browsing history. New draft creation, publication and checkout are
rejected. Previously committed orders and idempotent retries of those orders remain
readable. Concurrent checkout/deletion is transactional; a deadlock may require
retrying the failed request, never dropping order history to force deletion.

## App verification

Merchant products -> store management -> trash icon -> confirmation.
Cancel sends no request. Failure retains the current store and products and shows
an error. Success removes the store's cached products and pending draft. Refresh
also synchronizes stores removed on another device. Other stores are preserved.
Member catalogues cached on other devices need refreshing; the server always
rejects new checkout against a deleted store, even with stale cart contents.

Test with a disposable store: add draft and active products, place a test order,
delete the store, verify its products disappear and the old order still loads.
Do not confuse this operation with an administrator's full test-database reset.
