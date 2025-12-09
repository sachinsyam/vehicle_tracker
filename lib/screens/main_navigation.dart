import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'home_screen.dart';     
import 'expense_report_screen.dart'; 
import 'settings_screen.dart'; // We will create this next

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),          
    const ExpenseReportScreen(), 
    const SettingsScreen(),      
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.car),
            selectedIcon: FaIcon(FontAwesomeIcons.carSide),
            label: 'Garage',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.chartPie),
            selectedIcon: FaIcon(FontAwesomeIcons.chartPie),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.toolbox),
            selectedIcon: FaIcon(FontAwesomeIcons.screwdriverWrench),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}