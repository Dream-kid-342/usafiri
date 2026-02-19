import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:permission_manager_pro/features/payment/models/payment_plan.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_plan_repository.g.dart';

@riverpod
PaymentPlanRepository paymentPlanRepository(PaymentPlanRepositoryRef ref) {
  return PaymentPlanRepository();
}

class PaymentPlanRepository {
  Future<List<PaymentPlan>> getActivePlans() async {
    final response = await supabase
        .from('payment_plans')
        .select()
        .eq('is_active', true)
        .order('price', ascending: true);

    return (response as List).map((e) => PaymentPlan.fromJson(e)).toList();
  }

  Future<List<PaymentPlan>> getAllPlans() async {
    final response = await supabase
        .from('payment_plans')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((e) => PaymentPlan.fromJson(e)).toList();
  }

  Future<void> createPlan(PaymentPlan plan) async {
    await supabase.from('payment_plans').insert({
      'name': plan.name,
      'description': plan.description,
      'price': plan.price,
      'duration_days': plan.durationDays,
      'features': plan.features,
      'is_active': plan.isActive,
    });
  }

  Future<void> updatePlan(PaymentPlan plan) async {
    await supabase
        .from('payment_plans')
        .update({
          'name': plan.name,
          'description': plan.description,
          'price': plan.price,
          'duration_days': plan.durationDays,
          'features': plan.features,
          'is_active': plan.isActive,
        })
        .eq('id', plan.id);
  }

  Future<void> deletePlan(String id) async {
    await supabase.from('payment_plans').delete().eq('id', id);
  }
}
