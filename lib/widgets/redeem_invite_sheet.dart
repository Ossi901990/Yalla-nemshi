import 'package:flutter/material.dart';

import '../services/invite_service.dart';

class RedeemInviteSheet extends StatefulWidget {
  const RedeemInviteSheet({super.key});

  @override
  State<RedeemInviteSheet> createState() => _RedeemInviteSheetState();
}

class _RedeemInviteSheetState extends State<RedeemInviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _walkIdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final InviteService _inviteService = InviteService();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _walkIdCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _inviteService.redeemInvite(
        walkId: _walkIdCtrl.text,
        shareCode: _codeCtrl.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on InviteException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: media.viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Redeem private invite', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Enter the walk ID and invite code you received from the host. '
                'Valid codes unlock private walks instantly.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _walkIdCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Walk ID',
                  hintText: 'e.g. wk_A1B2C3',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Walk ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'ABC123',
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Invite code is required';
                  }
                  if (value.trim().length < 4) {
                    return 'Code looks too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Codes expire 7 days after the host publishes the walk. '
                'If yours expired, ask them to regenerate before trying again.',
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Redeem invite'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
