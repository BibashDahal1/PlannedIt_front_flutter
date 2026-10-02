import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../data/trust_providers.dart';
import '../domain/report_reason.dart';
import '../../../core/widgets/user_avatar.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  final String?
  activityId; // passed when opened from an activity's host card, so a report can reference it

  const PublicProfileScreen({super.key, required this.userId, this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _showReportSheet(context, ref);
              if (value == 'block') _confirmBlock(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'report', child: Text('Report user')),
              PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: UserAvatar(avatarUrl: profile.avatar, radius: 44)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                profile.fullName.isEmpty ? 'User' : profile.fullName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(
                  label: 'Rating',
                  value: profile.averageRating != null
                      ? profile.averageRating!.toStringAsFixed(1)
                      : '—',
                ),
                _StatColumn(label: 'Reviews', value: '${profile.ratingsCount}'),
                _StatColumn(
                  label: 'Hosted',
                  value: '${profile.activitiesHosted}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row(
                      label: 'Verification',
                      value: profile.verificationStatus,
                    ),
                    _Row(label: 'Trust tier', value: profile.trustTier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context, WidgetRef ref) {
    String? selectedReason;
    final detailsController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report this user',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: reportReasons
                    .map(
                      (r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedReason = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(trustRepositoryProvider)
                              .submitReport(
                                reportedUserId: userId,
                                activityPostId: activityId,
                                reason: selectedReason!,
                                details: detailsController.text.trim(),
                              );
                          if (sheetContext.mounted)
                            Navigator.of(sheetContext).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(extractApiErrorMessage(e)),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBlock(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          "You won't see each other's activities. This can be undone later in Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(trustRepositoryProvider).blockUser(userId);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(extractApiErrorMessage(e))),
                  );
                }
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
