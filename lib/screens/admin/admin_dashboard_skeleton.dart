import 'package:flutter/material.dart';
import 'package:geges_smartbarber/widgets/skeleton_card.dart';

class AdminDashboardSkeleton extends StatelessWidget {
  const AdminDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar Skeleton
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonCard(width: 200, height: 28, borderRadius: 6),
                      SizedBox(height: 8),
                      SkeletonCard(width: 120, height: 16, borderRadius: 4),
                    ],
                  ),
                  SkeletonCard(width: 40, height: 40, borderRadius: 20),
                ],
              ),
              const SizedBox(height: 30),

              // Shop Toggle Skeleton
              const SkeletonCard(height: 60, borderRadius: 16),
              const SizedBox(height: 30),

              // Stats Row Skeleton
              Row(
                children: List.generate(4, (index) => 
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: const SkeletonCard(width: 80, height: 80, borderRadius: 12),
                  )
                ),
              ),
              const SizedBox(height: 30),

              // Menu Grid Skeleton
              const SkeletonCard(width: 150, height: 24, borderRadius: 4), // "Main Menu" title
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(6, (index) => 
                  const SkeletonCard(height: 100, borderRadius: 16)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
