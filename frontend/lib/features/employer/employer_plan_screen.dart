import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/services/employer_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/employer_profile.dart';

class EmployerPlanScreen extends StatefulWidget {
  final EmployerProfile profile;
  const EmployerPlanScreen({super.key, required this.profile});

  @override
  State<EmployerPlanScreen> createState() => _EmployerPlanScreenState();
}

class _EmployerPlanScreenState extends State<EmployerPlanScreen> {
  final _api = EmployerApiService();
  final _razorpay = Razorpay();
  late Future<Map<String, dynamic>> _planRequest;
  bool _busy = false;
  String? _expectedOrderId;
  int _expandedIndex = 0; // Default open first plan

  @override
  void initState() {
    super.initState();
    _planRequest = _api.plans();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _activateFreePlan(Map<String, dynamic> plan) async {
    if (!widget.profile.isApproved) {
      _message('Company approval is required before activating plans.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.createOrder(plan['id'] as String, plan['version'] as int);
      if (!mounted) return;
      final msg = res['message'] ?? 'Free Starter Plan activated! 1 free posting credit added.';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 54),
          title: const Text('Plan Activated!', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(msg.toString(), textAlign: TextAlign.center),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Start Hiring'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyPaidPlan(Map<String, dynamic> plan, bool ready) async {
    if (!widget.profile.isApproved) {
      _message('Company approval is required before buying a plan.');
      return;
    }
    if (!ready) {
      _message('Online payment is unavailable right now. Please try again later.');
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await _api.createOrder(plan['id'] as String, plan['version'] as int);
      if (!mounted) return;
      final id = order['orderId'];
      final key = order['keyId'];
      final amount = order['amountPaise'];
      if (id is! String || key is! String || amount is! int) {
        throw StateError('The payment order is incomplete.');
      }
      _expectedOrderId = id;
      _razorpay.open({
        'key': key,
        'order_id': id,
        'amount': amount,
        'currency': 'INR',
        'name': 'Career360',
        'description': '${plan['name']} - Hiring plan',
        'prefill': {
          'email': widget.profile.email,
          if (widget.profile.phone.isNotEmpty) 'contact': widget.profile.phone,
        },
        'theme': {'color': '#155EEF'},
      });
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    final id = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (id == null || id != _expectedOrderId || paymentId == null || signature == null) {
      _message('Payment is being confirmed. Check your dashboard shortly.');
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await _api.verifyPayment(id, paymentId, signature);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.verified_rounded, color: AppTheme.success, size: 54),
          title: const Text('Payment Successful!', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Your posting plan is now active. You can now publish jobs and receive candidate direct calls & WhatsApp inquiries.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message('Payment verification note: ${error.toString().replaceFirst('Bad state: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onFailure(PaymentFailureResponse response) {
    _message(response.message ?? 'Payment was not completed.');
    if (mounted) setState(() => _busy = false);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _message('Continue in ${response.walletName ?? 'your wallet'} to complete payment.');
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFeaturesModal(Map<String, dynamic> plan) {
    final features = (plan['features'] as List?)?.cast<String>() ?? [];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan['name'] ?? 'Plan Features',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    plan['priceDisplay'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                plan['gstDisplay'] ?? '',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompareModal(List<Map<String, dynamic>> plans) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => SafeArea(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Plan Comparison',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Direct candidate contact (WhatsApp, Call, Email) is enabled across all plans.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  columns: const [
                    DataColumn(label: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Free Starter', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Starter - 15', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Premium - 30', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Elite All-TN', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: const [
                    DataRow(cells: [
                      DataCell(Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('₹0 (Free)')),
                      DataCell(Text('₹2,360')),
                      DataCell(Text('₹3,750')),
                      DataCell(Text('₹20,000')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Job Count')),
                      DataCell(Text('1 Job')),
                      DataCell(Text('1 Job')),
                      DataCell(Text('1 Job')),
                      DataCell(Text('1 Job')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Location Reach')),
                      DataCell(Text('1 Local District')),
                      DataCell(Text('1 District')),
                      DataCell(Text('1 District')),
                      DataCell(Text('All 39 Districts (TN)')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Listing Validity')),
                      DataCell(Text('7 Days')),
                      DataCell(Text('15 Days')),
                      DataCell(Text('30 Days')),
                      DataCell(Text('30 Days')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Candidate Phone Calls')),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Direct WhatsApp Chat')),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Direct Email Inquiries')),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                      DataCell(Icon(Icons.check, color: AppTheme.success, size: 18)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Featured Highlight')),
                      DataCell(Text('Standard')),
                      DataCell(Text('Standard')),
                      DataCell(Text('Featured Badge', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                      DataCell(Text('Statewide Blast', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Choose your plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _planRequest,
              builder: (context, snapshot) {
                final plansRaw = snapshot.data?['plans'];
                final List<Map<String, dynamic>> plans = plansRaw is List
                    ? plansRaw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
                    : [];
                return TextButton(
                  onPressed: plans.isEmpty ? null : () => _showCompareModal(plans),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626), // Nithra Red button
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: const Text(
                    'Compare plan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _planRequest,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Could not load plans. Check your connection and try again.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => setState(() => _planRequest = _api.plans()),
                  child: const Text('Retry')),
              ]),
            ));
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final plansRaw = data['plans'];
          final List<Map<String, dynamic>> plans = plansRaw is List
              ? plansRaw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
              : [];
          if (plans.isEmpty) return const Center(child: Text('Plans are being prepared. Please check back soon.'));
          final ready = data['checkoutReady'] != false;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isExpanded = _expandedIndex == index;
              final isFree = (plan['amountPaise'] as num? ?? 0) == 0;
              final planNumber = index + 1;
              final isCurrent = widget.profile.activePlan == plan['id'] &&
                  widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true;
              final freeUsed = isFree && widget.profile.activePlan == 'free_starter';
              final paidTermActive = widget.profile.planTier != 'free' &&
                  widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true;

              return Card(
                elevation: isExpanded ? 2 : 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isExpanded ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                    width: isExpanded ? 1.5 : 1,
                  ),
                ),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? -1 : index;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row (matching Nithra)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isExpanded ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(9),
                            bottom: Radius.circular(isExpanded ? 0 : 9),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Number Circle Badge
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$planNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Plan Name
                            Expanded(
                              child: Text(
                                plan['name'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF93C5FD)),
                                ),
                                child: const Text(
                                  'ACTIVE PLAN',
                                  style: TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (isFree)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: const Text(
                                  'FREE',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: const Color(0xFF2563EB),
                              size: 24,
                            ),
                          ],
                        ),
                      ),

                      // Expanded Body
                      if (isExpanded) ...[
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Price and Subtitle
                              Text(
                                '${plan['priceDisplay']}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${plan['gstDisplay']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Tree Specification breakdown (matching Nithra design)
                              _buildSpecTree(plan),

                              const SizedBox(height: 20),

                              // Bottom Buttons: "See Features" & "Pay Now" / "Activate Free Plan"
                              Row(
                                children: [
                                  // Yellow "See Features" Button
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _showFeaturesModal(plan),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF59E0B),
                                        foregroundColor: const Color(0xFF0F172A),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text(
                                        'See Features',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Blue Action Button
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _busy || isCurrent || freeUsed || paidTermActive
                                          ? null
                                          : () {
                                              if (isFree) {
                                                _activateFreePlan(plan);
                                              } else {
                                                _buyPaidPlan(plan, ready);
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text(
                                        _busy
                                            ? 'Processing…'
                                            : isCurrent
                                                ? 'Current plan'
                                                : freeUsed
                                                    ? 'Already used'
                                                    : paidTermActive
                                                        ? 'Renew after expiry'
                                            : isFree
                                                ? 'Activate Free'
                                                : 'Pay Now',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the custom tree widget matching Nithra app's layout
  Widget _buildSpecTree(Map<String, dynamic> plan) {
    final jobs = plan['jobCredits'] ?? 1;
    final locations = plan['locationsCovered'] ?? '1 / per job';
    final listingDays = plan['listingDays'] ?? 15;
    final planValidity = plan['creditValidityDays'] ?? 15;
    final unlocks = plan['profileUnlockLimit'] ?? 0;

    final items = [
      'Job Count : $jobs',
      'Location Count : $locations',
      'Job Validity : $listingDays days',
      'Plan Validity : $planValidity days',
      'Applicant profiles : $unlocks unlocks',
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: List.generate(items.length, (idx) {
          final isLast = idx == items.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tree branch graphics
                SizedBox(
                  width: 24,
                  child: CustomPaint(
                    painter: _TreeBranchPainter(isLast: isLast),
                  ),
                ),
                // Number block
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(bottom: 12, right: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Text label
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      items[idx],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Custom painter for the vertical tree hierarchy line
class _TreeBranchPainter extends CustomPainter {
  final bool isLast;
  _TreeBranchPainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const startX = 6.0;
    const branchY = 11.0;

    // Horizontal branch pointing to the square box
    canvas.drawLine(const Offset(startX, branchY), Offset(size.width, branchY), paint);

    // Vertical line connecting from top
    canvas.drawLine(const Offset(startX, 0), Offset(startX, isLast ? branchY : size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) =>
      oldDelegate.isLast != isLast;
}
