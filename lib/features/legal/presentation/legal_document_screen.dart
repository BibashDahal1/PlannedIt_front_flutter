import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/legal_providers.dart';

/// Deliberately plain Material styling rather than the app's
/// hand-drawn theme -- dense legal text needs to stay easy to read,
/// not wobbly.
class LegalDocumentScreen extends ConsumerWidget {
  final String documentType;
  const LegalDocumentScreen({super.key, required this.documentType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(legalDocumentProvider(documentType));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: docAsync.maybeWhen(
          data: (d) => Text(d.title),
          orElse: () => const Text('Legal'),
        ),
      ),
      body: docAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load this document: $e')),
        data: (doc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Version ${doc.version} · published ${_formatDate(doc.publishedAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            Expanded(
              child: Markdown(
                data: doc.content,
                padding: const EdgeInsets.all(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
