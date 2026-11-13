import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/library_provider.dart';

class PillNavbar extends StatefulWidget {
  final NavTab activeTab;
  final ValueChanged<NavTab> onTabChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenSettings;
  final bool isArabic;

  const PillNavbar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onOpenSettings,
    required this.isArabic,
  });

  @override
  State<PillNavbar> createState() => _PillNavbarState();
}

class _PillNavbarState extends State<PillNavbar> {
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchFocusNode.requestFocus();
      } else {
        widget.searchController.clear();
        widget.onSearchChanged('');
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x38FFFFFF),
                Color(0x15FFFFFF),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.12),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Home Tab
              _buildTabItem(
                tab: NavTab.home,
                icon: Icons.home_rounded,
                label: widget.isArabic ? 'الرئيسية' : 'Home',
              ),

              // 2. Movies Tab
              _buildTabItem(
                tab: NavTab.movies,
                label: widget.isArabic ? 'أفلام' : 'Movies',
              ),

              // 3. Shows Tab
              _buildTabItem(
                tab: NavTab.shows,
                label: widget.isArabic ? 'مسلسلات' : 'Shows',
              ),

              // 4. My List Tab
              _buildTabItem(
                tab: NavTab.myList,
                label: widget.isArabic ? 'قائمتي' : 'My List',
              ),

              // Glass Divider between Tabs and Action Icons
              Container(
                height: 20,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                ),
              ),

              // 5. Expandable Search Input
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: _isSearchExpanded ? 200 : 0,
                child: _isSearchExpanded
                    ? Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: TextField(
                          controller: widget.searchController,
                          focusNode: _searchFocusNode,
                          onChanged: widget.onSearchChanged,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          cursorColor: AppColors.netflixRed,
                          decoration: InputDecoration(
                            hintText: widget.isArabic ? 'بحث في مكتبتك...' : 'Search library...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Search Toggle Icon
              _buildActionButton(
                icon: _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                tooltip: widget.isArabic ? 'بحث' : 'Search',
                isActive: _isSearchExpanded,
                onTap: _toggleSearch,
              ),

              const SizedBox(width: 4),

              // 6. Settings Action
              _buildActionButton(
                icon: Icons.settings_outlined,
                tooltip: widget.isArabic ? 'الإعدادات' : 'Settings',
                onTap: widget.onOpenSettings,
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required NavTab tab,
    required String label,
    IconData? icon,
  }) {
    final isSelected = widget.activeTab == tab;

    return GestureDetector(
      onTap: () {
        if (_isSearchExpanded) {
          _toggleSearch();
        }
        widget.onTabChanged(tab);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : Colors.white.withOpacity(0.85),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.netflixRed : Colors.white.withOpacity(0.85),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
