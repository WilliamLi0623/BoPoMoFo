import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  static const destinations = <NavigationDestination>[
    NavigationDestination(key: ValueKey('nav-home'), icon: Icon(Icons.home_outlined), label: 'Home'),
    NavigationDestination(key: ValueKey('nav-dashboard'), icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
    NavigationDestination(key: ValueKey('nav-settings'), icon: Icon(Icons.settings_outlined), label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map((item) => NavigationRailDestination(
                            icon: item.icon,
                            label: Text(item.label, key: item.key),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            );
          }
          return Column(children: [Expanded(child: body), navigation]);
        },
      ),
    );
  }
}
