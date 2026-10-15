import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../data/journal_repository.dart';
import '../domain/journal.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key});

  @override
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _contentController, decoration: const InputDecoration(labelText: 'Content'), maxLines: null),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                final journal = Journal(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: user.uid,
                  title: _titleController.text,
                  content: _contentController.text,
                  tags: [],
                  mood: 'neutral',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await ref.read(Provider((ref) => JournalRepository())).createJournal(journal);
                context.pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
