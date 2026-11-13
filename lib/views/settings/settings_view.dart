import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/tmdb_service.dart';
import '../../core/services/update_service.dart';
import '../../providers/library_provider.dart';
import '../../providers/locale_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = TmdbService.apiKey ?? '';
  }

  Future<void> _pickFolder(BuildContext context) async {
    final library = context.read<LibraryProvider>();
    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Media Directory / اختر مجلد الأفلام أو المسلسلات',
    );

    if (selectedDirectory != null) {
      await library.addMediaFolder(selectedDirectory);
    }
  }

  Future<void> _confirmClearHistory(BuildContext context, LocaleProvider locale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(locale.tr('clear_history')),
        content: Text(locale.tr('clear_history_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(locale.tr('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.netflixRed),
            child: Text(locale.tr('clear'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<LibraryProvider>().clearWatchHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.isArabic ? 'تم مسح سجل المشاهدة بنجاح' : 'Watch history cleared successfully'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.tr('settings')),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        children: [
          // Section 1: Language Selection
          Text(
            locale.tr('language'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: const Text('English (EN)'),
                selected: !locale.isArabic,
                selectedColor: AppColors.netflixRed,
                backgroundColor: AppColors.cardBackground,
                onSelected: (selected) {
                  if (selected) locale.setLocale('en');
                },
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('العربية (AR)'),
                selected: locale.isArabic,
                selectedColor: AppColors.netflixRed,
                backgroundColor: AppColors.cardBackground,
                onSelected: (selected) {
                  if (selected) locale.setLocale('ar');
                },
              ),
            ],
          ),

          const SizedBox(height: 36),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),

          // Section 2: Media Folders
          Text(
            locale.tr('media_folders'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            locale.tr('media_folders_desc'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),

          // Folder List
          if (library.mediaFolders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Text(
                  locale.tr('no_folders_yet'),
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            )
          else
            ...library.mediaFolders.map((folder) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder_special_rounded, color: AppColors.netflixRed),
                  title: Text(folder),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => library.removeMediaFolder(folder),
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),
          Align(
            alignment: locale.isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _pickFolder(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(locale.tr('add_folder')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 36),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),

          // Section 3: TMDB API Metadata
          Text(
            locale.tr('tmdb_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            locale.tr('tmdb_desc'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    hintText: locale.tr('tmdb_hint'),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.netflixRed),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<LibraryProvider>().setTmdbApiKey(_apiKeyController.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(locale.tr('saved_successfully'))),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                child: Text(locale.tr('save')),
              ),
            ],
          ),

          const SizedBox(height: 36),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),

          // Section 4: History Management
          Text(
            locale.tr('clear_history'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            locale.isArabic
                ? 'إعادة ضبط وحذف سجل المشاهدة بالكامل لجميع الأفلام والمسلسلات:'
                : 'Reset and remove all watched progress and resume timestamps across all media:',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: locale.isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _confirmClearHistory(context, locale),
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              label: Text(locale.tr('clear_history'), style: const TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 36),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),

          // Section 5: Manual Scan Trigger
          Align(
            alignment: locale.isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: library.isScanning
                  ? null
                  : () async {
                      await library.scanFolders();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(locale.tr('scan_completed'))),
                        );
                      }
                    },
              icon: const Icon(Icons.sync_rounded),
              label: Text(library.isScanning
                  ? (locale.isArabic ? 'جاري الفحص...' : 'Scanning...')
                  : locale.tr('scan_now')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixDarkRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 36),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),

          // Section 6: Software Updates & App Info
          Text(
            locale.isArabic ? 'تحديثات البرنامج والإصدار' : 'Software Updates & Version',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            locale.isArabic
                ? 'الإصدار الحالي: v${UpdateService.currentVersion} • تحقق من توفر تحديثات جديدة عبر GitHub'
                : 'Current Version: v${UpdateService.currentVersion} • Check for new releases on GitHub',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: locale.isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => UpdateService.checkAndPromptUpdate(context, isManual: true),
              icon: const Icon(Icons.system_update_alt_rounded, color: Colors.white),
              label: Text(
                locale.isArabic ? 'التحقق من وجود تحديثات الآن' : 'Check for Updates Now',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
