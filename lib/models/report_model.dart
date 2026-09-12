import 'package:flutter/foundation.dart';

enum ReportTargetType {
  cart,
  user;

  static ReportTargetType fromWire(String? value) =>
      value == 'user' ? ReportTargetType.user : ReportTargetType.cart;
  String get wire => name;
}

enum ReportReason {
  spam,
  fakeListing,
  wrongLocation,
  offensive,
  other;

  static ReportReason fromWire(String? value) => ReportReason.values
      .firstWhere((r) => r.name == value, orElse: () => ReportReason.other);
  String get wire => name;

  String get label => switch (this) {
        ReportReason.spam => 'Spam',
        ReportReason.fakeListing => 'Fake listing',
        ReportReason.wrongLocation => 'Wrong location',
        ReportReason.offensive => 'Offensive content',
        ReportReason.other => 'Something else',
      };
}

enum ReportStatus {
  open,
  reviewing,
  resolved,
  dismissed;

  static ReportStatus fromWire(String? value) => ReportStatus.values
      .firstWhere((s) => s.name == value, orElse: () => ReportStatus.open);
  String get wire => name;

  String get label => switch (this) {
        ReportStatus.open => 'Open',
        ReportStatus.reviewing => 'Reviewing',
        ReportStatus.resolved => 'Resolved',
        ReportStatus.dismissed => 'Dismissed',
      };

  bool get isClosed =>
      this == ReportStatus.resolved || this == ReportStatus.dismissed;
}

@immutable
class ReportModel {
  const ReportModel({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    required this.createdAt,
    this.note = '',
    this.status = ReportStatus.open,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
  });

  final String id;
  final ReportTargetType targetType;
  final String targetId;
  final String targetName;
  final String reporterId;
  final String reporterName;
  final ReportReason reason;
  final String note;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;

  ReportModel copyWith({
    ReportStatus? status,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? resolutionNote,
  }) {
    return ReportModel(
      id: id,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      reporterId: reporterId,
      reporterName: reporterName,
      reason: reason,
      note: note,
      createdAt: createdAt,
      status: status ?? this.status,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'targetType': targetType.wire,
        'targetId': targetId,
        'targetName': targetName,
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reason': reason.wire,
        'note': note,
        'status': status.wire,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolvedBy': resolvedBy,
        'resolutionNote': resolutionNote,
      };

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      id: id,
      targetType: ReportTargetType.fromWire(map['targetType'] as String?),
      targetId: map['targetId'] as String? ?? '',
      targetName: map['targetName'] as String? ?? 'Unknown',
      reporterId: map['reporterId'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? 'Someone',
      reason: ReportReason.fromWire(map['reason'] as String?),
      note: map['note'] as String? ?? '',
      status: ReportStatus.fromWire(map['status'] as String?),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      resolvedAt: map['resolvedAt'] == null
          ? null
          : DateTime.tryParse(map['resolvedAt'] as String),
      resolvedBy: map['resolvedBy'] as String?,
      resolutionNote: map['resolutionNote'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportModel && other.id == id && other.status == status;

  @override
  int get hashCode => Object.hash(id, status);
}
