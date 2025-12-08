import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers.dart';

class AboutScreen extends ConsumerWidget { // 👈 Changed to ConsumerWidget
  const AboutScreen({super.key});

  final String _repoUrl = 'https://github.com/sachinsyam/vehicle_tracker';

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_repoUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) { // 👈 Added WidgetRef ref
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon / Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_filled,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              
              // App Name & Version
              const Text(
                'My Garage',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              
              const SizedBox(height: 30),
              
              // Description
              const Text(
                'An open source free vehicle maintenance tracker built with Flutter. Track expenses, service history, and fuel efficiency with ease.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              
              const SizedBox(height: 40),
              
              // GitHub Button
              FilledButton.icon(
                onPressed: _launchUrl,
                icon: const Icon(Icons.code),
                label: const Text('View Source on GitHub'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 20),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),

              // 👇 NUKE DATA BUTTON
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  // 1. Delete all data
                  final db = ref.read(databaseProvider);
                  await db.deleteAllData();
                  
                  // 2. Refresh UI
                  ref.refresh(vehicleListProvider);
                  ref.refresh(allExpensesProvider);
                  
                  // 3. Show feedback
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💥 All data permanently deleted!'), 
                        backgroundColor: Colors.red
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'NUKE DATA (TESTING ONLY)', 
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}