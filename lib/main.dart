import 'package:flutter/material.dart';
import 'package:github_manager_web/github_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GitHubService _githubService = GitHubService();
  bool _isLoggedIn = false;
  bool _isLoading = true; // To show a loading indicator on startup

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Try to fetch user data. If it succeeds, we have a valid session.
      await _githubService.getUser();
      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
    } catch (e) {
      // If it fails (e.g., 401 Unauthorized), the user is not logged in.
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  void _login() {
    // Get the current URL of the Flutter app.
    final String currentUrl = Uri.base.toString();

    // Redirect to the Cloudflare Worker's login endpoint, passing the current URL.
    final loginUrl = Uri.parse('https://github-auth-worker.sumitomo0210.workers.dev/login')
        .replace(queryParameters: {'redirect_uri': currentUrl});

    launchUrl(loginUrl, webOnlyWindowName: '_self');
  }

  void _logout() {
    // To log out, we can't directly clear the HttpOnly cookie from the client.
    // A proper implementation would involve a /logout endpoint on the worker
    // that clears the cookie. For now, we'll just update the UI state.
    setState(() {
      _isLoggedIn = false;
    });
    // Ideally, you would also navigate the user to a page that confirms logout.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isLoggedIn
              ? RepositoryListPage(onLogout: _logout, githubService: _githubService)
              : LoginPage(onLogin: _login),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _repositories = widget.githubService.getRepositories();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
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
                  title: Text(repo['name'] ?? 'No Name'),
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