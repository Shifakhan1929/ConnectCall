import 'package:flutter/material.dart';

class CallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  const CallButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor = Colors.white24,
    this.iconColor = Colors.white,
    this.size = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RawMaterialButton(
        onPressed: onPressed,
        shape: const CircleBorder(),
        elevation: 2.0,
        fillColor: backgroundColor,
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.45,
        ),
      ),
    );
  }
}
