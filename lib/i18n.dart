import 'package:flutter/foundation.dart';

/// UI language: uz (default) | en | ru. The *learning* language is set per class on the server.
final lang = ValueNotifier<String>('uz');

const _s = {
  'uz': {'class_code': 'Sinf kodi', 'pick_you': 'Sen kimsan?', 'pin': 'PIN', 'go': 'Boshlash', 'pick_hero': "Do'stingni tanla", 'err': "Xatolik, qayta urinib ko'ring", 'wrong': "PIN noto'g'ri", 'no_lesson': "Hozircha dars yo'q", 'unknown': "Bilmadim, yana suratga ol"},
  'en': {'class_code': 'Class code', 'pick_you': 'Who are you?', 'pin': 'PIN', 'go': 'Start', 'pick_hero': 'Pick your friend', 'err': 'Oops, try again', 'wrong': 'Wrong PIN', 'no_lesson': 'No lesson yet', 'unknown': 'Not sure, try another photo'},
  'ru': {'class_code': 'Код класса', 'pick_you': 'Кто ты?', 'pin': 'PIN', 'go': 'Начать', 'pick_hero': 'Выбери друга', 'err': 'Ошибка, попробуй ещё раз', 'wrong': 'Неверный PIN', 'no_lesson': 'Урока пока нет', 'unknown': 'Не уверен, сфотографируй ещё'},
};
String t(String k) => _s[lang.value]![k] ?? k;
