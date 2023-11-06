import 'package:flutter/material.dart';

/// Simple button widget with expanded layout by default
class ButtonExpanded extends StatelessWidget {
  final Icon? icon;
  final String? text;
  final Color? color;
  final bool? enabled;
  final int? flex;
  final double? borderRadius;
  final double height; // Define height as a required parameter
  final Function()? onPressed;

  ButtonExpanded({
    this.icon,
    this.text,
    this.color,
    this.enabled,
    this.flex = 1,
    this.borderRadius = 0,
    required this.height, // Make height required
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex ?? 1,
      child: Container(
        height: height, // Set the height here
        child: ElevatedButton(
          onPressed: enabled! ? onPressed : null,
          style: ElevatedButton.styleFrom(
            primary: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              icon!,
              SizedBox(width: 5.0),
              Text(text!),
            ],
          ),
        ),
      ),
    );
  }
}
