import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/groups/data/group_repository.dart';
import 'package:instagram_clone/features/groups/domain/veyro_group.dart';

Future<String?> showGroupEditor(
        BuildContext context, GroupRepository repository,
        {VeyroGroup? group}) =>
    showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GroupEditor(repository: repository, group: group));

class _GroupEditor extends StatefulWidget {
  final GroupRepository repository;
  final VeyroGroup? group;

  const _GroupEditor({required this.repository, this.group});

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group?.name);
  late final _description =
      TextEditingController(text: widget.group?.description);
  late GroupCategory _category =
      widget.group?.category ?? GroupCategory.general;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = widget.group;
      final String id;
      if (group == null) {
        id = await widget.repository
            .create(_name.text, _description.text, _category);
      } else {
        await widget.repository
            .edit(group.id, _name.text, _description.text, _category);
        id = group.id;
      }
      if (mounted) Navigator.of(context).pop(id);
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error =
              'Could not save the group. Check your connection and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          scrollable: true,
          title: Text(widget.group == null ? 'Start a group' : 'Edit group'),
          content: SizedBox(
              width: 380,
              child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          'Public group · people can view posts, and only members can publish.',
                          style: context.veyroText.bodySmall),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 50,
                        textInputAction: TextInputAction.next,
                        decoration:
                            const InputDecoration(labelText: 'Group name'),
                        validator: (value) {
                          final length = (value ?? '').trim().runes.length;
                          return length < 3 || length > 50
                              ? 'Use 3–50 characters.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<GroupCategory>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: [
                          for (final value in GroupCategory.values)
                            DropdownMenuItem(
                                value: value, child: Text(value.label))
                        ],
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value != null)
                                  setState(() => _category = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        enabled: !_busy,
                        maxLength: 360,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'Description (optional)'),
                        validator: (value) =>
                            (value ?? '').trim().runes.length > 360
                                ? 'Use up to 360 characters.'
                                : null,
                      ),
                      if (_busy) const LinearProgressIndicator(minHeight: 2),
                      if (_error != null)
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: TextStyle(
                                    color: context.veyroColors.error))),
                    ]),
              )),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                    widget.group == null ? 'Create group' : 'Save changes')),
          ],
        ),
      );
}
