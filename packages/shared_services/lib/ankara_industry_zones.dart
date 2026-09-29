class IndustryZone {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;

  const IndustryZone({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  double distanceTo(double lat, double lng) {
    // Quick Euclidean distance for local area projection (fast and sufficient)
    final double dLat = latitude - lat;
    final double dLng = longitude - lng;
    return dLat * dLat + dLng * dLng;
  }
}

class AnkaraIndustryZones {
  static const List<IndustryZone> zones = [
    IndustryZone(
      id: 'ostim',
      name: 'OSTİM Organize Sanayi Bölgesi',
      description: 'Türkiye\'nin en büyük küçük ve orta ölçekli sanayi üretim alanı.',
      latitude: 39.9839,
      longitude: 32.7411,
    ),
    IndustryZone(
      id: 'ivedik',
      name: 'İvedik Organize Sanayi Bölgesi',
      description: 'Ankara\'nın önemli sanayi ve ticaret merkezlerinden.',
      latitude: 40.0075,
      longitude: 32.7533,
    ),
    IndustryZone(
      id: 'siteler',
      name: 'Siteler Mobilya Sanayi',
      description: 'Türkiye\'nin en köklü ve büyük mobilya üretim merkezi.',
      latitude: 39.9575,
      longitude: 32.8894,
    ),
    IndustryZone(
      id: 'sincan_osb',
      name: 'ASO 1. Organize Sanayi Bölgesi (Sincan)',
      description: 'Ankara Sanayi Odası 1. OSB.',
      latitude: 39.9542,
      longitude: 32.5539,
    ),
    IndustryZone(
      id: 'diskapı',
      name: 'Dışkapı Sanayi Sitesi (Ata Sanayi)',
      description: 'Şehir merkezine yakın oto sanayi ve tamirhane bölgesi.',
      latitude: 39.9511,
      longitude: 32.8533,
    ),
    IndustryZone(
      id: 'kazan_osb',
      name: 'Keresteciler ve Kazan OSB',
      description: 'Sarayköy ve Kahramankazan yolu üzeri sanayi tesisleri.',
      latitude: 40.0658,
      longitude: 32.6186,
    ),
    IndustryZone(
      id: 'baskent_osb',
      name: 'Başkent Organize Sanayi Bölgesi',
      description: 'Malıköy mevkii, Ankara\'nın yeni sanayi üssü.',
      latitude: 39.7744,
      longitude: 32.4283,
    ),
    IndustryZone(
      id: 'sasmaz',
      name: 'Şaşmaz Oto Sanayi Sitesi',
      description: 'Otomotiv tamir ve bakımında Ankara\'nın en bilinen sanayi sitesi.',
      latitude: 39.9419,
      longitude: 32.7214,
    ),
  ];

  static List<IndustryZone> getSortedZones(double lat, double lng) {
    final List<IndustryZone> sorted = List.from(zones);
    sorted.sort((a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
    return sorted;
  }
}
