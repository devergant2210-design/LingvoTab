# LingvoTab MVP

Flutter (tablet-first) + Supabase (Postgres/Auth/RLS) + Claude via Edge Functions only.

## Setup
1. `supabase db push` (runs `migrations/001_init.sql`: schema, RLS, 5 original characters).
2. `supabase secrets set ANTHROPIC_API_KEY=... [ANTHROPIC_MODEL=claude-haiku-5-5]`
3. `supabase functions deploy character-chat identify-object student-auth`
4. `flutter create . --platforms=android,ios` (generates platform folders), then add permissions:
   Android `RECORD_AUDIO`, `CAMERA`, `INTERNET`; iOS `NSMicrophoneUsageDescription`,
   `NSSpeechRecognitionUsageDescription`, `NSCameraUsageDescription`.
5. `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## Vocabulary rule (character-chat)
Prompt restricts the character to lesson words + `FUNCTION_WORDS`/`PRAISE` (`_shared/validator.ts`).
Every reply is validated; on out-of-list words it is regenerated (max 3 tries, with the offending words
fed back). If all fail, a safe template made only of lesson words is sent. Violations are logged in `messages`.

## Not built yet
Teacher/admin Flutter screens (data model, RLS, `student_progress` view and the `create` action of
`student-auth` are ready), PIN lockout, per-class target language in TTS/STT, tests.
