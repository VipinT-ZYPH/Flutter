import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/journal/data/journal_repository.dart';
import '../../features/journal/domain/journal.dart';

final journalsProvider = StreamProvider((ref) {
  return ref.watch(Provider((ref) => JournalRepository())).getJournals();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsyncValue = ref.watch(journalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Journal')),
      body: journalsAsyncValue.when(
        data: (journals) => ListView.builder(
          itemCount: journals.length,
          itemBuilder: (context, index) {
            final journal = journals[index];
            return ListTile(title: Text(journal.title));
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/editor'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
