// The app and the widget read and write through GRDB's `Database` inside KelimeCore calls;
// re-exporting keeps them from needing a direct GRDB dependency of their own.
@_exported import GRDB
