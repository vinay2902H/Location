import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import 'payment_brand_icon.dart';

class WithdrawalMethodInfo {
  final String id;
  final String name;
  final String subtitle;
  final String iconEmoji;
  final String? iconAsset;
  final Color primaryColor;
  final Color secondaryColor;
  final String numberHint;

  const WithdrawalMethodInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.iconEmoji,
    this.iconAsset,
    required this.primaryColor,
    required this.secondaryColor,
    required this.numberHint,
  });
}

class WithdrawalDialog extends StatefulWidget {
  final WithdrawalMethodInfo method;
  final RewardService rewardService;

  const WithdrawalDialog({
    super.key,
    required this.method,
    required this.rewardService,
  });

  static Future<bool?> show(
    BuildContext context, {
    required WithdrawalMethodInfo method,
    required RewardService rewardService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WithdrawalDialog(
        method: method,
        rewardService: rewardService,
      ),
    );
  }

  @override
  State<WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<WithdrawalDialog> {
  final TextEditingController _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  WithdrawalRecord? _completedRecord;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  String? _validateMobile(String? val) {
    if (val == null || val.trim().isEmpty) {
      return 'Please enter your 10-digit mobile number';
    }
    final clean = val.trim().replaceAll(' ', '');
    if (clean.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return 'Please enter a valid Indian mobile number (starts with 6-9)';
    }
    return null;
  }

  Future<void> _handleWithdraw() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = widget.rewardService.coinBalance;
    const requiredCoins = RewardService.withdrawalCoinsRequired;

    if (balance < requiredCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: WinzoColors.error,
          content: Text(
            'Insufficient coins! Need 1,00,000 (1L) coins to withdraw ₹25,000. You have $balance coins.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final cleanMobile = _mobileController.text.trim().replaceAll(' ', '');
    final success = await widget.rewardService.withdraw(
      method: widget.method.id,
      methodName: widget.method.name,
      mobileNumber: '+91 $cleanMobile',
      coins: RewardService.withdrawalCoinsRequired,
      amountInr: RewardService.withdrawalAmountInr,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (success) {
          _completedRecord = widget.rewardService.withdrawals.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final balance = widget.rewardService.coinBalance;
    const requiredCoins = RewardService.withdrawalCoinsRequired;
    const amountInr = RewardService.withdrawalAmountInr;
    final hasEnoughCoins = balance >= requiredCoins;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: screenHeight * 0.90,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: WinzoColors.bgDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(WinzoDimens.radiusXL)),
            border: Border(
              top: BorderSide(color: WinzoColors.borderPrimary, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 30,
                offset: Offset(0, -10),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            WinzoDimens.spaceLG,
            WinzoDimens.spaceMD,
            WinzoDimens.spaceLG,
            bottomInset + WinzoDimens.spaceLG,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _completedRecord != null
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildSuccessReceipt(_completedRecord!),
                  )
                : _buildWithdrawalForm(hasEnoughCoins, balance, requiredCoins, amountInr),
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalForm(
    bool hasEnoughCoins,
    int balance,
    int requiredCoins,
    int amountInr,
  ) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: WinzoColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: WinzoDimens.spaceMD),

            // Header Row
            Row(
              children: [
                PaymentBrandIcon.fromMethod(
                  method: widget.method,
                  size: 52,
                ),
                const SizedBox(width: WinzoDimens.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdraw to ${widget.method.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: WinzoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.method.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: WinzoColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: WinzoColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: WinzoDimens.spaceLG),

            // Amount & Coins Card
            Container(
              padding: const EdgeInsets.all(WinzoDimens.spaceMD),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.method.primaryColor.withAlpha(30),
                    WinzoColors.bgSurface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
                border: Border.all(
                  color: widget.method.primaryColor.withAlpha(80),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Withdrawal Cash',
                        style: TextStyle(fontSize: 13, color: WinzoColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: WinzoColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: WinzoColors.success.withAlpha(90)),
                        ),
                        child: const Text(
                          'Fixed Payout',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: WinzoColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹$amountInr',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: WinzoColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      Row(
                        children: [
                          const Text('🪙 ', style: TextStyle(fontSize: 16)),
                          Text(
                            '${(requiredCoins / 1000).toStringAsFixed(0)}K (1L) Coins',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: WinzoColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: WinzoColors.borderSubtle),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Current Balance:',
                        style: TextStyle(fontSize: 12, color: WinzoColors.textMuted),
                      ),
                      Text(
                        '$balance 🪙',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: hasEnoughCoins ? WinzoColors.success : WinzoColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: WinzoDimens.spaceMD),

            // Insufficient Balance Notice if balance < 100,000
            if (!hasEnoughCoins)
              Container(
                padding: const EdgeInsets.all(WinzoDimens.spaceMD),
                decoration: BoxDecoration(
                  color: WinzoColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  border: Border.all(color: WinzoColors.error.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: WinzoColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1L Coins Required for ₹25,000',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: WinzoColors.error,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You need 1,00,000 (1 Lakh) coins to withdraw ₹25,000. You need ${(requiredCoins - balance)} more coins. Watch daily ads & complete check-ins to reach your goal!',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: WinzoColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: WinzoColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  border: Border.all(color: WinzoColors.success.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: WinzoColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sufficient balance! You have enough coins for ₹25,000 withdrawal.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WinzoColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: WinzoDimens.spaceLG),

            // Mobile Number Input Section
            const Text(
              'Enter Mobile Number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: WinzoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.method.numberHint,
              style: const TextStyle(fontSize: 12, color: WinzoColors.textMuted),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: WinzoColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: WinzoColors.bgSurface,
                hintText: '98765 43210',
                hintStyle: TextStyle(
                  color: WinzoColors.textMuted.withAlpha(120),
                  letterSpacing: 1.5,
                  fontSize: 16,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇳', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 6),
                      Text(
                        '+91',
                        style: TextStyle(
                          color: WinzoColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        height: 20,
                        child: VerticalDivider(color: WinzoColors.borderSubtle),
                      ),
                    ],
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  borderSide: BorderSide(color: widget.method.primaryColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  borderSide: const BorderSide(color: WinzoColors.error),
                ),
              ),
              validator: _validateMobile,
            ),
            const SizedBox(height: WinzoDimens.spaceLG),

            // Submit Button
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: hasEnoughCoins ? widget.method.primaryColor : WinzoColors.bgElevated,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  ),
                  elevation: hasEnoughCoins ? 4 : 0,
                ),
                onPressed: _isSubmitting ? null : _handleWithdraw,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasEnoughCoins ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            size: 18,
                            color: hasEnoughCoins ? Colors.white : WinzoColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasEnoughCoins
                                ? 'Withdraw ₹$amountInr Now'
                                : 'Need 1L Coins (Short ${(requiredCoins - balance)})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: hasEnoughCoins ? Colors.white : WinzoColors.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: WinzoColors.textMuted),
                  SizedBox(width: 4),
                  Text(
                    'Direct UPI / Wallet credit within 24 hours',
                    style: TextStyle(fontSize: 11, color: WinzoColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessReceipt(WithdrawalRecord record) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: WinzoDimens.spaceMD),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WinzoColors.success.withAlpha(25),
              border: Border.all(color: WinzoColors.success, width: 2),
              boxShadow: [
                BoxShadow(
                  color: WinzoColors.success.withAlpha(80),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, size: 44, color: WinzoColors.success),
            ),
          ),
        ),
        const SizedBox(height: WinzoDimens.spaceLG),
        const Text(
          'Withdrawal Placed!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: WinzoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your payout request is being processed',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: WinzoColors.textMuted),
        ),
        const SizedBox(height: WinzoDimens.spaceXL),

        // Receipt Card
        Container(
          padding: const EdgeInsets.all(WinzoDimens.spaceMD),
          decoration: BoxDecoration(
            color: WinzoColors.bgSurface,
            borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
            border: Border.all(color: WinzoColors.borderSubtle),
          ),
          child: Column(
            children: [
              _receiptRow('Amount', '₹${record.amountInr}', isBold: true, highlight: WinzoColors.success),
              const Divider(color: WinzoColors.borderSubtle, height: 20),
              _receiptRow('Coins Deducted', '-${record.coins} 🪙'),
              const Divider(color: WinzoColors.borderSubtle, height: 20),
              _receiptRow('Method', record.methodName),
              const Divider(color: WinzoColors.borderSubtle, height: 20),
              _receiptRow('Mobile Number', record.mobileNumber),
              const Divider(color: WinzoColors.borderSubtle, height: 20),
              _receiptRow('Transaction ID', record.id),
              const Divider(color: WinzoColors.borderSubtle, height: 20),
              _receiptRow('Status', record.status, highlight: WinzoColors.warning),
            ],
          ),
        ),
        const SizedBox(height: WinzoDimens.spaceXL),

        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WinzoColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, Color? highlight}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: WinzoColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: highlight ?? WinzoColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
