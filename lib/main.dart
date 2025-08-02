import 'package:flutter/material.dart';
import 'package:github_manager_web/github_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  String? _accessToken;

  void _login(String accessToken) {
    setState(() {
      _isLoggedIn = true;
      _accessToken = accessToken;
    });
  }

  void _logout() {
    setState(() {
      _isLoggedIn = false;
      _accessToken = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _isLoggedIn
          ? RepositoryListPage(
              onLogout: _logout,
              githubService: GitHubService(_accessToken!),
            )
          : LoginPage(onLogin: () => _login("YOUR_DUMMY_ACCESS_TOKEN")),
    );
  }
}

class LoginPage extends StatelessWidget {
  final VoidCallback onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: onLogin,
          child: const Text('Login with GitHub'),
        ),
      ),
    );
  }
}

class RepositoryListPage extends StatefulWidget {
  final VoidCallback onLogout;
  final GitHubService githubService;

  const RepositoryListPage(
      {super.key, required this.onLogout, required this.githubService});

  @override
  State<RepositoryListPage> createState() => _RepositoryListPageState();
}

class _RepositoryListPageState extends State<RepositoryListPage> {
  Future<List<dynamic>>? _repositories;

  @override
  void initState() {
    super.initState();
    _repositories = widget.githubService.getRepositories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _repositories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No repositories found.'));
          } else {
            final repositories = snapshot.data!;
            return ListView.builder(
              itemCount: repositories.length,
              itemBuilder: (context, index) {
                final repo = repositories[index];
                return ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(repo['name']),
                  subtitle: Text(repo['description'] ?? 'No description'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement repository detail view
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
