enum RequestStatus {
  pending,
  awaitingAcceptance,
  accepted,
  inProgress,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Çekici Aranıyor';
      case RequestStatus.awaitingAcceptance:
        return 'Sürücü Onayı Bekleniyor';
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
      case RequestStatus.awaitingAcceptance:
        return 'awaiting_acceptance';
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
      case 'awaiting_acceptance':
        return RequestStatus.awaitingAcceptance;
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
