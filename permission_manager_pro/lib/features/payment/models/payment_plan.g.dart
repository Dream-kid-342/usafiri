// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaymentPlanImpl _$$PaymentPlanImplFromJson(Map<String, dynamic> json) =>
    _$PaymentPlanImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$PaymentPlanImplToJson(_$PaymentPlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'duration_days': instance.durationDays,
      'features': instance.features,
      'is_active': instance.isActive,
      'created_at': instance.createdAt?.toIso8601String(),
    };
