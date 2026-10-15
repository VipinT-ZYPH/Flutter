import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _ink = Color(0xFF292724);
const _muted = Color(0xFF756F68);
const _paper = Color(0xFFFAF8F5);
const _line = Color(0xFFE8E2DB);
const _gold = Color(0xFFB47724);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReflectAiApp());
}

class ReflectAiApp extends StatelessWidget {
  const ReflectAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReflectAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _gold,
          brightness: Brightness.light,
          surface: _paper,
        ),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _gold, width: 1.5),
          ),
        ),
      ),
      home: const WorkspaceScreen(),
    );
  }
}

class JournalEntry {
  JournalEntry({
    required this.title,
    required this.content,
    required this.mood,
    required this.date,
    this.reflection,
  });

  final String title;
  final String content;
  final String mood;
  final DateTime date;
  final Reflection? reflection;

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'mood': mood,
    'date': date.toIso8601String(),
    'reflection': reflection?.toJson(),
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final reflection = json['reflection'] as Map<String, dynamic>?;
    return JournalEntry(
      title: json['title'] as String? ?? 'Untitled reflection',
      content: json['content'] as String? ?? '',
      mood: json['mood'] as String? ?? 'Reflective',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      reflection: reflection == null ? null : Reflection.fromJson(reflection),
    );
  }
}

class Reflection {
  const Reflection({
    required this.summary,
    required this.prompt,
    required this.score,
  });

  final String summary;
  final String prompt;
  final double score;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'prompt': prompt,
    'score': score,
  };

  factory Reflection.fromJson(Map<String, dynamic> json) => Reflection(
    summary: json['summary'] as String? ?? 'A thoughtful moment of reflection.',
    prompt:
        json['prompt'] as String? ??
        'What would support you most in this moment?',
    score: (json['score'] as num?)?.toDouble() ?? 7,
  );
}

class GeminiService {
  GeminiService({String? apiKey})
    : apiKey =
          apiKey ??
          const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final String apiKey;
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<String> _generate(String prompt) async {
    if (!isConfigured) {
      throw StateError(
        'Gemini is not configured. Start the app with '
        '--dart-define=GEMINI_API_KEY=your-key',
      );
    }

    final response = await http.post(
      Uri.parse('$_endpoint?key=${Uri.encodeQueryComponent(apiKey)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini request failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    final content = candidates != null && candidates.isNotEmpty
        ? candidates.first as Map<String, dynamic>
        : null;
    final parts = content?['content'] as Map<String, dynamic>?;
    final responseParts = parts?['parts'] as List<dynamic>?;
    final text = responseParts != null && responseParts.isNotEmpty
        ? responseParts.first as Map<String, dynamic>
        : null;
    final result = text?['text'] as String?;
    if (result == null || result.trim().isEmpty) {
      throw StateError('Gemini returned an empty response');
    }
    return result.trim();
  }

  Future<Reflection> reflect(JournalEntry entry) async {
    final raw = await _generate('''
You are an empathetic personal reflection mentor.
Analyze this journal entry and return only JSON:
{"summary":"one or two compassionate sentences","prompt":"one open-ended growth question","score":7.5}

Title: ${entry.title}
Mood: ${entry.mood}
Entry:
${entry.content}
''');
    final json = _decodeJson(raw);
    return Reflection.fromJson(json);
  }

  Future<String> chat(List<Map<String, String>> messages) async {
    final transcript = messages
        .map((message) => '${message['role']}: ${message['text']}')
        .join('\n');
    final raw = await _generate('''
You are ReflectAI, an empathetic and practical reflection companion.
Respond warmly in 2-4 sentences. Do not diagnose, moralize, or claim to be a
therapist. Ask at most one gentle follow-up question.

Conversation:
$transcript
''');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['text'] is String) {
        return decoded['text'] as String;
      }
    } catch (_) {
      // Gemini may return plain text when the response config is relaxed.
    }
    return raw.replaceAll(RegExp(r'^```(?:json)?|```$'), '').trim();
  }

  Map<String, dynamic> _decodeJson(String value) {
    final cleaned = value
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'^```\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Gemini returned invalid reflection JSON');
    }
    return decoded;
  }
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const _entriesKey = 'reflectai.entries';
  final _gemini = GeminiService();
  final _entries = <JournalEntry>[
    JournalEntry(
      title: 'A morning walk and mental clarity',
      content: 'Woke up early and walked without my phone. Stillness reminded me that slowing down is not lost time.',
      mood: 'Peaceful',
      date: DateTime(2026, 9, 14),
      reflection: const Reflection(
        summary: 'Your choice to step away from screens created space for clarity and renewed focus.',
        prompt: 'How can you protect a small perimeter of digital silence tomorrow?',
        score: 8.8,
      ),
    ),
  ];
  int _tab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_entriesKey);
    if (stored != null && stored.isNotEmpty) {
      _entries
        ..clear()
        ..addAll(
          stored.map(
            (entry) => JournalEntry.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ),
          ),
        );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveEntries() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _entriesKey,
      _entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ReflectAI',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Privacy',
            onPressed: () => _showMessage('Your reflections stay private.'),
            icon: const Icon(Icons.lock_outline),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFE8DED0),
              child: Text('Y', style: TextStyle(color: _ink)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _tab,
                children: [
                  _Dashboard(
                    entries: _entries,
                    onNewEntry: _openEditor,
                    onChat: () => setState(() => _tab = 1),
                  ),
                  _Chat(service: _gemini),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Workspace',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Talk to AI',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openEditor,
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New reflection'),
            )
          : null,
    );
  }

  Future<void> _openEditor() async {
    final entry = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (_) => const _EntryEditor(),
    );
    if (entry == null) return;
    JournalEntry saved = JournalEntry(
      title: entry.title,
      content: entry.content,
      mood: entry.mood,
      date: entry.date,
      reflection: const Reflection(
        summary: 'You made space to notice what is happening within you. That attention is a meaningful first step.',
        prompt:
            'What is one gentle action that would honor this feeling today?',
        score: 7.4,
      ),
    );
    if (_gemini.isConfigured) {
      try {
        saved = JournalEntry(
          title: entry.title,
          content: entry.content,
          mood: entry.mood,
          date: entry.date,
          reflection: await _gemini.reflect(entry),
        );
      } catch (error) {
        if (mounted) {
          _showMessage(
            'Saved locally. Gemini reflection failed: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }
    }
    if (mounted) {
      setState(() => _entries.insert(0, saved));
      await _saveEntries();
      _showMessage('Reflection saved');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.entries,
    required this.onNewEntry,
    required this.onChat,
  });

  final List<JournalEntry> entries;
  final VoidCallback onNewEntry;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final latest = entries.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        Text(
          'Good morning,',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: _muted),
        ),
        const SizedBox(height: 2),
        Text(
          'Make room for what matters.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 22),
        _InsightCard(onChat: onChat),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your reflections',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(onPressed: onNewEntry, child: const Text('Add new')),
          ],
        ),
        const SizedBox(height: 8),
        _EntryCard(entry: latest),
        if (entries.length > 1)
          ...entries
              .skip(1)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _EntryCard(entry: entry),
                ),
              ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(
              child: _FeatureTile(
                icon: Icons.shield_outlined,
                title: 'Private by design',
                text: 'Your inner world is yours alone.',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _FeatureTile(
                icon: Icons.auto_awesome,
                title: 'Gemini insights',
                text: 'Clarity without judgment.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.onChat});
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2E5CF), Color(0xFFF9F3E9)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8D4B4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: _gold),
              SizedBox(width: 8),
              Text(
                'A moment to reflect',
                style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'What feels heavier than it needs to today?',
            style: TextStyle(
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You do not have to solve it all at once. Start with an honest sentence.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onChat,
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: const Text('Explore with AI'),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(entry.date),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                _MoodChip(entry.mood),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              entry.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
            if (entry.reflection != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: _line),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.reflection!.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.reflection!.score.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _gold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip(this.mood);
  final String mood;

  @override
  Widget build(BuildContext context) {
    final emoji =
        {
          'Peaceful': '🕊️',
          'Grateful': '🌿',
          'Anxious': '🌧️',
          'Energized': '✨',
        }[mood] ??
        '◌';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji  $mood',
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF46724C),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: _muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor();

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _mood = 'Reflective';

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'New reflection',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'There is no right way to write this.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 6,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What is on your mind?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How are you feeling?',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              children:
                  ['Reflective', 'Peaceful', 'Grateful', 'Anxious', 'Energized']
                      .map(
                        (mood) => ChoiceChip(
                          label: Text(mood),
                          selected: _mood == mood,
                          onSelected: (_) => setState(() => _mood = mood),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _content.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        JournalEntry(
                          title: _title.text.trim().isEmpty
                              ? 'Untitled reflection'
                              : _title.text.trim(),
                          content: _content.text.trim(),
                          mood: _mood,
                          date: DateTime.now(),
                        ),
                      ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Save and reflect'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chat extends StatefulWidget {
  const _Chat({required this.service});
  final GeminiService service;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _messages = <Map<String, String>>[
    {
      'role': 'assistant',
      'text': 'I’m here with you. What would you like to make a little more clear today?',
    },
  ];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
    });
    String reply;
    if (widget.service.isConfigured) {
      try {
        reply = await widget.service.chat(_messages);
      } catch (error) {
        reply =
            'I could not reach Gemini right now. Your message is still here '
            'locally, and one small kind next step may be enough for today.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      reply =
          'Gemini is not configured yet. Your message is saved in this demo. '
          'What part of this feels most within your control right now?';
    }
    if (mounted) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': reply});
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            children: [
              const Text(
                'Your reflection companion',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'A private space to untangle thoughts, without judgment.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              ..._messages.map((message) => _MessageBubble(message: message)),
              if (_sending)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'ReflectAI is thinking…',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Write what is on your mind…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Map<String, String> message;

  @override
  Widget build(BuildContext context) {
    final user = message['role'] == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: user ? _ink : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(user ? 17 : 4),
            bottomRight: Radius.circular(user ? 4 : 17),
          ),
          border: user ? null : Border.all(color: _line),
        ),
        child: Text(
          message['text']!,
          style: TextStyle(color: user ? Colors.white : _ink, height: 1.45),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
