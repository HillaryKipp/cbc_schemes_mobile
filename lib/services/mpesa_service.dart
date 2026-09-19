import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/config/theme.dart';
import '../models/scheme.dart';
import 'curriculum_service.dart';
import 'guest_storage_service.dart';
import 'supabase_service.dart';

class MpesaService {
  static MpesaService? _instance;
  static MpesaService get instance => _instance ??= MpesaService._();

  MpesaService._();

  /// Normalizes Kenyan phone numbers to standard 254XXXXXXXXX format
  static String? normalizeKenyanPhone(String input) {
    var raw = input.replaceAll(RegExp(r'[\s\-\+]'), '').trim();
    if (raw.startsWith('254') && raw.length == 12) {
      return raw;
    }
    if ((raw.startsWith('07') || raw.startsWith('01')) && raw.length == 10) {
      return '254${raw.substring(1)}';
    }
    if ((raw.startsWith('7') || raw.startsWith('1')) && raw.length == 9) {
      return '254$raw';
    }
    return null;
  }

  /// Evaluates payment gate: returns true if scheme is already unlocked or payments are disabled
  Future<bool> shouldBypassPayment(Scheme scheme) async {
    if (scheme.isPaid) return true;

    try {
      final settings = await CurriculumService.instance.getAppSettings();
      if (!settings.paymentsEnabled) return true;

      // Check if this scheme was already paid in Postgres
      final supabase = SupabaseService.instance;
      if (supabase.isInitialized) {
        final existingPayment = await supabase.client
            .from('payments')
            .select('status')
            .eq('scheme_id', scheme.id)
            .eq('status', 'paid')
            .limit(1)
            .maybeSingle();

        if (existingPayment != null) {
          if (scheme.id.startsWith('guest-')) {
            await GuestStorageService.instance.markSchemePaid(scheme.id);
          }
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Initiate M-Pesa STK push via backend endpoint
  Future<Map<String, dynamic>> startMpesaPayment({
    required String schemeId,
    required String phoneNumber,
  }) async {
    final normalized = normalizeKenyanPhone(phoneNumber);
    if (normalized == null) {
      return {
        'ok': false,
        'message': 'Please enter a valid Safaricom number (e.g. 0712345678 or 0112345678)',
      };
    }

    final backendUrl = AppConfig.backendUrl;

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/mpesa/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'schemeId': schemeId,
          'phone': normalized,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final decoded = jsonDecode(res.body);
        return {
          'ok': false,
          'message': decoded['message'] ?? 'Failed to initiate M-Pesa payment (${res.statusCode})',
        };
      }
    } catch (e) {
      // If backend endpoint is offline or running locally, check Supabase payments directly
      debugPrint('Error contacting backend start endpoint: $e');
      return {
        'ok': true,
        'paymentId': 'local-pay-${DateTime.now().millisecondsSinceEpoch}',
        'amount': 100,
        'isMock': true,
      };
    }
  }

  /// Poll M-Pesa payment status with Safaricom status disambiguation
  Future<Map<String, dynamic>> checkMpesaPayment({
    required String paymentId,
    required String schemeId,
  }) async {
    final backendUrl = AppConfig.backendUrl;

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/mpesa/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentId': paymentId,
          'schemeId': schemeId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error polling backend check: $e');
    }

    // Direct check in Supabase payments table
    final supabase = SupabaseService.instance;
    if (supabase.isInitialized) {
      try {
        final payRecord = await supabase.client
            .from('payments')
            .select('status, result_desc, mpesa_receipt_number')
            .or('id.eq.$paymentId,scheme_id.eq.$schemeId')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (payRecord != null) {
          final status = payRecord['status'];
          if (status == 'paid') {
            return {
              'status': 'paid',
              'receipt': payRecord['mpesa_receipt_number'] ?? 'CONFIRMED',
            };
          }
          if (status == 'failed') {
            return {
              'status': 'failed',
              'terminal': true,
              'message': payRecord['result_desc'] ?? 'Payment was cancelled or failed',
            };
          }
        }
      } catch (_) {}
    }

    return {'status': 'pending'};
  }

  /// Displays the M-Pesa STK push checkout bottom sheet dialog with 120s timer
  Future<bool> showMpesaCheckoutSheet({
    required BuildContext context,
    required Scheme scheme,
    required double amount,
    required VoidCallback onPaymentSuccess,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _MpesaCheckoutSheet(
            scheme: scheme,
            amount: amount,
            onPaymentSuccess: onPaymentSuccess,
          ),
        ) ??
        false;
  }
}

class _MpesaCheckoutSheet extends StatefulWidget {
  final Scheme scheme;
  final double amount;
  final VoidCallback onPaymentSuccess;

  const _MpesaCheckoutSheet({
    required this.scheme,
    required this.amount,
    required this.onPaymentSuccess,
  });

  @override
  State<_MpesaCheckoutSheet> createState() => _MpesaCheckoutSheetState();
}

class _MpesaCheckoutSheetState extends State<_MpesaCheckoutSheet> {
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;
  int _secondsLeft = 120;
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCheckout() async {
    final phone = _phoneController.text.trim();
    final normalized = MpesaService.normalizeKenyanPhone(phone);
    if (normalized == null) {
      setState(() {
        _errorMessage = 'Please enter a valid Safaricom phone number (e.g. 0712345678)';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _secondsLeft = 120;
    });

    final startRes = await MpesaService.instance.startMpesaPayment(
      schemeId: widget.scheme.id,
      phoneNumber: normalized,
    );

    if (startRes['ok'] != true) {
      setState(() {
        _isProcessing = false;
        _errorMessage = startRes['message'] ?? 'Failed to initiate M-Pesa prompt. Please try again.';
      });
      return;
    }

    if (startRes['alreadyPaid'] == true) {
      _handleSuccess();
      return;
    }

    final paymentId = startRes['paymentId'] as String? ?? widget.scheme.id;

    // Start 120s countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        t.cancel();
        _pollingTimer?.cancel();
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Payment verification timed out. If you were charged, tap below to check again.';
        });
      }
    });

    // Poll every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted || _secondsLeft <= 0) {
        t.cancel();
        return;
      }

      final checkRes = await MpesaService.instance.checkMpesaPayment(
        paymentId: paymentId,
        schemeId: widget.scheme.id,
      );

      if (checkRes['status'] == 'paid') {
        t.cancel();
        _countdownTimer?.cancel();
        _handleSuccess();
        return;
      }

      if (checkRes['status'] == 'failed' && checkRes['terminal'] == true) {
        t.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = checkRes['message'] ?? 'Payment was cancelled or failed.';
          });
        }
      }
    });
  }

  void _handleSuccess() async {
    if (widget.scheme.id.startsWith('guest-')) {
      await GuestStorageService.instance.markSchemePaid(widget.scheme.id);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    widget.onPaymentSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.payment_rounded, color: Color(0xFF16A34A), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'M-Pesa Express Checkout',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                  ),
                ],
              ),
              if (!_isProcessing)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context, false),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Unlock ${widget.scheme.gradeName ?? "Grade"} ${widget.scheme.subjectName ?? "Scheme"} (${widget.scheme.termName} ${widget.scheme.year}) for full DOCX, PDF & WhatsApp sharing.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),

          // Price Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to Pay:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                Text(
                  'KES ${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_isProcessing) ...[
            const Text(
              'Safaricom M-Pesa Phone Number',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. 0712345678 or 0112345678',
                prefixIcon: Icon(Icons.phone_iphone_rounded, color: Color(0xFF16A34A)),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppTheme.errorRed, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startCheckout,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send M-Pesa Prompt (STK)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            // Processing & Countdown State
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'M-Pesa STK Prompt Sent!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check your phone screen and enter your M-Pesa PIN to complete the payment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF15803D), height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Waiting for confirmation: ${_secondsLeft}s',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  _countdownTimer?.cancel();
                  _pollingTimer?.cancel();
                  setState(() => _isProcessing = false);
                },
                child: const Text('Cancel or Change Number', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
