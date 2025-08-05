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
        scaffoldBackgroundColor: const Color(0xFFF6F8FA), // GitHub background
        primaryColor: const Color(0xFF24292E), // GitHub header
        fontFamily: 'Segoe UI', // A common sans-serif font
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2EA44F), // GitHub green for buttons
          secondary: Color(0xFF0366D6), // GitHub blue for links/accents
          onPrimary: Colors.white,
          surface: Colors.white, // Card background
          onSurface: Color(0xFF24292E), // Main text color
          error: Color(0xFFD73A49), // GitHub red for errors/delete
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF24292E),
          foregroundColor: Colors.white,
          elevation: 0, // Flat app bar
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          )
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2EA44F), // Green button
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0366D6), // Blue link color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF24292E), fontSize: 14),
          bodyMedium: TextStyle(color: Color(0xFF24292E), fontSize: 14),
          bodySmall: TextStyle(color: Color(0xFF586069), fontSize: 12),
          headlineSmall: TextStyle(color: Color(0xFF24292E), fontWeight: FontWeight.w600, fontSize: 24),
          titleLarge: TextStyle(color: Color(0xFF24292E), fontWeight: FontWeight.w600, fontSize: 20),
          titleMedium: TextStyle(color: Color(0xFF24292E), fontWeight: FontWeight.w600, fontSize: 16),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE1E4E8),
          thickness: 1,
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.white,
          shape: Border(
            bottom: BorderSide(color: Color(0xFFE1E4E8), width: 1)
          )
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0xFFD1D5DA)),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        ),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('web/icons/Icon-512.png', width: 80, height: 80),
            const SizedBox(height: 24),
            Text('GitHub Manager', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Sign in to continue', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              onPressed: onLogin,
              label: const Text('Login with GitHub'),
            ),
          ],
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
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _repositories = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int pageNumber) async {
    if (pageNumber < 1) return; // Page numbers must be positive

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fetchedRepos = await widget.githubService.getRepositories(page: pageNumber, perPage: 30);
      if (!mounted) return;

      setState(() {
        _page = pageNumber;
        _repositories = fetchedRepos; // Always replace the list for pagination
        _sortRepositories();
        _hasMore = fetchedRepos.length == 30;
        _isLoading = false;
      });

      // After the new page is rendered, scroll to the top.
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
    return _loadPage(1);
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
            tooltip: 'Logout',
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
            Text('Failed to load repositories: $_error'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadPage(1),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_repositories.isEmpty) {
      return const Center(child: Text('No repositories found.'));
    } else {
      final loadedCount = (_page - 1) * 30 + _repositories.length;

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFD1D5DA)))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$loadedCount results for public repositories',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Page $_page',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: _repositories.length + 1, // +1 for the pagination controls
              itemBuilder: (context, index) {
                if (index < _repositories.length) {
                  final repo = _repositories[index];
                  final updatedAt = repo['pushed_at'] != null
                      ? DateTime.tryParse(repo['pushed_at'])
                      : null;
                  final formattedDate = updatedAt != null
                      ? 'Updated on ${updatedAt.toLocal().toString().substring(0, 10)}'
                      : 'No update info';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD1D5DA)),
                      borderRadius: BorderRadius.circular(6)
                    ),
                    child: ListTile(
                      key: ValueKey(repo['id']),
                      title: Text(repo['name'] ?? 'No Name', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(repo['description'] ?? 'No description'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if(repo['language'] != null) ...[
                                const Icon(Icons.code, size: 16),
                                const SizedBox(width: 4),
                                Text(repo['language'], style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(width: 16),
                              ],
                              const Icon(Icons.star_border, size: 16),
                              const SizedBox(width: 4),
                              Text(repo['stargazers_count'].toString(), style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(width: 16),
                              Text(formattedDate, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RepositoryDetailPage(
                              repo: repo,
                              githubService: widget.githubService,
                            ),
                          ),
                        ).then((result) {
                          if (result is String || result == true) {
                            _refresh();
                          }
                        });
                      },
                    ),
                  );
                } else {
                  // Footer with pagination controls
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_page > 1)
                          TextButton(
                            onPressed: _isLoading ? null : () => _loadPage(_page - 1),
                            child: const Text('‹ Previous'),
                          ),
                        if (_page > 1 && _hasMore) const SizedBox(width: 16),
                        if (_hasMore)
                          TextButton(
                            onPressed: _isLoading ? null : () => _loadPage(_page + 1),
                            child: const Text('Next ›'),
                          ),
                      ],
                    ),
                  );
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.repo['name'] ?? 'Repository Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.repo['full_name'] ?? 'No full name',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(widget.repo['description'] ?? 'No description available.', style: textTheme.bodyLarge),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.repo['owner'] != null && widget.repo['owner']['avatar_url'] != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(widget.repo['owner']['avatar_url']),
                    radius: 16,
                  ),
                const SizedBox(width: 8),
                Text('Owner: ${widget.repo['owner']?['login'] ?? 'N/A'}', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 24),
            Text('Repository Details', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildDetailRow(context, Icons.star_border, '${widget.repo['stargazers_count'] ?? 0} stars'),
            _buildDetailRow(context, Icons.call_split, '${widget.repo['forks_count'] ?? 0} forks'),
            _buildDetailRow(context, Icons.code, widget.repo['language'] ?? 'N/A'),
            _buildDetailRow(context, Icons.bug_report, '${widget.repo['open_issues_count'] ?? 0} open issues'),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text('Danger Zone', style: textTheme.titleLarge?.copyWith(color: colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete This Repository'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onPrimary,
              ),
              onPressed: _isDeleting
                  ? null
                  : () async {
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
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
                                child: const Text('DELETE'),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed != true) return;

                      // Check if the widget is still in the tree after the dialog.
                      if (!context.mounted) return;

                      setState(() { _isDeleting = true; });

                      try {
                        await widget.githubService.deleteRepository(widget.repo['full_name']);
                        
                        // Check again if the widget is still mounted after the async call.
                        if (!context.mounted) return;

                        Navigator.of(context).pop(widget.repo['full_name']);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"${widget.repo['name']}" was deleted successfully.')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete repository: $e')),
                        );
                      } finally {
                         if(context.mounted) {
                          setState(() { _isDeleting = false; });
                         }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
