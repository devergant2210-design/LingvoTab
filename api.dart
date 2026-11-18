import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All AI calls go through Edge Functions. No AI keys exist in the app.
final sb = Supabase.instance.client;

Future<Map<String, dynamic>> _fn(String name, Map<String, dynamic> body) async {
  final r = await sb.functions.invoke(name, body: body); // throws FunctionException on non-2xx
  return Map<String, dynamic>.from(r.data as Map);
}

Future<List<Map>> roster(String code) async =>
    ((await _fn('student-auth', {'action': 'roster', 'class_code': code}))['students'] as List).cast<Map>();

Future<void> login(String code, String studentId, String pin) async {
  final r = await _fn('student-auth', {'action': 'login', 'class_code': code, 'student_id': studentId, 'pin': pin});
  await sb.auth.verifyOTP(tokenHash: r['token_hash'], type: OtpType.magiclink);
}

Future<Map<String, dynamic>> chat(String characterId, String lessonId, String text) =>
    _fn('character-chat', {'character_id': characterId, 'lesson_id': lessonId, 'text': text});

Future<Map<String, dynamic>> identify(Uint8List jpeg, String lessonId) =>
    _fn('identify-object', {'image_b64': base64Encode(jpeg), 'lesson_id': lessonId});
