import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  static final String _appId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  static final String _restApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';
  static const String _oneSignalUrl = 'https://onesignal.com/api/v1/notifications';

  /// Sends a push notification to all admins when a customer has completed a payment.
  static Future<void> sendNotificationToAdmin({
    required String namaPenerima,
    required int total,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_oneSignalUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'filters': [
            {'field': 'tag', 'key': 'role', 'relation': '=', 'value': 'admin'},
          ],
          'headings': {'en': 'Pesanan Baru'},
          'contents': {'en': 'Pesanan baru dari $namaPenerima total Rp $total'},
        }),
      );
      print('OneSignal Admin Notif Status: ${response.statusCode}');
      print('OneSignal Admin Notif Body: ${response.body}');
    } catch (e) {
      print('Gagal kirim notifikasi admin: $e');
    }
  }

  /// Sends a push notification to a specific customer when their order status is updated.
  static Future<void> sendNotificationToCustomer({
    required String customerEmail,
    required String invoiceCode,
    required String status,
  }) async {
    try {
      String statusMsg = status;
      final statusLower = status.toLowerCase();
      if (statusLower == 'dibayar') {
        statusMsg = 'telah dibayar dan terverifikasi';
      } else if (statusLower == 'diproses') {
        statusMsg = 'sedang diproses';
      } else if (statusLower == 'dikirim') {
        statusMsg = 'sedang dikirim ke alamat Anda';
      } else if (statusLower == 'selesai') {
        statusMsg = 'telah selesai';
      } else if (statusLower == 'ditolak') {
        statusMsg = 'ditolak oleh admin';
      }

      print('Mengirim notifikasi ke customer dengan email: $customerEmail');
      final response = await http.post(
        Uri.parse(_oneSignalUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': [customerEmail]
          },
          'target_channel': 'push',
          'headings': {'en': 'Status Pesanan Diperbarui'},
          'contents': {
            'en': 'Pesanan Anda dengan invoice #$invoiceCode statusnya kini $statusMsg.'
          },
        }),
      );
      print('OneSignal Customer Notif Status: ${response.statusCode}');
      print('OneSignal Customer Notif Body: ${response.body}');
    } catch (e) {
      print('Gagal kirim notifikasi customer: $e');
    }
  }
}
