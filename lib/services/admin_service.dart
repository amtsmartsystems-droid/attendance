import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminService {
  // We will call the new edge function 'assign-door'
  static String get _assignDoorUrl =>
      '${SupabaseConfig.url}/functions/v1/assign-door';

  static Future<bool> assignNewDoor({
    required String doorName,
    required String doorLocation,
    required String nfcUid,
    required String adminPin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_assignDoorUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'door_name': doorName,
          'location': doorLocation,
          'nfc_uid': nfcUid,
          'admin_pin': adminPin,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error assigning door: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception assigning door: $e');
      return false;
    }
  }
}
