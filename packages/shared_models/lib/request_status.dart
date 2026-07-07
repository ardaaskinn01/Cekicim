enum RequestStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Çekici Aranıyor';
      case RequestStatus.accepted:
        return 'Sürücü Yolda';
      case RequestStatus.inProgress:
        return 'Hizmet Veriliyor';
      case RequestStatus.completed:
        return 'Tamamlandı';
      case RequestStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  String get dbValue {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.inProgress:
        return 'in_progress';
      case RequestStatus.completed:
        return 'completed';
      case RequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static RequestStatus fromString(String? value) {
    switch (value) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'in_progress':
        return RequestStatus.inProgress;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
        return RequestStatus.cancelled;
      case 'pending':
      default:
        return RequestStatus.pending;
    }
  }
}
