import 'package:flutter/material.dart';

/// Manages smooth horizontal slide transitions between bottom navigation branches
/// while preserving the state and map view of each branch using Offstage.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousIndex = 0;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _isForward = widget.currentIndex > _previousIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final isAnimating = _controller.isAnimating;
        final progress = _animation.value;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (index) {
            final isCurrent = index == widget.currentIndex;
            final isPrevious = index == _previousIndex && isAnimating;

            if (isCurrent && isAnimating) {
              final dx = _isForward ? (1.0 - progress) : (progress - 1.0);
              return FractionalTranslation(
                translation: Offset(dx, 0),
                child: widget.children[index],
              );
            }

            if (isPrevious) {
              final dx = _isForward ? -progress : progress;
              return FractionalTranslation(
                translation: Offset(dx, 0),
                child: widget.children[index],
              );
            }

            return Offstage(
              offstage: !isCurrent,
              child: widget.children[index],
            );
          }),
        );
      },
    );
  }
}
