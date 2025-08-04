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
  List<dynamic> _repositories = []; // Make it non-final to allow reassignment
  bool _isLoading = true; // Unified loading state
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRepositories(isInitialLoad: true);
  }

  Future<void> _fetchRepositories({bool isInitialLoad = false}) async {
    if (_isLoading && !isInitialLoad) return;

    setState(() {
      _isLoading = true;
      if (isInitialLoad) _error = null;
    });

    const int perPage = 30;
    List<dynamic> fetchedRepos = [];
    String? error;

    try {
      fetchedRepos = await widget.githubService.getRepositories(page: _page, perPage: perPage);
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;

    setState(() {
      if (error != null) {
        _error = error;
      } else {
        if (isInitialLoad) {
          _repositories.clear();
          _page = 1;
          _hasMore = true;
        }
        _repositories.addAll(fetchedRepos);

        _sortRepositories();

        if (fetchedRepos.length < perPage) {
          _hasMore = false;
        } else {
          _hasMore = true;
          _page++;
        }
      }
      _isLoading = false;
    });
  }

  void _sortRepositories() {
    _repositories.sort((a, b) {
      final aDate = DateTime.tryParse(a['pushed_at'] ?? '');
      final bDate = DateTime.tryParse(b['pushed_at'] ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  }

  Future<void> _refresh() {
    _page = 1;
    _hasMore = true;
    return _fetchRepositories(isInitialLoad: true);
  }

  @override
  void dispose() {
    super.dispose();
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _repositories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    } else if (_error != null && _repositories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchRepositories(isInitialLoad: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_repositories.isEmpty) {
      return const Center(child: Text('No repositories found.'));
    } else {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('読み込み済み: ${_repositories.length}件'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _repositories.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _repositories.length) {
                  final repo = _repositories[index];
                  final updatedAt = repo['pushed_at'] != null
                      ? DateTime.tryParse(repo['pushed_at'])
                      : null;
                  final formattedDate = updatedAt != null
                      ? 'Updated: ${updatedAt.toLocal().toString().substring(0, 10)}'
                      : 'No update info';

                  // Add a UniqueKey to each ListTile for efficient list updates
                  return ListTile( 
                    key: ValueKey(repo['id']), // Use repo ID as a unique key
                    leading: const Icon(Icons.book),
                    title: Text(repo['name'] ?? 'No Name'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(repo['description'] ?? 'No description'),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RepositoryDetailPage(
                            repo: repo,
                            githubService: widget.githubService,
                          ),
                        ),
                      ).then((value) {
                        if (value == true) {
                          _refresh();
                        }
                      });
                    },
                  );
                } else {
                  // 末尾にローディングまたは「次のページ」ボタン
                  if (_isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (_hasMore) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _fetchRepositories(),
                        child: const Text('次のページ'),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }
              },
            ),
          ),
        ],
      );
    }
  }
}

class RepositoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> repo;
  final GitHubService githubService;

  const RepositoryDetailPage({super.key, required this.repo, required this.githubService});

  @override
  State<RepositoryDetailPage> createState() => _RepositoryDetailPageState();
}

class _RepositoryDetailPageState extends State<RepositoryDetailPage> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.repo['name'] ?? 'Repository Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.repo['full_name'] ?? 'No full name',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(widget.repo['description'] ?? 'No description available.'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star_border),
                const SizedBox(width: 8),
                Text('${widget.repo['stargazers_count'] ?? 0} stars'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.call_split),
                const SizedBox(width: 8),
                Text('${widget.repo['forks_count'] ?? 0} forks'),
              ],
            ),
             const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.code),
                const SizedBox(width: 8),
                Text(widget.repo['language'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.bug_report),
                const SizedBox(width: 8),
                Text('${widget.repo['open_issues_count'] ?? 0} open issues'),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.repo['owner'] != null && widget.repo['owner']['avatar_url'] != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(widget.repo['owner']['avatar_url']),
                  ),
                const SizedBox(width: 8),
                Text('Owner: ${widget.repo['owner']?['login'] ?? 'N/A'}'),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete This Repository'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _isDeleting
                  ? null
                  : () async {
                      setState(() {
                        _isDeleting = true;
                      });
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Confirm Deletion'),
                            content: Text(
                              'Are you sure you want to delete "${widget.repo['name']}"?\n\nTHIS ACTION CANNOT BE UNDONE.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed == true && context.mounted) {
                        try {
                          await widget.githubService.deleteRepository(widget.repo['full_name']);
                          
                          // Pop the detail page and signal that a deletion happened
                          Navigator.of(context).pop(true);
                          
                          // Show a success message on the list page
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${widget.repo['name']}" was deleted successfully.')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete repository: $e')),
                          );
                        }
                      }
                      setState(() {
                        _isDeleting = false;
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }
}