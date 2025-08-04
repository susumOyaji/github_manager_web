
import 'dart:convert';
import 'package:http/browser_client.dart';

class GitHubService {
  final String _workerUrl = 'https://github-auth-worker.sumitomo0210.workers.dev';
  late final BrowserClient _client;

  GitHubService() {
    _client = BrowserClient()..withCredentials = true;
  }

  Future<List<dynamic>> getRepositories({int page = 1, int perPage = 30}) async {
    final response = await _client.get(
      Uri.parse('$_workerUrl/api/user/repos?per_page=$perPage&page=$page'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Not authenticated. Please login again.');
    } else {
      throw Exception('Failed to load repositories: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getUser() async {
    final response = await _client.get(
      Uri.parse('$_workerUrl/api/user'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user data: ${response.body}');
    }
  }

  Future<void> deleteRepository(String fullName) async {
    final response = await _client.delete(
      Uri.parse('$_workerUrl/api/repos/$fullName'),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete repository. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }
}
