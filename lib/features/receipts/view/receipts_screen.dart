import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hlvm_mobileapp/features/receipts/view/view.dart';
import 'package:hlvm_mobileapp/services/api.dart';
import 'package:intl/intl.dart';
import 'package:hlvm_mobileapp/features/auth/view/settings_screen.dart';
import 'package:hlvm_mobileapp/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hlvm_mobileapp/features/receipts/bloc/receipt_bloc.dart';
import 'package:hlvm_mobileapp/features/receipts/bloc/receipt_event.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _receiptsWithSellers = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppStyles.defaultAnimationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fetchReceipt();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchReceipt() async {
    try {
      final receipts = await _apiService.listReceipt();
      List<Map<String, dynamic>> receiptsData = [];

      for (var receipt in receipts) {
        if (!mounted) return; // Проверяем, что виджет все еще в дереве

        final seller = await _apiService.getSeller(receipt['seller']);
        if (!mounted) return; // Проверяем после каждого await

        receiptsData.add({
          'receipt': receipt,
          'seller': seller,
        });
      }

      if (mounted) {
        setState(() {
          _receiptsWithSellers = receiptsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;

      final errorMsg = e.toString();
      if (errorMsg.contains('Необходимо указать адрес сервера')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Необходимо указать адрес сервера в настройках'),
              action: SnackBarAction(
                label: 'Настроить',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка загрузки данных: $e')));
        }
      }
    }
  }

  void _showReceiptDetailsDialog(
      BuildContext context, Map<String, dynamic> receipt, String seller) {
    final totalSum = receipt['total_sum'];

    // Получаем данные о продуктах
    final products = receipt['product'] as List<dynamic>? ?? [];

    // Создаем список продуктов
    final productList = products.map((product) {
      final productName = product['product_name'] ?? 'Неизвестный продукт';
      final quantity = product['quantity'] ?? 1;
      final price = product['price'] ?? 0.0;
      final sum = product['amount'] ?? 0.0;

      return _buildDetailItem(
        icon: Icons.shopping_cart,
        label: productName,
        value: '$quantity x $price ₽ = $sum ₽',
        isAmount: true,
      );
    }).toList();

    final dateString = receipt['receipt_date'];
    DateTime dateTime = DateTime.parse(dateString);
    String formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(dateTime);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen// ignore: deprecated_member_use
                  .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  seller,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailItem(
                  icon: Icons.calendar_today,
                  label: 'Дата',
                  value: formattedDate,
                ),
                _buildDetailItem(
                  icon: Icons.attach_money,
                  label: 'Сумма чека',
                  value: '$totalSum ₽',
                  isAmount: true,
                ),
                if (receipt['number_receipt'] != null)
                  _buildDetailItem(
                    icon: Icons.numbers,
                    label: 'Номер ФД',
                    value: receipt['number_receipt'].toString(),
                  ),
                if (receipt['nds10'] != null &&
                    (receipt['nds10'] is num
                        ? receipt['nds10'] > 0
                        : (double.tryParse(receipt['nds10'].toString()) ?? 0) >
                            0))
                  _buildDetailItem(
                    icon: Icons.receipt,
                    label: 'НДС 10%',
                    value: '${receipt['nds10']} ₽',
                  ),
                if (receipt['nds20'] != null &&
                    (receipt['nds20'] is num
                        ? receipt['nds20'] > 0
                        : (double.tryParse(receipt['nds20'].toString()) ?? 0) >
                            0))
                  _buildDetailItem(
                    icon: Icons.receipt,
                    label: 'НДС 20%',
                    value: '${receipt['nds20']} ₽',
                  ),
                if (receipt['product'] != null &&
                    receipt['product'].isNotEmpty) ...[
                  _buildDetailItem(
                    icon: Icons.inventory,
                    label: 'Товары',
                    value: '${receipt['product'].length} позиций',
                  ),
                  ...productList,
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    bool isAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen// ignore: deprecated_member_use
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
                    color:
                        isAmount ? AppTheme.primaryGreen : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Мои чеки'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchReceipt,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingScreen() : _buildReceiptsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ImageCaptureScreen(),
              ),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка при открытии экрана: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Добавить чек'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen// ignore: deprecated_member_use
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 40,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Загружаем чеки...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList() {
    if (_receiptsWithSellers.isEmpty) {
      return _buildEmptyState();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _fetchReceipt,
            color: AppTheme.primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _receiptsWithSellers.length,
              itemBuilder: (context, index) {
                final receiptData = _receiptsWithSellers[index];
                final receipt = receiptData['receipt'];
                final seller = receiptData['seller']['name_seller'] ??
                    'Неизвестный продавец';

                return _buildReceiptCard(receipt, seller, index);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen// ignore: deprecated_member_use
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 60,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Чеков пока нет',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте первый чек, чтобы начать вести учет',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ImageCaptureScreen(),
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при открытии экрана: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

                void _showDeleteConfirmationDialog(
                    BuildContext context, int receiptId) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text('Удалить чек?'),
                          ],
                        ),
                        content: const Text(
                          'Вы уверены, что хотите удалить этот чек? Это действие нельзя отменить.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Отмена'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              // Отправляем событие удаления в BLoC
                              context
                                  .read<ReceiptBloc>()
                                  .add(DeleteReceipt(receiptId: receiptId));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Удалить'),
                          ),
                        ],
                      );
                    },
                  );
                }
}
            },
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Добавить чек'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(
      Map<String, dynamic> receipt, String seller, int index) {
    final totalSum = receipt['total_sum'];
    final dateString = receipt['receipt_date'];
    DateTime dateTime = DateTime.parse(dateString);
    String formattedDate = DateFormat('dd.MM.yyyy').format(dateTime);
    String formattedTime = DateFormat('HH:mm').format(dateTime);

    // Анимация появления карточек
    final animationDelay = Duration(milliseconds: index * 100);

    return TweenAnimationBuilder<double>(
      duration: AppStyles.defaultAnimationDuration + animationDelay,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showReceiptDetailsDialog(context, receipt, seller),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppStyles.balanceCardGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seller,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formattedTime,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$totalSum ₽',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _showDeleteConfirmationDialog(
                                    context, receipt['id']),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Удалить чек',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryGreen// ignore: deprecated_member_use
                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Чек',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.dividerColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.touch_app,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Нажмите для подробностей',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.dividerColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, int receiptId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 24,
              ),
              SizedBox(width: 8),
              Text('Удалить чек?'),
            ],
          ),
          content: const Text(
            'Вы уверены, что хотите удалить этот чек? Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Отправляем событие удаления в BLoC
                context
                    .read<ReceiptBloc>()
                    .add(DeleteReceipt(receiptId: receiptId));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }
}
