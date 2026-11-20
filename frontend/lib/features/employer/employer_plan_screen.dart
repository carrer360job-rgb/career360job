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
  String? _processingPlanId;

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
    if (_busy) return;
    if (!widget.profile.isApproved) {
      _message('Company approval is required before buying a plan.');
      return;
    }
    if (!ready) {
      _message(
        'Online payment is unavailable right now. Please try again later.',
      );
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current plan'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue to payment'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _processingPlanId = plan['id'] as String?;
    });
    try {
      final order = await _api.createOrder(
        plan['id'] as String,
        plan['version'] as int,
      );
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
        'theme': {'color': '#16A34A'},
      });
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
      if (mounted) {
        setState(() {
          _busy = false;
          _processingPlanId = null;
        });
      }
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    final id = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (id == null ||
        id != _expectedOrderId ||
        paymentId == null ||
        signature == null) {
      _message('Payment is being confirmed. Check your dashboard shortly.');
      if (mounted) {
        setState(() {
          _busy = false;
          _processingPlanId = null;
        });
      }
      return;
    }
    try {
      await _api.verifyPayment(id, paymentId, signature);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.verified_rounded,
            color: AppTheme.success,
            size: 54,
          ),
          title: const Text(
            'Subscription active',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your job post quota is ready. You can now publish jobs and manage applicants.',
          ),
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
      _message(
        'Payment verification note: ${error.toString().replaceFirst('Bad state: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _processingPlanId = null;
        });
      }
    }
  }

  void _onFailure(PaymentFailureResponse response) {
    final orderId = _expectedOrderId;
    _expectedOrderId = null;
    if (orderId != null) {
      _api
          .markPaymentFailed(
            orderId,
            response.code?.toString() ?? 'payment_not_completed',
          )
          .catchError((_) {});
    }
    _message(response.message ?? 'Payment was not completed.');
    if (mounted) {
      setState(() {
        _busy = false;
        _processingPlanId = null;
      });
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _message(
      'Continue in ${response.walletName ?? 'your wallet'} to complete payment.',
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(num paise) {
    final amount = (paise / 100).toStringAsFixed(2);
    final parts = amount.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '₹${buffer.toString()}${parts.last == '00' ? '' : '.${parts.last}'}';
  }

  Widget _metric(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.primaryLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.primaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _planCard(Map<String, dynamic> plan, bool ready, bool recommended) {
    final id = plan['id'] as String? ?? '';
    final totalPaise = (plan['amountPaise'] as num?) ?? 0;
    final basePaise = (plan['basePaise'] as num?) ?? totalPaise;
    final taxPaise = (plan['taxPaise'] as num?) ?? 0;
    final taxMode = plan['taxMode'] as String? ?? 'inclusive';
    final rate = ((plan['taxRateBps'] as num?) ?? 0) / 100;
    final jobs = (plan['jobCredits'] as num?)?.toInt() ?? 0;
    final unlocks = (plan['profileUnlockLimit'] as num?)?.toInt() ?? 0;
    final duration = (plan['creditValidityDays'] as num?)?.toInt() ?? 0;
    final reach = plan['reach'] == 'statewide' ? 'Tamil Nadu' : 'District';
    final name = (plan['name'] as String? ?? 'Hiring plan').trim();
    final features =
        (plan['features'] as List?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        <String>[];
    final current =
        widget.profile.activePlan == id &&
        widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true;
    final active =
        widget.profile.creditsExpireAt?.isAfter(DateTime.now()) == true &&
        widget.profile.planTier.isNotEmpty &&
        widget.profile.planTier != 'free';
    final processing = _busy && _processingPlanId == id;
    final isFree = totalPaise <= 0 || plan['tier'] == 'free';
    final canBuy =
        !_busy && !isFree && ready && id.isNotEmpty && plan['version'] is int;
    final listedPrice = taxMode == 'exclusive' ? basePaise : totalPaise;
    final taxLine = taxPaise <= 0
        ? 'No GST • $duration days'
        : taxMode == 'exclusive'
        ? '+ ${rate.toStringAsFixed(0)}% GST (${_money(taxPaise)}) • ${_money(totalPaise)} total • $duration days'
        : 'Includes ${rate.toStringAsFixed(0)}% GST (${_money(taxPaise)}) • $duration days';
    final details = <String>[
      '$jobs job ${jobs == 1 ? 'post' : 'posts'} during this plan',
      'Each job may stay live for up to ${plan['listingDays'] ?? duration} days (ends with plan)',
      '$unlocks candidate profile ${unlocks == 1 ? 'unlock' : 'unlocks'}',
      reach == 'District'
          ? 'One district per job'
          : 'Visibility across Tamil Nadu',
      ...features.where(
        (feature) => !RegExp(
          r'^\d+ (job posts?|profile unlocks?)$',
          caseSensitive: false,
        ).hasMatch(feature),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recommended ? AppTheme.primary : AppTheme.border,
          width: recommended ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B172B40),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommended)
            Container(
              width: double.infinity,
              color: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _money(listedPrice),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  taxLine,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (current) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '✓ CURRENTLY ACTIVE • ${widget.profile.daysRemaining} days remaining',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 17),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _metric('$jobs Job Posts'),
                    _metric('$unlocks Unlocks'),
                    _metric(reach),
                  ],
                ),
                const SizedBox(height: 17),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 17),
                ...details.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            detail,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: canBuy ? () => _buyPaidPlan(plan, ready) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: recommended
                          ? AppTheme.primary
                          : AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.border,
                      disabledForegroundColor: AppTheme.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      processing
                          ? 'Preparing checkout…'
                          : !ready
                          ? 'Checkout unavailable'
                          : isFree
                          ? 'Unavailable'
                          : current
                          ? 'Renew for ${_money(totalPaise)} →'
                          : active
                          ? 'Change plan for ${_money(totalPaise)} →'
                          : 'Subscribe for ${_money(totalPaise)} →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Choose your hiring plan')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _planRequest,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load plans. Check your connection and try again.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _planRequest = _api.plans()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final plansRaw = data['plans'];
          final plans = plansRaw is List
              ? plansRaw
                    .whereType<Map>()
                    .map((entry) => entry.cast<String, dynamic>())
                    .toList()
              : <Map<String, dynamic>>[];
          if (plans.isEmpty) {
            return const Center(
              child: Text('Plans are being prepared. Please check back soon.'),
            );
          }
          final ready = data['checkoutReady'] == true;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              const Text(
                'Compare plans',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'See the full price, posting allowance and candidate access before you pay.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              ...plans.map(
                (plan) => _planCard(plan, ready, plan['id'] == 'quarterly'),
              ),
              const SizedBox(height: 3),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Secure checkout via Razorpay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
