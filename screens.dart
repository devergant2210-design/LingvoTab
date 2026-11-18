import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'api.dart';
import 'i18n.dart';

Widget L(WidgetBuilder b) => ValueListenableBuilder(valueListenable: lang, builder: (c, _, __) => b(c));

// ───────── Login: class code → pick your picture → PIN ─────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final code = TextEditingController(), pin = TextEditingController();
  List<Map> students = [];
  Map? picked;
  String? err;

  Future<void> _roster() async {
    try {
      final s = await roster(code.text.trim());
      setState(() { students = s; picked = null; err = s.isEmpty ? t('err') : null; });
    } catch (_) { setState(() => err = t('err')); }
  }

  Future<void> _login() async {
    try {
      await login(code.text.trim(), picked!['id'], pin.text);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PickerScreen()));
    } catch (_) { setState(() => err = t('wrong')); }
  }

  @override
  Widget build(BuildContext c) => L((_) => Scaffold(
        appBar: AppBar(title: const Text('LingvoTab'), actions: [
          DropdownButton<String>(value: lang.value, onChanged: (v) => lang.value = v!, items: [
            for (final l in ['uz', 'en', 'ru']) DropdownMenuItem(value: l, child: Text(l.toUpperCase())),
          ]),
          const SizedBox(width: 16),
        ]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: t('class_code')), onSubmitted: (_) => _roster()),
              const SizedBox(height: 12),
              FilledButton(onPressed: _roster, child: Text(t('go'))),
              if (students.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(t('pick_you'), style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final s in students)
                    ChoiceChip(selected: picked == s, label: Text('${s['avatar']} ${s['display_name']}', style: const TextStyle(fontSize: 24)), onSelected: (_) => setState(() => picked = s)),
                ]),
              ],
              if (picked != null) ...[
                const SizedBox(height: 16),
                TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: InputDecoration(labelText: t('pin')), onSubmitted: (_) => _login()),
                FilledButton(onPressed: _login, child: Text(t('go'))),
              ],
              if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.red, fontSize: 18))),
            ]),
          ),
        ),
      ));
}

// ───────── Character picker ─────────
class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(t('pick_hero'))),
        body: FutureBuilder(
          future: Future.wait([sb.from('characters').select(), sb.from('lessons').select('id').eq('is_active', true).limit(1)]),
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final chars = (s.data![0] as List).cast<Map>(), lessons = s.data![1] as List;
            if (lessons.isEmpty) return Center(child: Text(t('no_lesson'), style: const TextStyle(fontSize: 24)));
            return GridView.extent(maxCrossAxisExtent: 240, padding: const EdgeInsets.all(16), mainAxisSpacing: 16, crossAxisSpacing: 16, children: [
              for (final h in chars)
                InkWell(
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ChatScreen(h, lessons[0]['id']))),
                  child: Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(h['avatar'], style: const TextStyle(fontSize: 72)),
                    Text(h['name'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
                  ])),
                ),
            ]);
          },
        ),
      );
}

// ───────── Chat with character (voice, word buttons, camera) ─────────
class ChatScreen extends StatefulWidget {
  final Map ch;
  final String lessonId;
  const ChatScreen(this.ch, this.lessonId, {super.key});
  @override
  State<ChatScreen> createState() => _ChatState();
}

class _ChatState extends State<ChatScreen> {
  final msgs = <(bool, String)>[]; // (fromChild, text)
  final tts = FlutterTts(), stt = SpeechToText();
  List<String> words = [];
  bool busy = false, listening = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US'); // target language; make configurable from class.target_lang
    tts.setPitch((widget.ch['tts_pitch'] as num).toDouble()); // distinct voice per character
    tts.setSpeechRate((widget.ch['tts_rate'] as num).toDouble());
    sb.from('lesson_words').select('word').eq('lesson_id', widget.lessonId).then((r) => setState(() => words = [for (final x in r) x['word'] as String]));
    _send('hello', show: false);
  }

  @override
  void dispose() { tts.stop(); stt.stop(); super.dispose(); }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, style: const TextStyle(fontSize: 18))));

  Future<void> _send(String text, {bool show = true}) async {
    if (busy || text.trim().isEmpty) return;
    setState(() { busy = true; if (show) msgs.add((true, text)); });
    try {
      final r = await chat(widget.ch['id'], widget.lessonId, text);
      if (!mounted) return;
      setState(() => msgs.add((false, r['reply'])));
      await tts.speak(r['reply']);
    } catch (_) { if (mounted) _toast(t('err')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _listen() async {
    if (listening) { await stt.stop(); return; }
    final ok = await stt.initialize(onStatus: (s) { if (s == 'done' || s == 'notListening') setState(() => listening = false); });
    if (!ok) return;
    setState(() => listening = true);
    await stt.listen(localeId: 'en_US', listenFor: const Duration(seconds: 6), onResult: (r) { if (r.finalResult) _send(r.recognizedWords); });
  }

  Future<void> _snap() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
    if (x == null || busy) return;
    setState(() => busy = true);
    try {
      final r = await identify(await x.readAsBytes(), widget.lessonId);
      final w = r['word'] as String?;
      if (w == null) { _toast(t('unknown')); setState(() => busy = false); return; }
      tts.speak(w);
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => AlertDialog(title: Text(w, style: const TextStyle(fontSize: 44)), content: Text('${r['uz'] ?? ''}', style: const TextStyle(fontSize: 28))));
      setState(() => busy = false);
      if (r['in_lesson'] == true) await _send(w); // character reacts only if it's a lesson word
    } catch (_) { if (mounted) { _toast(t('err')); setState(() => busy = false); } }
  }

  @override
  Widget build(BuildContext c) {
    final hero = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.ch['avatar'], style: const TextStyle(fontSize: 120)),
      Text(widget.ch['name'], style: Theme.of(c).textTheme.headlineMedium),
    ]));
    final panel = Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [for (final m in msgs) _Bubble(m.$1, m.$2)])),
      if (busy) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.all(8), child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final w in words) ActionChip(label: Text(w, style: const TextStyle(fontSize: 22)), onPressed: () => _send(w)),
      ])),
      Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(iconSize: 44, onPressed: _snap, icon: const Icon(Icons.photo_camera)),
        const SizedBox(width: 24),
        IconButton.filled(iconSize: 56, onPressed: _listen, icon: Icon(listening ? Icons.stop : Icons.mic)),
      ])),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(widget.ch['name'])),
      body: SafeArea(
        child: LayoutBuilder(builder: (_, k) => k.maxWidth > k.maxHeight
            ? Row(children: [Expanded(flex: 2, child: hero), Expanded(flex: 3, child: panel)]) // landscape tablet
            : Column(children: [SizedBox(height: k.maxHeight * .26, child: FittedBox(child: hero)), Expanded(child: panel)])), // portrait / phone
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool child;
  final String text;
  const _Bubble(this.child, this.text);
  @override
  Widget build(BuildContext c) => Align(
        alignment: child ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(color: child ? Colors.deepPurple.shade100 : Colors.amber.shade100, borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: const TextStyle(fontSize: 26)),
        ),
      );
}
