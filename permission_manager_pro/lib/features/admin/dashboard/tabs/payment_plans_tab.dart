import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/features/payment/models/payment_plan.dart';
import 'package:permission_manager_pro/features/payment/repository/payment_plan_repository.dart';

final paymentPlansProvider = FutureProvider.autoDispose<List<PaymentPlan>>((
  ref,
) async {
  return ref.read(paymentPlanRepositoryProvider).getAllPlans();
});

class PaymentPlansTab extends ConsumerWidget {
  const PaymentPlansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(paymentPlansProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlanDialog(context, ref),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(
              child: Text('No payment plans found. Add one!'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isEven = index % 2 == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: isEven
                        ? [Colors.blueGrey.shade50, Colors.white]
                        : [Colors.white, Colors.blueGrey.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isEven
                        ? Colors.blueGrey.shade100
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: plan.isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    child: Icon(
                      Icons.star,
                      color: plan.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    plan.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'KES ${plan.price} - ${plan.durationDays} Days\n${plan.description ?? ""}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showPlanDialog(context, ref, plan: plan),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, plan.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showPlanDialog(
    BuildContext context,
    WidgetRef ref, {
    PaymentPlan? plan,
  }) {
    final nameController = TextEditingController(text: plan?.name);
    final priceController = TextEditingController(text: plan?.price.toString());
    final descController = TextEditingController(text: plan?.description);
    final daysController = TextEditingController(
      text: plan?.durationDays.toString() ?? '30',
    );
    bool isActive = plan?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(plan == null ? 'New Plan' : 'Edit Plan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Plan Name'),
                  ),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (KES)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: daysController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (Days)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (val) => setState(() => isActive = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newPlan = PaymentPlan(
                    id: plan?.id ?? 'temp', // ID ignored on insert
                    name: nameController.text,
                    price: double.tryParse(priceController.text) ?? 0,
                    description: descController.text,
                    durationDays: int.tryParse(daysController.text) ?? 30,
                    isActive: isActive,
                  );

                  if (plan == null) {
                    await ref
                        .read(paymentPlanRepositoryProvider)
                        .createPlan(newPlan);
                  } else {
                    await ref
                        .read(paymentPlanRepositoryProvider)
                        .updatePlan(newPlan.copyWith(id: plan.id));
                  }

                  ref.invalidate(paymentPlansProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(paymentPlanRepositoryProvider).deletePlan(id);
              ref.invalidate(paymentPlansProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
