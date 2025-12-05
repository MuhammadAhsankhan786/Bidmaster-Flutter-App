import 'package:flutter/material.dart';

class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  // BestBid Color Palette
  static const Color _primary = Color(0xFF0A3069);
  static const Color _cardBackground = Color(0xFFFFFFFF);
  static const Color _borderColor = Color(0xFFDDDDDD);
  static const Color _selectedBorderColor = Color(0xFF0A3069);

  void _showCategoryDropdown(BuildContext context) {
    // Get all categories except 'All'
    final categoryList = categories.where((cat) => cat != 'All').toList();
    
    if (categoryList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No categories available')),
      );
      return;
    }

    // Show dropdown menu
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: _textLight,
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Category list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categoryList.length,
                itemBuilder: (context, index) {
                  final category = categoryList[index];
                  final isSelected = selectedCategory == category;
                  
                  return ListTile(
                    title: Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? _primary : _textDark,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: _primary, size: 20)
                        : null,
                    onTap: () {
                      onCategorySelected(category);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const Color _textDark = Color(0xFF222222);
  static const Color _textLight = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected = selectedCategory == category;
            final isAllCategory = category == 'All';
            
            return GestureDetector(
              onTap: () {
                if (isAllCategory) {
                  // Show dropdown for "All Products"
                  _showCategoryDropdown(context);
                } else {
                  // Direct selection for other categories
                  onCategorySelected(category);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _selectedBorderColor : _borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAllCategory ? 'All Products' : category,
                      style: TextStyle(
                        fontSize: 13,
                        color: _primary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (isAllCategory) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: _primary,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}





