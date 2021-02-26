// app_background.dart
import 'package:flutter/material.dart';

class AppBackgroundPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraint) {
      final height = constraint.maxHeight;
      final width = constraint.maxWidth;
      return Stack(
        children: <Widget>[
          Container(
            color: Color(0xFFE4E6F1),
          ),
          Positioned(
            right: (height / 9 - height / 2),
            top: -height * 0.09,
            child: Container(
              height: height,
              width: width,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Positioned(
            top: height * 0.60,
            right: height * 0.09,
            child: Container(
              height: height,
              width: width,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(0.4)),
            ),
          ),
          Positioned(
            top: -height * 0.20,
            left: -height * 0.39,
            child: Container(
              height: height,
              width: width,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
            ),
          ),
        ],
      );
    });
  }
}