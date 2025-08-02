
import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubService {
  final String _accessToken;

  GitHubService(this._accessToken);

  Future<List<dynamic>> getRepositories() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/user/repos'),
      headers: {
        'Authorization': 'token $_accessToken',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load repositories');
    }
  }
}
