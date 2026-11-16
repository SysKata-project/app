import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'theme.dart';
import '../features/destinations.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) => const TodayScreen(),
          ),
          GoRoute(
            path: '/learn',
            builder: (context, state) => const LearnScreen(),
          ),
          GoRoute(
            path: '/review',
            builder: (context, state) => const ReviewScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: FilledButton(
            onPressed: () => context.go('/today'),
            child: const Text('Return to Today'),
          ),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

class SysKataApp extends ConsumerWidget {
  const SysKataApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'SysKata',
    debugShowCheckedModeBanner: false,
    theme: KataTokens.theme(Brightness.light),
    darkTheme: KataTokens.theme(Brightness.dark),
    routerConfig: ref.watch(routerProvider),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  static const paths = ['/today', '/learn', '/review', '/profile'];
  static const labels = ['Today', 'Learn', 'Review', 'Profile'];
  static const icons = [
    Icons.wb_sunny_outlined,
    Icons.route_outlined,
    Icons.refresh,
    Icons.person_outline,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = paths.indexOf(path);
    final selected = index < 0 ? 0 : index;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 840 && size.height >= 500;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 24;
    void select(int i) => context.go(paths[i]);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SysKata'),
        actions: [
          if (ref.watch(configProvider).useFakeServices)
            const Padding(padding: EdgeInsets.all(12), child: Text('Preview')),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < 4; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                ],
              ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              top: false,
              child: largeText
                  ? Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Semantics(
                            selected: i == selected,
                            child: TextButton.icon(
                              onPressed: () => select(i),
                              icon: Icon(icons[i]),
                              label: Text(labels[i]),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(100, 56),
                              ),
                            ),
                          ),
                      ],
                    )
                  : NavigationBar(
                      selectedIndex: selected,
                      onDestinationSelected: select,
                      destinations: [
                        for (var i = 0; i < 4; i++)
                          NavigationDestination(
                            icon: Icon(icons[i]),
                            label: labels[i],
                          ),
                      ],
                    ),
            ),
    );
  }
}
