import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrialExpiredScreen extends ConsumerWidget {
  const TrialExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Trial Expired',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your 7-day free trial has ended. Subscribe to continue using Permission Manager Pro.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to payment or show dialog
                    // For now, we reuse the logic from client dashboard or just show message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please contact admin or use client dashboard logic to pay',
                        ),
                      ),
                    );
                    // In a real flow, we'd navigate to a dedicated payment screen
                  },
                  child: const Text('Subscribe for KES 199/mo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
