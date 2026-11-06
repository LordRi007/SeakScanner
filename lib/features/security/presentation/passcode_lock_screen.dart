import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/security_service.dart';

class PasscodeLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PasscodeLockScreen({super.key, required this.onUnlocked});

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  String _enteredCode = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final bioEnabled = await SecurityService.instance.isBiometricsEnabled();
    if (bioEnabled) {
      final success = await SecurityService.instance.authenticateWithBiometrics();
      if (success && mounted) {
        widget.onUnlocked();
      }
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredCode.length >= 6) return;
    HapticFeedback.lightImpact();

    setState(() {
      _enteredCode += digit;
      _errorMessage = null;
    });

    if (_enteredCode.length >= 4) {
      _verifyCode();
    }
  }

  void _onDelete() {
    if (_enteredCode.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyCode() async {
    final valid = await SecurityService.instance.verifyPasscode(_enteredCode);
    if (valid) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    } else {
      if (_enteredCode.length >= 6) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Incorrect passcode. Try again.';
          _enteredCode = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.t('appName'),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('enterPasscode'),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // PIN Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredCode.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppColors.secondary : Colors.white24,
                    border: Border.all(color: Colors.white38),
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],

            const Spacer(),

            // Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fingerprint_rounded, color: AppColors.secondary, size: 32),
                        onPressed: _checkBiometrics,
                      ),
                      _buildKeypadButton('0'),
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 28),
                        onPressed: _onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildKeypadButton).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

