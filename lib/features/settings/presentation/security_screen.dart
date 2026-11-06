import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/security_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _isLockEnabled = false;
  bool _useBiometrics = false;
  bool _hasPasscode = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final lock = await SecurityService.instance.isAppLockEnabled();
    final bio = await SecurityService.instance.isBiometricsEnabled();
    final hasPass = await SecurityService.instance.hasPasscode();
    final canBio = await SecurityService.instance.canCheckBiometrics();

    if (mounted) {
      setState(() {
        _isLockEnabled = lock;
        _useBiometrics = bio;
        _hasPasscode = hasPass;
        _canCheckBiometrics = canBio;
      });
    }
  }

  Future<void> _setNewPasscode() async {
    final l10n = AppLocalizations.of(context);
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('changePasscode')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl1,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(hintText: l10n.t('enterPasscode')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl2,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(hintText: l10n.t('confirmPasscode')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            onPressed: () {
              if (ctrl1.text == ctrl2.text && ctrl1.text.length >= 4) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.t('passcodesDoNotMatch'))),
                );
              }
            },
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );

    if (result == true) {
      await SecurityService.instance.setPasscode(ctrl1.text);
      _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('securityTitle')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.t('securitySubtitle'),
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.t('enableAppLock'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  value: _isLockEnabled,
                  onChanged: (val) async {
                    if (val && !_hasPasscode) {
                      _setNewPasscode();
                    } else {
                      await SecurityService.instance.setAppLockEnabled(val);
                      _loadStatus();
                    }
                  },
                ),
                if (_hasPasscode)
                  ListTile(
                    title: Text(l10n.t('changePasscode')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _setNewPasscode,
                  ),
                if (_canCheckBiometrics)
                  SwitchListTile(
                    title: Text(l10n.t('useBiometrics'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _useBiometrics,
                    onChanged: (val) async {
                      await SecurityService.instance.setBiometricsEnabled(val);
                      _loadStatus();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.success, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('privacyStatement'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.t('privacyDetails'),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

