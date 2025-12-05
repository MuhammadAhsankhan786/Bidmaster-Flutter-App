import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _walletData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiService.getWallet();
      if (response['success'] == true) {
        setState(() {
          _walletData = response['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load wallet data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Wallet] Error loading wallet data: $e');
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getTransactionTypeColor(String type) {
    switch (type) {
      case 'referral':
        return AppColors.green600;
      case 'sale':
        return AppColors.blue600;
      default:
        return AppColors.slate600;
    }
  }

  IconData _getTransactionTypeIcon(String type) {
    switch (type) {
      case 'referral':
        return Icons.people;
      case 'sale':
        return Icons.shopping_bag;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Wallet'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
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
                        onPressed: _loadWalletData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _walletData == null
                  ? const Center(child: Text('No wallet data'))
                  : RefreshIndicator(
                      onRefresh: _loadWalletData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Total Balance Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.blue600, AppColors.blue700],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Total Balance',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: AppColors.cardWhite,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${_formatCurrency(_walletData!['total_balance'] ?? 0.0)}',
                                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                          color: AppColors.cardWhite,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _BalanceItem(
                                        label: 'Referral',
                                        amount: _walletData!['breakdown']?['referral_rewards'] ?? 0.0,
                                        color: AppColors.green500,
                                      ),
                                      _BalanceItem(
                                        label: 'Earnings',
                                        amount: _walletData!['breakdown']?['seller_earnings'] ?? 0.0,
                                        color: AppColors.yellow500,
                                      ),
                                      if ((_walletData!['breakdown']?['pending_earnings'] ?? 0.0) > 0)
                                        _BalanceItem(
                                          label: 'Pending',
                                          amount: _walletData!['breakdown']?['pending_earnings'] ?? 0.0,
                                          color: AppColors.yellow600,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Transaction History
                            Text(
                              'Transaction History',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),

                            if ((_walletData!['transactions'] as List?)?.isEmpty ?? true)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.history, size: 64, color: AppColors.slate400),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No transactions yet',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...((_walletData!['transactions'] as List?) ?? []).map((transaction) {
                                final type = transaction['transaction_type'] ?? 'unknown';
                                final amount = (transaction['amount'] ?? 0.0).toDouble();
                                final date = transaction['transaction_date'] ?? '';
                                final status = transaction['status'] ?? 'completed';
                                final description = transaction['title'] ?? transaction['description'] ?? 'Transaction';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getTransactionTypeColor(type).withOpacity(0.2),
                                      child: Icon(
                                        _getTransactionTypeIcon(type),
                                        color: _getTransactionTypeColor(type),
                                      ),
                                    ),
                                    title: Text(
                                      description,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(_formatDate(date)),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${_formatCurrency(amount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _getTransactionTypeColor(type),
                                          ),
                                        ),
                                        if (status != 'awarded' && status != 'completed')
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.yellow100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.yellow700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BalanceItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.cardWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.cardWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


