import 'package:flutter/material.dart';
import '../../core/config/theme.dart';

class ContentPickerSheet extends StatefulWidget {
  final String title;
  final String categoryName;
  final List<String> availableOptions;
  final List<String> selectedOptions;
  final Function(List<String>) onSave;
  final String? bookTitle;

  const ContentPickerSheet({
    super.key,
    required this.title,
    required this.categoryName,
    required this.availableOptions,
    required this.selectedOptions,
    required this.onSave,
    this.bookTitle,
  });

  @override
  State<ContentPickerSheet> createState() => _ContentPickerSheetState();
}

class _ContentPickerSheetState extends State<ContentPickerSheet> {
  late Set<String> _selected;
  final TextEditingController _customController = TextEditingController();
  late List<String> _allOptions;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedOptions);
    // Combine available options with existing selected custom items
    _allOptions = List.from(widget.availableOptions);
    for (final sel in widget.selectedOptions) {
      if (!_allOptions.contains(sel)) {
        _allOptions.add(sel);
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustomOption() {
    final text = _customController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_allOptions.contains(text)) {
          _allOptions.insert(0, text);
        }
        _selected.add(text);
        _customController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (widget.bookTitle != null)
                      Text(
                        'Filtered by: ${widget.bookTitle}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryEmerald, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // Custom Input Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: InputDecoration(
                    hintText: 'Add custom ${widget.categoryName.toLowerCase()}...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addCustomOption(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCustomOption,
                icon: const Icon(Icons.add, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Count Info
          Text(
            '${_selected.length} selected from bank',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),

          // Options List
          Expanded(
            child: _allOptions.isEmpty
                ? const Center(child: Text('No bank items found. You can add custom items above.'))
                : ListView.separated(
                    itemCount: _allOptions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = _allOptions[index];
                      final isSelected = _selected.contains(option);

                      return CheckboxListTile(
                        value: isSelected,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryEmerald,
                        title: Text(
                          option,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppTheme.textDark : AppTheme.textDark.withOpacity(0.85),
                          ),
                        ),
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              _selected.add(option);
                            } else {
                              _selected.remove(option);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          // Save / Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_selected.toList());
                Navigator.pop(context);
              },
              child: Text('Apply Changes (${_selected.length})'),
            ),
          ),
        ],
      ),
    );
  }
}
