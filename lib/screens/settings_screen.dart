import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'import_screen.dart';
import 'about_screen.dart';
import '../services/backup_service.dart';
import '../services/migration_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Tools & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Data Management'),
          _SettingsTile(
            icon: FontAwesomeIcons.download,
            title: 'Backup Data',
            subtitle: 'Export everything to a ZIP file',
            color: Colors.blue,
            onTap: () => BackupService(context, ref).createBackup(),
          ),
          _SettingsTile(
            icon: FontAwesomeIcons.upload,
            title: 'Restore Backup',
            subtitle: 'Restore from a native ZIP backup',
            color: Colors.green,
            onTap: () => BackupService(context, ref).restoreBackup(),
          ),
          _SettingsTile(
            icon: FontAwesomeIcons.fileCsv,
            title: 'Import CSV',
            subtitle: 'Import a single CSV file',
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
          
          const SizedBox(height: 20),
          _SectionHeader(title: 'Migration'),
          _SettingsTile(
            icon: FontAwesomeIcons.truckFast,
            title: 'Migrate from Simply Auto',
            subtitle: 'Import data from 3rd party apps',
            color: Colors.orange,
            onTap: () => MigrationService(context, ref).importFromZip(),
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'App Info'),
          _SettingsTile(
            icon: FontAwesomeIcons.circleInfo,
            title: 'About My Garage',
            subtitle: 'Version 1.0.0',
            color: Colors.grey,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: FaIcon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: onTap,
      ),
    );
  }
}