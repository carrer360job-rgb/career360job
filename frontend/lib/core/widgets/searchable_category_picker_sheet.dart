import 'package:flutter/material.dart';

/// A modern, searchable bottom sheet / dialog picker with custom item creation.
/// Matches Career360 Emerald Growth Theme (#064E3B, #065F46, #16A34A).
class SearchableCategoryPickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final IconData defaultIcon;
  final String? searchHint;

  const SearchableCategoryPickerSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedItem,
    this.defaultIcon = Icons.label_outline,
    this.searchHint,
  });

  /// Displays the picker sheet in a bottom sheet on mobile or dialog on wide screens.
  static Future<String?> show({
    required BuildContext context,
    required String title,
    required List<String> items,
    String? selectedItem,
    IconData defaultIcon = Icons.label_outline,
    String? searchHint,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 640;

    if (isDesktop) {
      return showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SearchableCategoryPickerSheet(
                title: title,
                items: items,
                selectedItem: selectedItem,
                defaultIcon: defaultIcon,
                searchHint: searchHint,
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: SearchableCategoryPickerSheet(
              title: title,
              items: items,
              selectedItem: selectedItem,
              defaultIcon: defaultIcon,
              searchHint: searchHint,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<SearchableCategoryPickerSheet> createState() =>
      _SearchableCategoryPickerSheetState();
}

class _SearchableCategoryPickerSheetState
    extends State<SearchableCategoryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _allItems;
  List<String> _filteredItems = [];
  String _currentQuery = '';

  // Theme Tokens
  static const Color _deepForest = Color(0xFF064E3B);
  static const Color _deepPine = Color(0xFF065F46);
  static const Color _emeraldPrimary = Color(0xFF16A34A);
  static const Color _mintBg = Color(0xFFF0FDF4);
  static const Color _mintBorder = Color(0xFFBBF7D0);
  static const Color _navyText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _inputBorder = Color(0xFFD0D5DD);
  static const Color _dividerColor = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _allItems = List.from(widget.items);
    _filteredItems = List.from(_allItems);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _currentQuery = query;
      if (query.isEmpty) {
        _filteredItems = List.from(_allItems);
      } else {
        _filteredItems = _allItems
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  bool get _shouldShowAddCard {
    if (_currentQuery.isEmpty) return false;
    final normalized = _currentQuery.toLowerCase();
    return !_allItems.any((item) => item.toLowerCase() == normalized);
  }

  void _selectItem(String value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Banner
          _buildHeaderBanner(),

          // 2. Search Field
          _buildSearchBox(),

          // 3. Dynamic "+ Use" Custom Item Card (Image 3)
          if (_shouldShowAddCard) _buildCustomItemCard(),

          // 4. Scrollable Item List
          Expanded(
            child: _filteredItems.isEmpty && !_shouldShowAddCard
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: _dividerColor,
                      indent: 52,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item == widget.selectedItem;
                      return _buildItemRow(item, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deepForest, _deepPine, _emeraldPrimary],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(widget.defaultIcon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _inputBorder, width: 1.2),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: false,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _navyText,
          ),
          decoration: InputDecoration(
            hintText: widget.searchHint ?? 'Search ${widget.title}...',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _secondaryText,
              size: 20,
            ),
            suffixIcon: _currentQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomItemCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: _mintBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectItem(_currentQuery),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _mintBorder, width: 1.4),
            ),
            child: Row(
              children: [
                // Circular Plus Badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: _emeraldPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Use "$_currentQuery"',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _deepForest,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to select this custom item',
                        style: TextStyle(
                          fontSize: 12,
                          color: _deepPine,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _deepPine,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(String item, bool isSelected) {
    return Material(
      color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
      child: InkWell(
        onTap: () => _selectItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                widget.defaultIcon,
                size: 20,
                color: isSelected ? _emeraldPrimary : _secondaryText,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _deepForest : _navyText,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: _emeraldPrimary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 10),
            Text(
              'No items matching "$_currentQuery"',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type to add a new custom category above',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
