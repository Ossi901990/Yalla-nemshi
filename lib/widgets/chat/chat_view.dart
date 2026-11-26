// lib/widgets/chat/chat_view.dart
//
// Shared chat layout in the 2026 style, used by the walk group chat and DMs.
// Pure UI: the screens keep the Firestore streams and sending, and pass in
// plain ChatMessage objects, so this view can be tested without Firebase.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../ui/ui_kit.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    this.text = '',
    this.imageUrl,
    this.sentAt,
    this.deleted = false,
  });

  final String id;
  final String senderId;
  final String? senderName;
  final String text;
  final String? imageUrl;

  /// Null while the server timestamp is still pending (just sent).
  final DateTime? sentAt;
  final bool deleted;
}

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.messages,
    required this.currentUid,
    required this.onBack,
    required this.onSend,
    required this.emptyTitle,
    required this.emptyText,
    this.showSenderNames = false,
    this.loading = false,
    this.error,
    this.onAttach,
    this.attaching = false,
    this.onLongPressMine,
    this.onOpenImage,
    this.now,
  });

  final String title;
  final String subtitle;

  /// Avatar (DM) or walk icon (group chat) next to the title.
  final Widget leading;

  /// Newest first, as Firestore returns them.
  final List<ChatMessage> messages;
  final String? currentUid;
  final VoidCallback onBack;

  /// Sends the text; the box clears straight away.
  final Future<void> Function(String text) onSend;
  final String emptyTitle;
  final String emptyText;

  /// Group chat: show who wrote each run of messages.
  final bool showSenderNames;
  final bool loading;
  final String? error;

  /// Photo button (only when photo uploads are switched on).
  final VoidCallback? onAttach;
  final bool attaching;
  final void Function(ChatMessage)? onLongPressMine;
  final void Function(String url)? onOpenImage;

  /// For tests; defaults to the current time.
  final DateTime? now;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await widget.onSend(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static DateTime _dateOf(DateTime t) => DateTime(t.year, t.month, t.day);

  String _dayLabel(DateTime d) {
    final now = widget.now ?? DateTime.now();
    final diff = _dateOf(now).difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(d);
    return DateFormat('EEE d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: widget.title,
              subtitle: widget.subtitle,
              leading: widget.leading,
              onBack: widget.onBack,
            ),
            Expanded(child: _body(context)),
            _Composer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
              onAttach: widget.onAttach,
              attaching: widget.attaching,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final p = AppPalette.of(context);
    if (widget.error != null) {
      return _Centered(
        child: Text(
          "Couldn't load the chat. ${widget.error}",
          textAlign: TextAlign.center,
          style: AppText.body(15, color: p.textMuted),
        ),
      );
    }
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final msgs = widget.messages;
    if (msgs.isEmpty) {
      return _Centered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppPalette.lime,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                size: 34,
                color: AppPalette.ink,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              widget.emptyTitle,
              textAlign: TextAlign.center,
              textScaler: AppText.headlineScaler(context),
              style: AppText.display(26, color: p.text),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              widget.emptyText,
              textAlign: TextAlign.center,
              style: AppText.body(15, color: p.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.sm,
        AppSpace.page,
        AppSpace.sm,
      ),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final m = msgs[i];
        // Older neighbour is i + 1 (list is newest first, drawn reversed).
        final older = i + 1 < msgs.length ? msgs[i + 1] : null;
        final newer = i > 0 ? msgs[i - 1] : null;
        final isMe = m.senderId == widget.currentUid;

        final day = m.sentAt == null ? null : _dateOf(m.sentAt!);
        final olderDay = older?.sentAt == null ? null : _dateOf(older!.sentAt!);
        final newDay = day != null && (older == null || olderDay != day);

        // A "run" is consecutive messages from one sender on one day.
        final startsRun =
            newDay || older == null || older.senderId != m.senderId;
        final endsRun =
            newer == null ||
            newer.senderId != m.senderId ||
            (newer.sentAt != null &&
                day != null &&
                _dateOf(newer.sentAt!) != day);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) _DaySeparator(label: _dayLabel(day)),
            _Bubble(
              message: m,
              isMe: isMe,
              showName: widget.showSenderNames && !isMe && startsRun,
              showTime: endsRun,
              topGap: startsRun ? AppSpace.md : 3,
              onLongPress: isMe && !m.deleted && widget.onLongPressMine != null
                  ? () => widget.onLongPressMine!(m)
                  : null,
              onOpenImage: widget.onOpenImage,
            ),
          ],
        );
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.page),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight - AppSpace.page * 2),
        child: Center(child: child),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.md,
        AppSpace.page,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
            tooltip: 'Back',
            size: 44,
          ),
          const SizedBox(width: AppSpace.md),
          leading,
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: AppText.headlineScaler(context),
                  style: AppText.display(20, color: p.text),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(13, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xs),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpace.radiusPill),
          ),
          child: Text(
            label,
            style: AppText.body(
              12,
              color: p.textMuted,
              weight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMe,
    required this.showName,
    required this.showTime,
    required this.topGap,
    this.onLongPress,
    this.onOpenImage,
  });

  final ChatMessage message;
  final bool isMe;
  final bool showName;
  final bool showTime;
  final double topGap;
  final VoidCallback? onLongPress;
  final void Function(String url)? onOpenImage;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final m = message;
    final bg = m.deleted
        ? Colors.transparent
        : isMe
        ? AppPalette.lime
        : p.surface;
    final fg = isMe && !m.deleted ? AppPalette.ink : p.text;
    const r = Radius.circular(22);
    const tail = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !isMe && showTime ? tail : r,
      bottomRight: isMe && showTime ? tail : r,
    );
    final hasImage = (m.imageUrl ?? '').isNotEmpty && !m.deleted;

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 4),
              child: Text(
                (m.senderName ?? '').trim().isEmpty ? 'Walker' : m.senderName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  13,
                  color: p.textMuted,
                  weight: FontWeight.w800,
                ),
              ),
            ),
          FractionallySizedBox(
            widthFactor: 0.8,
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  padding: hasImage
                      ? const EdgeInsets.all(6)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                    border: isMe && !m.deleted
                        ? null
                        : Border.all(color: p.border),
                  ),
                  child: m.deleted
                      ? Text(
                          'Message deleted',
                          style: AppText.body(
                            14,
                            color: p.textMuted,
                          ).copyWith(fontStyle: FontStyle.italic),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasImage)
                              GestureDetector(
                                onTap: onOpenImage == null
                                    ? null
                                    : () => onOpenImage!(m.imageUrl!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: SizedBox(
                                    width: 220,
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: Image.network(
                                        m.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: p.surfaceMuted,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: p.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (m.text.isNotEmpty)
                              Padding(
                                padding: hasImage
                                    ? const EdgeInsets.fromLTRB(10, 8, 10, 4)
                                    : EdgeInsets.zero,
                                child: Text(
                                  m.text,
                                  style: AppText.body(
                                    16,
                                    color: fg,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          if (showTime && m.sentAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(
                DateFormat('HH:mm').format(m.sentAt!),
                style: AppText.body(12, color: p.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
    required this.attaching,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final bool attaching;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.sm,
        AppSpace.page,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onAttach != null) ...[
            attaching
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : RoundIconButton(
                    icon: Icons.photo_outlined,
                    onTap: onAttach!,
                    tooltip: 'Send a photo',
                    size: 48,
                  ),
            const SizedBox(width: AppSpace.sm),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppText.body(16, color: p.text),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: AppText.body(16, color: p.textMuted),
                counterText: '',
                filled: true,
                fillColor: p.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: p.text, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          sending
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : RoundIconButton(
                  icon: Icons.arrow_upward_rounded,
                  onTap: onSend,
                  tooltip: 'Send',
                  background: AppPalette.lime,
                  foreground: AppPalette.ink,
                  size: 48,
                ),
        ],
      ),
    );
  }
}
