import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_ui/app_colors.dart';

class ConnectivityUtils {
  static Stream<List<ConnectivityResult>> get onConnectivityChanged => Connectivity().onConnectivityChanged;

  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  static Widget buildOfflineBanner() {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data;
        final isOffline = results != null && results.contains(ConnectivityResult.none);
        if (!isOffline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'İnternet bağlantısı kesildi. Çevrimdışı moddasınız.',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}
