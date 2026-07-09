import 'package:flutter/material.dart';
import 'package:shared_models/request_status.dart';
import '../app_colors.dart';

extension RequestStatusExtension on RequestStatus {
  Color get color {
    switch (this) {
      case RequestStatus.pending:
        return AppColors.warning;
      case RequestStatus.awaitingAcceptance:
        return AppColors.warning;
      case RequestStatus.accepted:
      case RequestStatus.inProgress:
        return AppColors.accent;
      case RequestStatus.completed:
        return AppColors.success;
      case RequestStatus.cancelled:
        return AppColors.error;
    }
  }
}
