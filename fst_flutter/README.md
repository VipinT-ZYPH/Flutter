# ReflectAI Flutter client

This is the Flutter client for the ReflectAI journaling experience. It includes:

- A responsive reflective workspace with mood-aware journal entries.
- A guided journal editor with Gemini-powered reflections and a local fallback.
- A conversational reflection screen.
- Local persistence with `shared_preferences`.

## Run locally

Run these commands from the `Flutter` directory that contains the nested
`Flutter` SDK folder (`C:\...\FST_MP\Flutter`):

```powershell
Set-Location .\Flutter\fst_flutter
..\bin\flutter.bat pub get
..\bin\flutter.bat run
```

Journal entries are stored locally on the device. Gemini is used for chat and
new-entry reflections when a key is supplied at runtime:

```powershell
Set-Location .\Flutter\fst_flutter
..\bin\flutter.bat run `
  --dart-define=GEMINI_API_KEY=your-real-gemini-key
```

Without the key, the app remains usable with local fallback responses. Do not
put the key in Dart source, commit it to Git, or place it in a Flutter asset.
For production, move the Gemini call behind a server because a Flutter app can
be reverse-engineered.

## Validate

```powershell
Set-Location .\Flutter\fst_flutter
..\bin\flutter.bat analyze
..\bin\flutter.bat build web
```
