import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  final String _repoUrl = 'https://github.com/sachinsyam/vehicle_tracker';

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_repoUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                padding: const EdgeInsets.all(15), // Reduced padding slightly for the image
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                // 👇 REPLACED ICON WITH ASSET IMAGE
                child: Image.asset(
                  'assets/icon.png',
                  width: 80,
                  height: 80,
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

              const SizedBox(height: 15),

              // License Button
              OutlinedButton(
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'My Garage',
                    applicationVersion: '1.0.0',
                    // Also use the asset icon here
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/icon.png', width: 48, height: 48),
                    ),
                  );
                },
                child: const Text('Open Source Licenses'),
              ),
              
              const SizedBox(height: 20),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),

              // 👇 NUKE DATA BUTTON (Commented out for release)
              /*
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  await db.deleteAllData();
                  
                  ref.refresh(vehicleListProvider);
                  ref.refresh(allExpensesProvider);
                  
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
              */
            ],
          ),
        ),
      ),
    );
  }
}