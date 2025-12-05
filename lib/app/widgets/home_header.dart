import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeHeader extends StatelessWidget {
  final TextEditingController? searchController;
  final VoidCallback? onSearchSubmitted;

  const HomeHeader({
    super.key,
    this.searchController,
    this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Hamburger Menu + Logo + Profile Icon (Mobile App Style)
          Row(
            children: [
              // Hamburger Menu Icon
              Builder(
                builder: (context) => IconButton(
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  icon: Icon(
                    Icons.menu,
                    color: colorScheme.onSurface,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Logo (IQ BidMaster text + icon)
              GestureDetector(
                onTap: () {
                  context.go('/home');
                },
                child: Row(
                  children: [
                    // Logo icon placeholder - replace with actual logo asset
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.gavel,
                        color: colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'IQ BidMaster',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Notifications icon
              IconButton(
                onPressed: () {
                  context.push('/notifications');
                },
                icon: Icon(
                  Icons.notifications_outlined,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              
              const SizedBox(width: 8),
              
              // Profile icon
              IconButton(
                onPressed: () {
                  context.push('/profile');
                },
                icon: Icon(
                  Icons.person_outline,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          // Bottom Row: Search Box
          const SizedBox(height: 12),
          _SearchBox(
            controller: searchController,
            onSearchSubmitted: onSearchSubmitted,
          ),
        ],
      ),
    );
  }
}

// Search Box Widget
class _SearchBox extends StatefulWidget {
  final TextEditingController? controller;
  final VoidCallback? onSearchSubmitted;

  const _SearchBox({
    this.controller,
    this.onSearchSubmitted,
  });

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    widget.controller?.clear();
                    widget.onSearchSubmitted?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface,
        ),
        onSubmitted: (value) {
          widget.onSearchSubmitted?.call();
        },
      ),
    );
  }
}

