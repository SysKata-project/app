import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/models.dart';

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KataTokens.maxContentWidth),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final child in children)
            Padding(padding: const EdgeInsets.only(bottom: 24), child: child),
        ],
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
      ),
      const SizedBox(height: 12),
      Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class FailureCard extends StatelessWidget {
  const FailureCard({required this.error, required this.retry, super.key});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) {
    final signIn =
        error is ServiceFailure &&
        (error as ServiceFailure).recovery == 'sign_in';
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            signIn ? 'Sign-in is needed' : 'We could not load this right now',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            signIn
                ? 'Account sign-in will be connected in the next authentication milestone.'
                : 'Your confirmed progress has not changed. Try again when you are connected.',
          ),
          if (!signIn)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton(
                onPressed: retry,
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const Heading(
        'A little practice.\nLasting confidence.',
        'Build your OpenShift skills, one focused session at a time.',
      ),
      InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/branding/kata-avatar-512.png',
              width: 96,
              height: 96,
              semanticLabel: 'Kata, your red panda practice companion',
            ),
            const SizedBox(height: 16),
            Text(
              'One more rep?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Explore the learning path and find your next step.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/learn'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Explore learning'),
            ),
          ],
        ),
      ),
      if (ref.watch(configProvider).useFakeServices)
        const Text(
          'Development preview · Sample content and progress only. No learning activity is saved to a server.',
        ),
      ref
          .watch(progressProvider)
          .when(
            data: (progress) => ProgressCard(progress: progress),
            error: (error, stack) => FailureCard(
              error: error,
              retry: () => ref.invalidate(progressProvider),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading progress',
              ),
            ),
          ),
    ],
  );
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({required this.progress, super.key});
  final Progress progress;
  @override
  Widget build(BuildContext context) => InfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your practice', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            Text('${progress.totalXp} XP'),
            Text('${progress.streak} day streak'),
            Text('${progress.completedLessons.length} lessons completed'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          progress.dailyGoalCompleted
              ? 'Daily goal complete'
              : 'A fresh opportunity to practice',
        ),
      ],
    ),
  );
}

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const Heading(
        'Choose your path',
        'Seven pilot lessons and two planned hands-on checkpoints. A focused slice of OpenShift, not full course coverage.',
      ),
      ref
          .watch(catalogProvider)
          .when(
            data: (catalog) => Column(
              children: [
                for (final journey in catalog.journeys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.terminal, size: 32),
                          const SizedBox(height: 16),
                          Text(
                            journey.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text('${journey.unitIds.length} learning units'),
                          const SizedBox(height: 12),
                          const Text(
                            'Lesson activities will be available in a later milestone.',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            error: (error, stack) => FailureCard(
              error: error,
              retry: () => ref.invalidate(catalogProvider),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading learning paths',
              ),
            ),
          ),
    ],
  );
}

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageBody(
    children: [
      Heading(
        'Make it stick',
        'Return to a skill. Build confidence through practice.',
      ),
      InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.refresh, size: 40),
            SizedBox(height: 16),
            Text('Your review space is taking shape.'),
            SizedBox(height: 12),
            Text(
              'Personalized review will appear here when the review service is connected.',
            ),
          ],
        ),
      ),
    ],
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const Heading(
        'Your practice, your pace',
        'A home for your progress and preferences.',
      ),
      ref
          .watch(progressProvider)
          .when(
            data: (progress) => ProgressCard(progress: progress),
            error: (error, stack) => FailureCard(
              error: error,
              retry: () => ref.invalidate(progressProvider),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading profile',
              ),
            ),
          ),
      const InfoCard(
        child: Text(
          'Account sign-in and settings are coming in the authentication milestone. Theme follows your device settings.',
        ),
      ),
      const Text(
        'SysKata is independent and is not affiliated with or endorsed by Red Hat.',
      ),
    ],
  );
}
