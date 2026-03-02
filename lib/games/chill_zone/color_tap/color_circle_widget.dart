
import 'package:flutter/material.dart';

class ColorCircleData {
  final Color color;
  final double size;
  final String? tapResult; // 'correct', 'false', or null
  
  ColorCircleData({required this.color, required this.size, this.tapResult});
}

class ColorCircleWidget extends StatefulWidget {
  final ColorCircleData data;
  final Function(Color) onTap;

  const ColorCircleWidget({
    Key? key,
    required this.data,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ColorCircleWidget> createState() => _ColorCircleWidgetState();
}

class _ColorCircleWidgetState extends State<ColorCircleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isTapped) return;

    setState(() {
      _isTapped = true;
    });

    _controller.forward().then((_) {
      _controller.reverse();
      widget.onTap(widget.data.color);
      
      // Reset tap state after animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isTapped = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.data.size,
          height: widget.data.size,
          decoration: BoxDecoration(
            color: widget.data.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.data.color.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isTapped && widget.data.tapResult != null
              ? Center(
                  child: Icon(
                    widget.data.tapResult == 'correct' 
                        ? Icons.check_circle 
                        : Icons.cancel,
                    color: Colors.white,
                    size: widget.data.size * 0.4,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
