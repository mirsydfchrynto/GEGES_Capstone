
import 'package:flutter/material.dart';

// Warna Tema (sesuai main.dart)
const Color kBrownAccent = Color(0xFFC3A47B);

class LoadingWidget extends StatelessWidget {
  final Color color;
  const LoadingWidget({super.key, this.color = kBrownAccent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: color),
    );
  }
}
