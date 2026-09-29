enum UserRole {
  customer,
  driver,
  admin;

  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Müşteri';
      case UserRole.driver:
        return 'Çekici Sürücüsü';
      case UserRole.admin:
        return 'Yönetici';
    }
  }

  String get dbValue {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.driver:
        return 'driver';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}
