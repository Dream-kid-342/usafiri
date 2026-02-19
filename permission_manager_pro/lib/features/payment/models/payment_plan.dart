import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_plan.freezed.dart';
part 'payment_plan.g.dart';

@freezed
class PaymentPlan with _$PaymentPlan {
  const factory PaymentPlan({
    required String id,
    required String name,
    String? description,
    required double price,
    @JsonKey(name: 'duration_days') @Default(30) int durationDays,
    @Default([]) List<String> features,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _PaymentPlan;

  factory PaymentPlan.fromJson(Map<String, dynamic> json) =>
      _$PaymentPlanFromJson(json);
}
