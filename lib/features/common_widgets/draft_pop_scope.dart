import 'package:flutter/material.dart';

/// Route back and the close button follow the same draft rules.
class DraftPopScope extends StatefulWidget {
  final bool hasDraft;
  final bool uploading;
  final Widget child;

  const DraftPopScope(
      {super.key,
      required this.hasDraft,
      required this.uploading,
      required this.child});

  @override
  State<DraftPopScope> createState() => _DraftPopScopeState();
}

class _DraftPopScopeState extends State<DraftPopScope> {
  bool _confirming = false;

  Future<void> _confirmDiscard() async {
    if (_confirming || widget.uploading || !widget.hasDraft) return;
    _confirming = true;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Discard draft?'),
              content: const Text('Your changes won’t be saved.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Discard',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              ],
            ));
    _confirming = false;
    if (discard == true &&
        mounted &&
        !widget.uploading &&
        ModalRoute.isCurrentOf(context) == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !widget.hasDraft && !widget.uploading,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await _confirmDiscard();
        },
        child: widget.child,
      );
}
