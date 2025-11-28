import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';
import '../models/bid_model.dart';

class BuyerBiddingHistoryScreen extends StatefulWidget {
  const BuyerBiddingHistoryScreen({super.key});

  @override
  State<BuyerBiddingHistoryScreen> createState() => _BuyerBiddingHistoryScreenState();
}

class _BuyerBiddingHistoryScreenState extends State<BuyerBiddingHistoryScreen> {
  List<Map<String, dynamic>> _bids = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedStatus;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadBiddingHistory();
  }

  Future<void> _loadBiddingHistory({bool loadMore = false}) async {
    if (_isLoading && !loadMore) return;

    setState(() {
      if (!loadMore) {
        _isLoading = true;
        _currentPage = 1;
        _bids = [];
        _hasMore = true;
      }
      _errorMessage = null;
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final response = await apiService.getBuyerBiddingHistory(
        status: _selectedStatus,
        page: page,
        limit: 20,
      );

      if (response['success'] == true) {
        final newBids = ((response['data'] as List?) ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final analytics = response['analytics'] as Map<String, dynamic>?;
        final pagination = response['pagination'] as Map<String, dynamic>?;

        setState(() {
          if (loadMore) {
            _bids.addAll(newBids);
            _currentPage = page;
          } else {
            _bids = newBids;
            _currentPage = 1;
            _analytics = analytics;
          }
          _hasMore = pagination != null && page < (pagination['pages'] ?? 1);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load bidding history';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onStatusFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadBiddingHistory();
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'won':
        return AppColors.green600;
      case 'active':
        return AppColors.blue600;
      case 'lost':
        return AppColors.red600;
      default:
        return AppColors.slate600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'won':
        return Icons.check_circle;
      case 'active':
        return Icons.access_time;
      case 'lost':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Bids'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Analytics Cards
          if (_analytics != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Bids',
                      value: '${_analytics!['total_bids'] ?? 0}',
                      color: AppColors.blue600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Total Amount',
                      value: '\$${_formatCurrency((_analytics!['total_amount_bid'] ?? 0.0).toDouble())}',
                      color: AppColors.green600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Win Rate',
                      value: '${_analytics!['win_rate'] ?? 0}%',
                      color: AppColors.yellow600,
                    ),
                  ),
                ],
              ),
            ),

          // Status Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedStatus == null,
                    onSelected: () => _onStatusFilterChanged(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Active',
                    isSelected: _selectedStatus == 'active',
                    onSelected: () => _onStatusFilterChanged('active'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Won',
                    isSelected: _selectedStatus == 'won',
                    onSelected: () => _onStatusFilterChanged('won'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Lost',
                    isSelected: _selectedStatus == 'lost',
                    onSelected: () => _onStatusFilterChanged('lost'),
                  ),
                ],
              ),
            ),
          ),

          // Bids List
          Expanded(
            child: _isLoading && _bids.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _bids.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadBiddingHistory(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _bids.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.gavel, size: 64, color: AppColors.slate400),
                                const SizedBox(height: 16),
                                Text(
                                  'No bids yet',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start bidding on products to see your history here',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadBiddingHistory(),
                            child: ListView.builder(
                              itemCount: _bids.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _bids.length) {
                                  if (!_isLoading) {
                                    _loadBiddingHistory(loadMore: true);
                                  }
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final bid = _bids[index];
                                final status = bid['bid_status'] ?? 'unknown';
                                final productTitle = bid['product_title'] ?? 'Unknown Product';
                                final amount = (bid['amount'] ?? 0.0).toDouble();
                                final bidDate = bid['bid_date'] != null
                                    ? DateTime.parse(bid['bid_date'])
                                    : DateTime.now();
                                final productId = bid['product_id'];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                                      child: Icon(
                                        _getStatusIcon(status),
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    title: Text(
                                      productTitle,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_formatDate(bidDate)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _getStatusColor(status),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${_formatCurrency(amount)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: productId != null
                                        ? () {
                                            context.go('/product-details/$productId');
                                          }
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.blue600,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

