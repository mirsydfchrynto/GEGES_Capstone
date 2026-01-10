import 'package:flutter/material.dart';

class SkeletonCard extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.borderRadius = 16,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.grey[850], // Darker grey
      end: Colors.grey[700],   // Lighter grey
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonBarbershopCard extends StatelessWidget {
  const SkeletonBarbershopCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Match card background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Skeleton
          const SkeletonCard(height: 180, borderRadius: 20),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Distance Skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonCard(width: 150, height: 24, borderRadius: 4),
                    SkeletonCard(width: 60, height: 20, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Address Skeleton
                const SkeletonCard(width: 200, height: 16, borderRadius: 4),
                const SizedBox(height: 16),
                
                // Tags Skeleton
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    SkeletonCard(width: 80, height: 30, borderRadius: 30),
                    SkeletonCard(width: 100, height: 30, borderRadius: 30),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Button Skeleton
                const SkeletonCard(height: 55, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
