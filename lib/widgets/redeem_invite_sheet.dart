import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/invite_service.dart';
import '../services/deep_link_service.dart';

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

  Future<void> _pasteAndParse() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();

      if (text == null || text.isEmpty) {
        setState(() {
          _error = 'Clipboard is empty';
        });
        return;
      }

      // Check if it's a URL
      if (text.startsWith('http')) {
        final parsed = DeepLinkService.instance.parseInviteUrl(text);
        final walkId = parsed['walkId'];
        final code = parsed['code'];

        if (walkId != null && walkId.isNotEmpty) {
          _walkIdCtrl.text = walkId;
          if (code != null && code.isNotEmpty) {
            _codeCtrl.text = code;
          }
          setState(() {
            _error = null;
          });
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invite link parsed successfully!')),
            );
          }
          return;
        }
      }

      // If not a valid URL, show error
      setState(() {
        _error = 'Invalid invite link format';
      });
    } catch (e) {
      setState(() {
        _error = 'Could not parse clipboard';
      });
    }
  }

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
              OutlinedButton.icon(
                onPressed: _pasteAndParse,
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Paste invite link'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
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
