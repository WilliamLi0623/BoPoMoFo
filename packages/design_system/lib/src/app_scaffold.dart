import 'package:material_ui/material_ui.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.homeLabel,
    required this.dashboardLabel,
    required this.settingsLabel,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
  });

  final String title;
  final String homeLabel;
  final String dashboardLabel;
  final String settingsLabel;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      NavigationDestination(key: const ValueKey('nav-home'), icon: const Icon(Icons.home_outlined), label: homeLabel),
      NavigationDestination(key: const ValueKey('nav-dashboard'), icon: const Icon(Icons.dashboard_outlined), label: dashboardLabel),
      NavigationDestination(key: const ValueKey('nav-settings'), icon: const Icon(Icons.settings_outlined), label: settingsLabel),
    ];
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
