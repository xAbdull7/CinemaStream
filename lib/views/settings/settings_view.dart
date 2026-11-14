import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/gpu_service.dart';
import '../../core/services/tmdb_service.dart';
import '../../core/services/update_service.dart';
import '../../providers/library_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';

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

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
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
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: const Color(0xFF141926).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            locale.tr('clear_history'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            locale.tr('clear_history_confirm'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(locale.tr('cancel'), style: const TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(locale.tr('clear'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<LibraryProvider>().clearWatchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final locale = context.watch<LocaleProvider>();
    final isArabic = locale.isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // Background Atmospheric Liquid Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.4, -0.6),
                  radius: 1.5,
                  colors: [
                    Color(0xFF0F182A),
                    Color(0xFF0A0F1B),
                    Color(0xFF060910),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Main Scrollable Settings
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
              children: [
                // Top Navigation Bar
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الإعدادات والمجلدات' : 'Settings & Folders',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic
                              ? 'إدارة محرك العرض، المجلدات والتحديثات الذكية'
                              : 'Manage media folders, playback engine, and smart updates',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Version Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF76B900),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'v${UpdateService.currentVersion} Release',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // CARD 1: Media Folders & Scanning
                _buildLiquidCard(
                  icon: Icons.folder_copy_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  title: isArabic ? 'مجلدات الوسائط والمكتبة' : 'Media Folders & Library',
                  subtitle: isArabic
                      ? 'حدد مجلدات الأقراص الصلبة التي تحتوي على أفلامك ومسلسلاتك للتعرف عليها تلقائياً'
                      : 'Select hard drive folders containing movies and series to scan and index automatically',
                  children: [
                    if (library.mediaFolders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Center(
                          child: Text(
                            locale.tr('no_folders_yet'),
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...library.mediaFolders.map((folder) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_rounded, color: Color(0xFF00E5FF), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  folder,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: isArabic ? 'حذف المجلد' : 'Remove folder',
                                onPressed: () => library.removeMediaFolder(folder),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickFolder(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(locale.tr('add_folder')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.netflixRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: library.isScanning ? null : () => library.scanFolders(),
                          icon: library.isScanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(
                            library.isScanning
                                ? (isArabic ? 'جاري الفحص...' : 'Scanning...')
                                : (isArabic ? 'فحص المجلدات الآن' : 'Scan Folders Now'),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // CARD 2: NVIDIA RTX Video Super Resolution (VSR)
                Consumer<PlayerProvider>(
                  builder: (context, player, _) {
                    return _buildLiquidCard(
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFF76B900),
                      title: isArabic
                          ? 'محرك الذكاء الاصطناعي • NVIDIA RTX VSR'
                          : 'AI Video Engine • NVIDIA RTX Super Resolution',
                      subtitle: player.hasRtxGpu
                          ? (isArabic
                              ? 'تم الكشف عن كارت RTX (${GpuService.gpuName ?? 'NVIDIA RTX'}). يتم تطبيق مضاعفة الدقة وتحسين التفاصيل بالذكاء الاصطناعي تلقائياً لجميع الفيديوهات التي تقل عن 4K عبر أنوية Tensor.'
                              : 'Detected RTX GPU (${GpuService.gpuName ?? 'NVIDIA RTX'}). Real-time 2x AI upscaling via Tensor Cores is automatically applied to all videos under 4K.')
                          : (isArabic
                              ? 'لم يتم الكشف عن كارت NVIDIA RTX على هذا الجهاز. يتم استخدام فك التشفير القياسي السريع hwdec=auto-safe.'
                              : 'No NVIDIA RTX GPU detected. Standard high-performance hardware decoding (hwdec=auto-safe) is in use.'),
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: player.hasRtxGpu
                              ? const Color(0xFF76B900).withOpacity(0.15)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: player.hasRtxGpu
                                ? const Color(0xFF76B900).withOpacity(0.6)
                                : Colors.white12,
                          ),
                        ),
                        child: Text(
                          player.hasRtxGpu ? 'RTX ACTIVE' : 'STANDARD',
                          style: TextStyle(
                            color: player.hasRtxGpu ? const Color(0xFF76B900) : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      children: [
                        if (player.hasRtxGpu)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: player.isRtxVsrEnabled,
                            activeColor: const Color(0xFF76B900),
                            title: Text(
                              isArabic
                                  ? 'تفعيل المعالجة الفائقة بالذكاء الاصطناعي تلقائياً'
                                  : 'Enable Real-Time AI Super Resolution',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              isArabic
                                  ? 'مضاعفة الحدة والدقة عبر أنوية Tensor دون أي استهلاك لمعالج الحاسوب'
                                  : 'Real-time neural upscaling via Tensor Cores with zero CPU overhead',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            onChanged: (val) => player.setRtxVsrEnabled(val),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // CARD 3: Smart Software Updates & Version
                _buildLiquidCard(
                  icon: Icons.system_update_alt_rounded,
                  iconColor: const Color(0xFF818CF8),
                  title: isArabic ? 'التحديثات الذكية والإصدار' : 'Smart Software Updates & Version',
                  subtitle: isArabic
                      ? 'نظام التحديث الصامت الذكي: يتم تنزيل الملفات الجديدة ودمجها تلقائياً وإعادة التشغيل دون معالجات تثبيت'
                      : 'Silent Auto-Update System: Automatically downloads, merges files, and relaunches with zero manual wizard steps',
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            isArabic
                                ? 'الإصدار المثبت: v${UpdateService.currentVersion}'
                                : 'Installed Version: v${UpdateService.currentVersion}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          onPressed: () => UpdateService.checkAndPromptUpdate(context, isManual: true),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(isArabic ? 'التحقق من وجود تحديثات الآن' : 'Check for Updates Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // CARD 4: TMDB Metadata & High-Res Posters
                _buildLiquidCard(
                  icon: Icons.movie_filter_rounded,
                  iconColor: const Color(0xFFFFB300),
                  title: isArabic ? 'بيانات الأفلام والبوسترات (TMDB API)' : 'Metadata & Posters (TMDB API)',
                  subtitle: isArabic
                      ? 'مفتاح TMDB لجلب البوسترات عالية الجودة، الخلفيات، التقييمات، ونبذة العمل تلقائياً'
                      : 'Enter your free TMDB API key to fetch high-res posters, backdrops, ratings, and synopses',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: _apiKeyController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: isArabic ? 'أدخل مفتاح TMDB API...' : 'Enter your TMDB API key...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            context.read<LibraryProvider>().setTmdbApiKey(_apiKeyController.text.trim());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isArabic ? 'حفظ' : 'Save'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // CARD 5: Preferences & Watch History
                _buildLiquidCard(
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  title: isArabic ? 'تفضيلات الواجهة وسجل المشاهدة' : 'Interface & Watch History',
                  subtitle: isArabic
                      ? 'اختر لغة الواجهة وأدر نقاط استكمال المشاهدة السابقة'
                      : 'Choose application display language and manage your resume points',
                  children: [
                    Row(
                      children: [
                        Text(
                          isArabic ? 'لغة الواجهة:' : 'Interface Language:',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 14),
                        ChoiceChip(
                          label: const Text('English (EN)'),
                          selected: !locale.isArabic,
                          selectedColor: AppColors.netflixRed,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          labelStyle: TextStyle(
                            color: !locale.isArabic ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) locale.setLocale('en');
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('العربية (AR)'),
                          selected: locale.isArabic,
                          selectedColor: AppColors.netflixRed,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          labelStyle: TextStyle(
                            color: locale.isArabic ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) locale.setLocale('ar');
                          },
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isArabic
                                ? 'إعادة ضبط وحذف سجل المشاهدة بالكامل لجميع الأفلام والمسلسلات'
                                : 'Reset and remove all watched progress and resume timestamps across all media',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _confirmClearHistory(context, locale),
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 16),
                          label: Text(
                            locale.tr('clear_history'),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Categorized Liquid Glass Container Card ---
  Widget _buildLiquidCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailingBadge,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF131722).withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: iconColor.withOpacity(0.4), width: 1),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 19),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailingBadge != null) trailingBadge,
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Colors.white10, height: 1),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
