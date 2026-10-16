import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/utils/phone_actions.dart';
import '../../data/messaging_repository.dart';

/// Opens the in-app thread between the passenger and the driver of [rideId].
///
/// [repository] exists as a test seam: a subclass overriding the three methods
/// lets widget tests drive the sheet without a network.
Future<void> showRideChatSheet(
  BuildContext context, {
  required String rideId,
  required String otherPartyName,
  required String? currentUserId,
  String? otherPartyPhone,
  String? plateNumber,
  MessagingRepository? repository,
  VoidCallback? onThreadRead,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => RideChatSheet(
      rideId: rideId,
      otherPartyName: otherPartyName,
      currentUserId: currentUserId,
      otherPartyPhone: otherPartyPhone,
      plateNumber: plateNumber,
      repository: repository,
      onThreadRead: onThreadRead,
    ),
  );
}

class RideChatSheet extends StatefulWidget {
  const RideChatSheet({
    super.key,
    required this.rideId,
    required this.otherPartyName,
    required this.currentUserId,
    this.otherPartyPhone,
    this.plateNumber,
    this.repository,
    this.onThreadRead,
  });

  final String rideId;
  final String otherPartyName;

  /// Used to tell own messages from the other party's; null when unknown, in
  /// which case every message renders as received.
  final String? currentUserId;

  final String? otherPartyPhone;
  final String? plateNumber;
  final MessagingRepository? repository;
  final VoidCallback? onThreadRead;

  @override
  State<RideChatSheet> createState() => _RideChatSheetState();
}

class _RideChatSheetState extends State<RideChatSheet> {
  late final MessagingRepository _repository =
      widget.repository ?? MessagingRepository();

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<RideMessage> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initialise();
    // Poll while the thread is open: the other party's replies arrive without
    // a push service.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialise() async {
    await _loadMessages();
    if (!mounted) return;
    try {
      await _repository.markRead(widget.rideId);
      widget.onThreadRead?.call();
    } catch (_) {
      // Read state is cosmetic; the thread still works.
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final messages = await _repository.getMessages(widget.rideId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        if (!silent) _error = null;
      });
      if (!silent) _scrollToBottom();
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final sent = await _repository.sendMessage(widget.rideId, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _isSending = false;
        _error = null;
      });
      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Keep the draft so the message is not lost.
      setState(() {
        _isSending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _call() async {
    final phone = widget.otherPartyPhone;
    if (phone == null || phone.isEmpty) return;
    final ok = await PhoneActions.placeCall(phone);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(media),
            Flexible(child: _buildBody()),
            _buildComposer(media),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MediaQueryData media) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherPartyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.plateNumber == null
                          ? 'In-app messages'
                          : 'In-app messages · ${widget.plateNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.otherPartyPhone != null &&
                  widget.otherPartyPhone!.isNotEmpty)
                IconButton(
                  onPressed: _call,
                  icon: const Icon(Icons.phone_rounded, size: 20),
                  color: const Color(0xFF2563EB),
                  tooltip: 'Call',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey.shade500,
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Say hello to ${widget.otherPartyName} about this ride.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final lastMine = _messages.lastWhere(
      (message) => message.senderId == widget.currentUserId,
      orElse: () => _messages.last,
    );

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = widget.currentUserId != null &&
            message.senderId == widget.currentUserId;
        final showReadLabel = isMine &&
            identical(message, lastMine) &&
            message.readAt != null;

        return _MessageBubble(
          message: message,
          isMine: isMine,
          showReadLabel: showReadLabel,
        );
      },
    );
  }

  Widget _buildComposer(MediaQueryData media) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, media.padding.bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message ${widget.otherPartyName}',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showReadLabel,
  });

  final RideMessage message;
  final bool isMine;
  final bool showReadLabel;

  String get _time {
    final createdAt = message.createdAt;
    if (createdAt == null) return '';
    final local = createdAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                message.body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: isMine ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            Text(
              showReadLabel ? '$_time · Read' : _time,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
