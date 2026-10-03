# MPWindows CRM Architecture

## MVP
- Flutter UI
- Local SQLite database
- Excel export
- iOS share sheet

## Planned production architecture
```
Flutter
  ├── Presentation
  ├── Domain / Models
  └── Services
       ├── Local SQLite
       └── Supabase Cloud
```

The data layer is isolated so local SQLite can later be replaced or extended with Supabase sync.
