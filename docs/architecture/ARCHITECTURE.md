# Architecture

The Bopomofo application is local-first and keeps external authentication and
sync behind injected services.

```text
UI → learning_engine → domain
UI → auth → sync → persistence
learning_engine → srs / phonology / content
sync → domain / persistence
```

The domain package has no Flutter dependency. The learning engine has no
Supabase dependency. The sync package has no UI dependency. Widgets consume
the composition root's services and do not construct a Supabase client.

The bootstrap composition root currently constructs configuration, local
database, guest/auth service, sync service, learning engine, and the
`BopomofoApp` in that order. The guest service reports no authenticated
session, so the shell can render without credentials or a network client.
