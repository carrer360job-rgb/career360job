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

  Future<void> _buyPaidPlan(Map<String, dynamic> plan, bool ready) async {
    if (!widget.profile.isApproved) {
      _message('Company approval is required before buying a plan.');
      return;
    }
    if (!ready) {
      _message('Online payment is unavailable right now. Please try again later.');
      return;
    }
    if (widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current subscription?'),
          content: const Text(
            'The new plan starts after payment. Unused posts and the remaining time on your current plan will not carry over.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep current plan')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue to payment')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
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
          title: const Text('Subscription active', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Your job post quota is ready. You can now publish jobs and manage applicants.'),
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
    final orderId = _expectedOrderId;
    _expectedOrderId = null;
    if (orderId != null) {
      _api.markPaymentFailed(orderId, response.code?.toString() ?? 'payment_not_completed')
          .catchError((_) {});
    }
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
              if (plan['gstDisplay'] != null && (plan['gstDisplay'] as String).trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  plan['gstDisplay'],
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Choose your plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
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
              final isFree = (plan['amountPaise'] as num? ?? 0) <= 0 ||
                  plan['tier'] == 'free';
              final planNumber = index + 1;
              final isCurrent = widget.profile.activePlan == plan['id'] &&
                  widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true;
              final paidTermActive = widget.profile.planTier.isNotEmpty &&
                  widget.profile.planTier != 'free' &&
                  widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true;

              return Card(
                elevation: isExpanded ? 2 : 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isExpanded ? AppTheme.primaryLightBorder : const Color(0xFFE2E8F0),
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
                      // Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isExpanded ? AppTheme.primaryLight : Colors.white,
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
                                color: AppTheme.primary,
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
                                  color: AppTheme.textPrimary,
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
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primaryLightBorder),
                                ),
                                child: const Text(
                                  'ACTIVE PLAN',
                                  style: TextStyle(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppTheme.primary,
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
                              if (plan['gstDisplay'] != null && (plan['gstDisplay'] as String).trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '${plan['gstDisplay']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),

                              // Tree Specification breakdown (matching Nithra design)
                              _buildSpecTree(plan),

                              const SizedBox(height: 20),

                              // Plan details and checkout actions.
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

                                  // Emerald Action Button
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _busy || isFree
                                          ? null
                                          : () => _buyPaidPlan(plan, ready),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text(
                                        _busy
                                            ? 'Processing...'
                                            : isFree
                                                    ? 'Unavailable'
                                                    : paidTermActive
                                                        ? isCurrent ? 'Renew plan' : 'Change plan'
                                                        : 'Pay now',
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
      'Job listing: up to $listingDays days (ends with plan)',
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
