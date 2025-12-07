import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Replace this with your actual GitHub URL
  final String _repoUrl = 'https://github.com/sachinsyam/vehicle_tracker';

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_repoUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Padding(
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
            ],
          ),
        ),
      ),
    );
  }
}