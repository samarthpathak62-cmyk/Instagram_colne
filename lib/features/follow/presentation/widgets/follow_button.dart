import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/follow/presentation/bloc/follow_bloc.dart';

class FollowButton extends StatefulWidget {
  final String targetUserId;
  final VoidCallback? onChanged;

  const FollowButton({super.key, required this.targetUserId, this.onChanged});

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = true; // Start loading initially

  @override
  void initState() {
    super.initState();
    // Check initial follow status when the widget is built
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<FollowBloc>().add(CheckFollowStatusEvent(
            currentUserId: authState.user.id,
            targetUserId: widget.targetUserId,
          ));
    } else {
      // Handle case where user is not authenticated (button shouldn't be shown ideally)
      setState(() => _isLoading = false);
    }
  }

  void _notifyChange() {
    final feed = context.read<FeedCubit>();
    if (feed.state.timeline == FeedTimeline.following) feed.refresh();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId =
        (authState is Authenticated) ? authState.user.id : null;

    // Don't show button if viewing own profile or not logged in
    if (currentUserId == null || currentUserId == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    return BlocConsumer<FollowBloc, FollowState>(
      listener: (context, state) {
        // Listen for status updates specifically for *this* target user
        if (state is FollowStatusChecked &&
            state.targetUserId == widget.targetUserId) {
          setState(() {
            _isFollowing = state.isFollowing;
            _isLoading = false;
          });
        } else if (state is FollowSuccess &&
            state.targetUserId == widget.targetUserId) {
          setState(() {
            _isFollowing = true;
            _isLoading = false;
          });
          _notifyChange();
        } else if (state is UnfollowSuccess &&
            state.targetUserId == widget.targetUserId) {
          setState(() {
            _isFollowing = false;
            _isLoading = false;
          });
          _notifyChange();
        } else if (state is FollowOperationFailure &&
            state.targetUserId == widget.targetUserId) {
          setState(() {
            _isLoading = false; // Stop loading on failure
          });
          // Optionally show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
        } else if (state is FollowStatusCheckFailure &&
            state.targetUserId == widget.targetUserId) {
          setState(() {
            _isLoading = false; // Stop loading on failure
          });
          // Optionally show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
        }
      },
      // Build the button based on the state
      builder: (context, state) {
        // Determine button style and text
        final buttonStyle = _isFollowing
            ? OutlinedButton.styleFrom(
                side: BorderSide(color: context.veyroColors.outlineVariant),
                foregroundColor: context.veyroColors.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              )
            : ElevatedButton.styleFrom(
                backgroundColor: VeyroTheme.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              );
        final buttonText = _isFollowing ? 'Following' : 'Follow';

        return SizedBox(
          width: 106,
          height: 44,
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    if (_isFollowing) {
                      context.read<FollowBloc>().add(UnfollowUserEvent(
                            currentUserId: currentUserId,
                            targetUserId: widget.targetUserId,
                          ));
                    } else {
                      context.read<FollowBloc>().add(FollowUserEvent(
                            currentUserId: currentUserId,
                            targetUserId: widget.targetUserId,
                          ));
                    }
                    // Optimistic UI update (optional) or wait for state change
                    // setState(() => _isLoading = true);
                  },
                  style: buttonStyle,
                  child: Text(buttonText),
                ),
        );
      },
    );
  }
}
