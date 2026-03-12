import 'package:flutter/material.dart';

class FlipCardData {
  final String id;
  final String value; // The card content (e.g., 'dog', 'cat')
  final IconData icon; // Visual representation
  final Color color;
  bool isFlipped;
  bool isMatched;

  FlipCardData({
    required this.id,
    required this.value,
    required this.icon,
    required this.color,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class FlipCardWidget extends StatefulWidget {
  final FlipCardData data;
  final Function(FlipCardData) onTap;
  final double size;

  const FlipCardWidget({
    Key? key,
    required this.data,
    required this.onTap,
    this.size = 100,
  }) : super(key: key);

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    // Set initial animation state based on card's isFlipped state
    _controller.value = widget.data.isFlipped ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(FlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate based on current state, ignoring object identity
    if (widget.data.isFlipped) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.data.isMatched && !widget.data.isFlipped) {
      widget.onTap(widget.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * 3.14159; // π radians = 180°
          final isFront = angle < 1.5708; // Less than π/2

          return Transform(
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(angle),
            alignment: Alignment.center,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: isFront ? Colors.blue.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      widget.data.isMatched
                          ? Colors.green
                          : Colors.grey.shade300,
                  width: widget.data.isMatched ? 4 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  isFront
                      ? _buildCardBack()
                      : Transform(
                        transform: Matrix4.identity()..rotateY(3.14159),
                        alignment: Alignment.center,
                        child: _buildCardFront(),
                      ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardBack() {
    return Center(
      child: Icon(
        Icons.question_mark,
        size: widget.size * 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCardFront() {
    if (widget.data.isMatched) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.data.icon,
                size: widget.size * 0.4,
                color: widget.data.color,
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                size: widget.size * 0.2,
                color: Colors.green,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        widget.data.icon,
        size: widget.size * 0.5,
        color: widget.data.color,
      ),
    );
  }
}
