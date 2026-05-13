import 'dart:convert';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // ⬅ NEW
import 'amplifyconfiguration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AmplifyAuthCognito authPlugin = AmplifyAuthCognito();
  final AmplifyAPI apiPlugin = AmplifyAPI();

  try {
    if (!Amplify.isConfigured) {
      Amplify.addPlugins([authPlugin, apiPlugin]);
      await Amplify.configure(amplifyconfig);
      debugPrint("✅ Successfully configured Amplify");
    }
  } catch (e) {
    debugPrint("❌ Could not configure Amplify: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CysecAgri',
      theme: ThemeData(primarySwatch: Colors.red),
      home: SignInPage(),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSignedInStatus();
  }

  Future<void> _checkSignedInStatus() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      debugPrint('[SignIn] isSignedIn = ${session.isSignedIn}');
      if (session.isSignedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DevicesPage()),
        );
      }
    } catch (e) {
      debugPrint("Error checking signed in status: $e");
    }
  }

  void _signIn() async {
    try {
      final res = await Amplify.Auth.signIn(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      debugPrint('[SignIn] result isSignedIn = ${res.isSignedIn}');
      if (res.isSignedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DevicesPage()),
        );
      } else {
        debugPrint("Sign in failed – additional steps required.");
      }
    } on UserNotConfirmedException catch (_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ConfirmUserPage(username: _usernameController.text.trim()),
        ),
      );
    } catch (e) {
      debugPrint("Could not sign in: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CysecAgri Sign In')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              ElevatedButton(onPressed: _signIn, child: const Text('Sign In')),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                ),
                child: const Text("Don't have an account? Sign up"),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ForgotPasswordPage()),
                ),
                child: const Text("Forgot Password?"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _usernameController = TextEditingController();

  void _resetPassword() async {
    try {
      await Amplify.Auth.resetPassword(
        username: _usernameController.text.trim(),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ConfirmResetCodePage(username: _usernameController.text.trim()),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to reset password")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration:
                  const InputDecoration(labelText: "Username or Email"),
            ),
            ElevatedButton(
              onPressed: _resetPassword,
              child: const Text("Send Reset Code"),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmResetCodePage extends StatefulWidget {
  final String username;

  const ConfirmResetCodePage({Key? key, required this.username}) : super(key: key);

  @override
  _ConfirmResetCodePageState createState() => _ConfirmResetCodePageState();
}

class _ConfirmResetCodePageState extends State<ConfirmResetCodePage> {
  final TextEditingController _confirmationCodeController =
      TextEditingController();

  void _navigateToNewPasswordPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewPasswordPage(
          username: widget.username,
          confirmationCode: _confirmationCodeController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Confirmation Code")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _confirmationCodeController,
              decoration:
                  const InputDecoration(labelText: "Confirmation Code"),
            ),
            ElevatedButton(
              onPressed: _navigateToNewPasswordPage,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

class NewPasswordPage extends StatefulWidget {
  final String username;
  final String confirmationCode;

  const NewPasswordPage(
      {Key? key, required this.username, required this.confirmationCode})
      : super(key: key);

  @override
  _NewPasswordPageState createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  Future<void> _confirmResetPassword() async {
    if (_newPasswordController.text == _confirmNewPasswordController.text) {
      try {
        await Amplify.Auth.confirmResetPassword(
          username: widget.username,
          newPassword: _newPasswordController.text.trim(),
          confirmationCode: widget.confirmationCode,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset successful")),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (e) {
        debugPrint('Error confirming password reset: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to confirm password reset")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set New Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: "New Password"),
              obscureText: true,
            ),
            TextField(
              controller: _confirmNewPasswordController,
              decoration:
                  const InputDecoration(labelText: "Confirm New Password"),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: _confirmResetPassword,
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _toast('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!Amplify.isConfigured) {
        _toast('Amplify not configured. Restart the app and check logs.');
        return;
      }

      debugPrint('[SignUp] Calling Amplify.Auth.signUp for "$username"...');
      final res = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: CognitoSignUpOptions(
          userAttributes: {CognitoUserAttributeKey.email: email},
        ),
      );
      debugPrint('[SignUp] Result: $res');

      final delivery = res.nextStep.codeDeliveryDetails;
      final destination = delivery?.destination ?? email;
      final medium = delivery?.deliveryMedium != null
          ? delivery!.deliveryMedium.toString().split('.').last
          : 'email';
      final where = '$destination ($medium)';

      _toast('Verification code sent to $where');

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => ConfirmUserPage(username: username)),
        );
      });
    } on UsernameExistsException {
      _toast('An account with this username already exists');
    } on InvalidPasswordException catch (e) {
      _toast('Invalid password: ${e.message}');
    } on InvalidParameterException catch (e) {
      _toast('Invalid input: ${e.message}');
    } on AuthException catch (e) {
      _toast('Sign up failed: ${e.message}');
      debugPrint('[SignUp][AuthException] $e');
    } catch (e) {
      _toast('Sign up failed: $e');
      debugPrint('[SignUp][Unknown] $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _signUp(),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signUp, child: const Text('Sign Up')),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfirmUserPage extends StatefulWidget {
  final String username;

  const ConfirmUserPage({Key? key, required this.username}) : super(key: key);

  @override
  _ConfirmUserPageState createState() => _ConfirmUserPageState();
}

class _ConfirmUserPageState extends State<ConfirmUserPage> {
  final TextEditingController _confirmationCodeController =
      TextEditingController();

  Future<void> _confirmSignUp() async {
    try {
      final res = await Amplify.Auth.confirmSignUp(
        username: widget.username,
        confirmationCode: _confirmationCodeController.text.trim(),
      );

      if (res.isSignUpComplete) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SignInPage()),
          ModalRoute.withName('/'),
        );
      } else {
        debugPrint(
            "Confirmation not complete, additional steps required. Result: $res");
      }
    } catch (e) {
      debugPrint("Could not confirm sign up: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to confirm sign up')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Account")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _confirmationCodeController,
              decoration:
                  const InputDecoration(labelText: "Confirmation Code"),
            ),
            ElevatedButton(
              onPressed: _confirmSignUp,
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔗 Farm advisor endpoint (FastAPI / later Lambda+API Gateway)
const String farmAdvisorMultiEndpoint = 'http://127.0.0.1:8000/farm-advice/multi';
const String farm3ReadingsEndpoint = 'http://127.0.0.1:8000/farm3/readings';
const String farm4ReadingsEndpoint = 'http://127.0.0.1:8000/farm4/readings';
const String farm5ReadingsEndpoint = 'http://127.0.0.1:8000/farm5/readings';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  _DevicesPageState createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late Future<Map<String, String>> deviceNames;

  @override
  void initState() {
    super.initState();
    deviceNames = getDeviceNames();
  }

  Future<Map<String, String>> getDeviceNames() async {
    final prefs = await SharedPreferences.getInstance();

    final devices = prefs.getKeys().fold<Map<String, String>>({}, (map, key) {
      final value = prefs.getString(key);
      if (value != null) map[key] = value;
      return map;
    });

    // ✅ Always include dataset-backed farms without requiring registration.
    devices.putIfAbsent("farm3_dataset", () => "Farm 3");
    devices.putIfAbsent("farm4_dataset", () => "Farm 4");
    devices.putIfAbsent("farm5_dataset", () => "Farm 5");

    final order = <String, int>{
      'Farm-1': 1,
      'Farm-2': 2,
      'Farm 3': 3,
      'Farm 4': 4,
      'Farm 5': 5,
    };

    final entries = devices.entries.toList()
      ..sort((a, b) {
        final aRank = order[a.value] ?? 999;
        final bRank = order[b.value] ?? 999;
        if (aRank != bRank) return aRank.compareTo(bRank);
        return a.value.toLowerCase().compareTo(b.value.toLowerCase());
      });

    return Map<String, String>.fromEntries(entries);
  }

  void refreshDeviceList() {
    setState(() {
      deviceNames = getDeviceNames();
    });
  }

  Future<void> _deleteDevice(String deviceId) async {
    // Prevent deleting built-in dataset farms.
    if ({"farm3_dataset", "farm4_dataset", "farm5_dataset"}.contains(deviceId)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(deviceId);
    refreshDeviceList();
  }

  Future<void> _signOut() async {
    try {
      await Amplify.Auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInPage()),
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Devices"),
        actions: [
  IconButton(
    icon: const Icon(Icons.forum),
    tooltip: 'Global Farm Advisor',
    onPressed: () async {
      final devices = await deviceNames;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GlobalFarmAdvisorPage(devices: devices),
        ),
      );
    },
  ),
  IconButton(
    icon: const Icon(Icons.dashboard),
    tooltip: 'Dashboard',
    onPressed: () async {
      final devices = await deviceNames;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(devices: devices),
        ),
      );
    },
  ),
  IconButton(
    icon: const Icon(Icons.add),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterDevicePage()),
    ),
  ),
  IconButton(
    icon: const Icon(Icons.refresh),
    onPressed: refreshDeviceList,
    tooltip: 'Refresh Device List',
  ),
  IconButton(
    icon: const Icon(Icons.exit_to_app),
    onPressed: _signOut,
    tooltip: 'Sign Out',
  ),
],

      ),
      body: FutureBuilder<Map<String, String>>(
        future: deviceNames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            final devices = snapshot.data!;
            if (devices.isEmpty) {
              return const Center(child: Text('No devices registered yet'));
            }
            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                String key = devices.keys.elementAt(index);
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(devices[key]!),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FetchDataPage(deviceId: key),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteDevice(key),
                      color: Colors.red,
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text('Failed to load devices'));
          }
        },
      ),
    );
  }
}

class RegisterDevicePage extends StatefulWidget {
  const RegisterDevicePage({super.key});

  @override
  _RegisterDevicePageState createState() => _RegisterDevicePageState();
}

class _RegisterDevicePageState extends State<RegisterDevicePage> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();

  Future<void> _registerDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _deviceIdController.text.trim();
    final name = _deviceNameController.text.trim();

    if (id.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both ID and name")),
      );
      return;
    }

    if (prefs.getString(id) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Device is already registered")),
      );
    } else {
      await prefs.setString(id, name);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Device registered successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Device")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(labelText: "Device ID"),
            ),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(labelText: "Friendly Name"),
            ),
            ElevatedButton(
              onPressed: _registerDevice,
              child: const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}

class FetchDataPage extends StatefulWidget {
  final String deviceId;

  const FetchDataPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  _FetchDataPageState createState() => _FetchDataPageState();
}

class _FetchDataPageState extends State<FetchDataPage> {
  // All data we’ve loaded so far (across pages)
  List<Map<String, dynamic>> allSensorData = [];

  bool isLoading = false;
  String? errorMessage;
  String? nextToken; // AppSync pagination token

  final ScrollController _scrollController = ScrollController();

  // Pagination UI
  static const int _pageSize = 25;
  int _currentPage = 1; // 1-based

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      allSensorData.clear();
      nextToken = null;
      _currentPage = 1;
    });

    // Built-in dataset farms are served by FastAPI, not Amplify/AppSync.
    if (widget.deviceId == "farm3_dataset") {
      await _fetchFarm3FromBackend();
      return;
    }
    if (widget.deviceId == "farm4_dataset") {
      await _fetchFarm4FromBackend();
      return;
    }
    if (widget.deviceId == "farm5_dataset") {
      await _fetchFarm5FromBackend();
      return;
    }

    await _fetchFromApi(token: null);
  }

  /// Ensure we have enough items to display [targetPage].
  Future<void> _ensurePageLoaded(int targetPage) async {
    final neededItems = targetPage * _pageSize;

    while (allSensorData.length < neededItems && nextToken != null) {
      await _fetchFromApi(token: nextToken);
      if (!mounted) return;
    }

    final maxPage = _maxPageCount();
    if (targetPage > maxPage) {
      targetPage = maxPage;
    }

    setState(() {
      _currentPage = targetPage;
    });
  }

  /// Fetch one chunk from AppSync (up to 25 items).
  Future<void> _fetchFromApi({String? token}) async {
    setState(() => isLoading = true);

    const graphQLDocument = r'''
      query ListTodoTablesFiltered($deviceId: String, $nextToken: String) {
        listTodoTables(
          filter: { device_id: { eq: $deviceId } }
          limit: 25
          nextToken: $nextToken
        ) {
          items {
            id
            timestamp
            device_id
            dev_eui
            temperature
            moisture
            application_id
            gateway_id
            payload
          }
          nextToken
        }
      }
    ''';

    try {
      final operation = Amplify.API.query<String>(
        request: GraphQLRequest<String>(
          document: graphQLDocument,
          variables: {
            'deviceId': widget.deviceId,
            'nextToken': token,
          },
        ),
      );

      final response = await operation.response;

      if (response.data == null) {
        throw const ApiException('No data returned from API');
      }

      final decoded = jsonDecode(response.data!) as Map<String, dynamic>;
      final list = decoded['listTodoTables'] as Map<String, dynamic>?;

      final items = (list?['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final newToken = list?['nextToken'] as String?;

      setState(() {
        allSensorData.addAll(items);

        // Global sort: newest timestamp first
        allSensorData.sort((a, b) {
          final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });

        nextToken = newToken;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      debugPrint('[FetchData][Error] $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _fetchFarm3FromBackend() async {
    try {
      final uri = Uri.parse('$farm3ReadingsEndpoint?limit=200');
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = 'No Farm 3 data found (HTTP ${resp.statusCode}).';
        });
        return;
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final readings = (decoded['readings'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final items = readings.map((r) {
        return {
          'device_id': widget.deviceId,
          'timestamp': r['timestamp'],
          'temperature': r['temperature'],
          'moisture': r['moisture'],
        };
      }).toList();

      setState(() {
        allSensorData = items;
        nextToken = null; // no pagination for dataset
        _currentPage = 1;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load Farm 3 data.';
      });
    }
  }


  Future<void> _fetchFarm4FromBackend() async {
    try {
      final uri = Uri.parse('$farm4ReadingsEndpoint?limit=200');
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = 'No Farm 4 data found (HTTP ${resp.statusCode}).';
        });
        return;
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final readings = (decoded['readings'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final items = readings.map((r) {
        return {
          'device_id': widget.deviceId,
          'timestamp': r['timestamp'],
          'max_temp_f': r['max_temp_f'],
          'min_temp_f': r['min_temp_f'],
          'precip_in': r['precip_in'],
          'avg_rh': r['avg_rh'],
        };
      }).toList();

      setState(() {
        allSensorData = items;
        nextToken = null;
        _currentPage = 1;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load Farm 4 data.';
      });
    }
  }

  Future<void> _fetchFarm5FromBackend() async {
    try {
      final uri = Uri.parse('$farm5ReadingsEndpoint?limit=50');
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = 'No Farm 5 data found (HTTP ${resp.statusCode}).';
        });
        return;
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final readings = (decoded['readings'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final items = readings.map((r) {
        return {
          'device_id': widget.deviceId,
          'timestamp': r['timestamp'],
          'station': r['station'],
          'soil_ph': r['soil_ph'],
          'organic_carbon': r['organic_carbon'],
          'nitrogen': r['nitrogen'],
        };
      }).toList();

      setState(() {
        allSensorData = items;
        nextToken = null;
        _currentPage = 1;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load Farm 5 data.';
      });
    }
  }

  int _maxPageCount() {
    if (allSensorData.isEmpty) return 1;
    return (allSensorData.length / _pageSize).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && allSensorData.isEmpty;
    final hasData = allSensorData.isNotEmpty;

    final maxPage = _maxPageCount();
    final page = _currentPage.clamp(1, maxPage);
    final startIndex = (page - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, allSensorData.length);
    final pageItems =
        (hasData && startIndex < allSensorData.length)
            ? allSensorData.sublist(startIndex, endIndex)
            : <Map<String, dynamic>>[];

    final List<Widget> pageButtons = [];

int windowSize = 3; // how many page numbers to show
int startPage = (page - 1).clamp(1, maxPage);
int endPage = (startPage + windowSize - 1).clamp(1, maxPage);

// adjust window if near end
if (endPage - startPage + 1 < windowSize) {
  startPage = (endPage - windowSize + 1).clamp(1, maxPage);
}

// 🔹 Prev
if (page > 1) {
  pageButtons.add(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: () async {
          await _ensurePageLoaded(page - 1);
        },
        child: const Text('‹ Prev'),
      ),
    ),
  );
}

// 🔹 Page numbers (limited window)
for (int i = startPage; i <= endPage; i++) {
  final isSelected = i == page;

  pageButtons.add(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        onPressed: () async {
          await _ensurePageLoaded(i);
        },
        child: Text(
          '$i',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ),
  );
}

// 🔹 Next
if (page < maxPage || nextToken != null) {
  pageButtons.add(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: () async {
          await _ensurePageLoaded(page + 1);
        },
        child: const Text('Next ›'),
      ),
    ),
  );
}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadInitial,
          ),
        ],
      ),
      body: isLoading && !hasData && !hasError
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(child: Text(errorMessage!))
              : Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        interactive: true,
                        thickness: 6,
                        radius: const Radius.circular(8),
                        child: ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: pageItems.length,
                            itemBuilder: (context, index) {
                              final item = pageItems[index];

                              final deviceId =
                                  item['device_id']?.toString() ?? 'Unknown';
                              final tsRaw =
                                  item['timestamp']?.toString() ?? 'Unknown time';

                              String details;
                              if (deviceId == 'farm4_dataset') {
                                final maxTemp = item['max_temp_f']?.toString() ?? 'N/A';
                                final minTemp = item['min_temp_f']?.toString() ?? 'N/A';
                                final precip = item['precip_in']?.toString() ?? 'N/A';
                                final avgRh = item['avg_rh']?.toString() ?? 'N/A';
                                details = 'Max Temp: $maxTemp, Min Temp: $minTemp\n'
                                          'Precip: $precip, Humidity: $avgRh';
                              } else if (deviceId == 'farm5_dataset') {
                                final station = item['station']?.toString() ?? 'N/A';
                                final soilPh = item['soil_ph']?.toString() ?? 'N/A';
                                final organicCarbon = item['organic_carbon']?.toString() ?? 'N/A';
                                final nitrogen = item['nitrogen']?.toString() ?? 'N/A';
                                details = 'Station: $station\n'
                                          'Soil pH: $soilPh, Organic Carbon: $organicCarbon, Nitrogen: $nitrogen';
                              } else {
                                final temp = item['temperature']?.toString() ?? 'N/A';
                                final moisture = item['moisture']?.toString() ?? 'N/A';
                                details = 'Temp: $temp, Moisture: $moisture';
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: ListTile(
                                  title: Text('Device ID: $deviceId'),
                                  subtitle: Text(
                                    'Time: $tsRaw\n'
                                    '$details',
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(children: pageButtons),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
    );
  }
}


// -----------------------------------------------------------------------------
// GLOBAL FARM ADVISOR CHAT PAGE (single chatbot across devices)
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// DASHBOARD PAGE (Option 2): Metrics + Risk level across devices
// -----------------------------------------------------------------------------
class DashboardPage extends StatefulWidget {
  final Map<String, String> devices; // deviceId -> friendlyName
  const DashboardPage({Key? key, required this.devices}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;

  // Computed metrics per device
  final List<_DeviceMetrics> _metrics = [];

  // Settings
  final int _perDeviceLimit = 30; // readings per device
  final Duration _trendWindow = const Duration(hours: 12);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _fetchLatestReadingsForDevice(
  String deviceId, {
  int limit = 30,
}) async {
  // ✅ Farm 3 dataset comes from FastAPI (not Amplify/AppSync)
  if (deviceId == "farm3_dataset") {
    final capped = limit > 15 ? 15 : limit;
    final resp = await http.get(Uri.parse('$farm3ReadingsEndpoint?limit=$capped'));
    if (resp.statusCode != 200) return [];
    final decoded =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final readings = (decoded['readings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    readings.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return readings.take(capped).toList();
  }
  if (deviceId == "farm4_dataset") {
    final capped = limit > 14 ? 14 : limit;
    final resp = await http.get(Uri.parse('$farm4ReadingsEndpoint?limit=$capped'));
    if (resp.statusCode != 200) return [];
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final readings = (decoded['readings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    readings.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return readings.take(capped).toList();
  }
  if (deviceId == "farm5_dataset") {
    final resp = await http.get(Uri.parse('$farm5ReadingsEndpoint?limit=1'));
    if (resp.statusCode != 200) return [];
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final readings = (decoded['readings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    readings.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return readings;
  }

  const graphQLDocument = r'''
    query ListTodoTablesFiltered($deviceId: String, $nextToken: String) {
      listTodoTables(
        filter: { device_id: { eq: $deviceId } }
        limit: 25
        nextToken: $nextToken
      ) {
        items {
          timestamp
          device_id
          temperature
          moisture
        }
        nextToken
      }
    }
  ''';

  List<Map<String, dynamic>> collected = [];
  String? token;

  while (collected.length < limit) {
    final operation = Amplify.API.query<String>(
      request: GraphQLRequest<String>(
        document: graphQLDocument,
        variables: {
          'deviceId': deviceId,
          'nextToken': token,
        },
      ),
    );

    final response = await operation.response;
    if (response.data == null) break;

    final decoded = jsonDecode(response.data!) as Map<String, dynamic>;
    final list = decoded['listTodoTables'] as Map<String, dynamic>?;

    final items =
        (list?['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    token = list?['nextToken'] as String?;

    collected.addAll(items);
    if (token == null) break;
  }

  collected.sort((a, b) {
    final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });

  if (collected.length > limit) collected = collected.take(limit).toList();
  return collected;
}


  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _metrics.clear();
    });

    try {
      final ids = widget.devices.keys.toList();
      final results = await Future.wait(
        ids.map((id) => _fetchLatestReadingsForDevice(id, limit: _perDeviceLimit)),
      );

      for (int i = 0; i < ids.length; i++) {
        final deviceId = ids[i];
        final readings = results[i];

        final m = _computeMetrics(
          deviceId: deviceId,
          friendlyName: widget.devices[deviceId] ?? deviceId,
          readings: readings,
          trendWindow: _trendWindow,
        );
        _metrics.add(m);
      }

      // Sort most urgent first: high risk, then lowest moisture
      _metrics.sort((a, b) {
        final prA = _riskPriority(a.risk);
        final prB = _riskPriority(b.risk);
        if (prA != prB) return prB.compareTo(prA);
        return (a.latestMoisture ?? 9999).compareTo(b.latestMoisture ?? 9999);
      });

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Failed to load dashboard: $e";
      });
    }
  }

  int _riskPriority(String risk) {
    switch (risk) {
      case 'HIGH':
        return 3;
      case 'WATCH':
      case 'MEDIUM':
        return 2;
      default:
        return 1;
    }
  }

  double _clamp(double x, [double lo = 0.0, double hi = 1.0]) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

String _riskLabel(double score) {
  if (score >= 0.66) return 'HIGH';
  if (score >= 0.33) return 'MEDIUM';
  return 'LOW';
}

double _riskScore(double? latestMoist, double? latestTemp, double? dryingRatePerHr) {
  // Dryness: 0 at >=40%, 1 at <=20% (with trend penalty if drying fast)
  double dryness = 0.5;
  if (latestMoist != null) {
    dryness = _clamp((40.0 - latestMoist) / 20.0);
  }
  double trendAdj = 0.0;
  if (dryingRatePerHr != null && dryingRatePerHr < -1.0) {
    trendAdj = _clamp(dryingRatePerHr.abs() / 5.0, 0.0, 0.3);
  }
  dryness = _clamp(dryness + trendAdj);

  // Heat: 0 at <=30C, 1 at >=40C
  double heat = 0.3;
  if (latestTemp != null) {
    heat = _clamp((latestTemp - 30.0) / 10.0);
  }

  return _clamp(0.6 * dryness + 0.4 * heat);
}


  _DeviceMetrics _computeMetrics({
    required String deviceId,
    required String friendlyName,
    required List<Map<String, dynamic>> readings,
    required Duration trendWindow,
  }) {
    if (readings.isEmpty) {
      return _DeviceMetrics(
        deviceId: deviceId,
        friendlyName: friendlyName,
        latestMoisture: null,
        latestTemp: null,
        moistureChange: null,
        dryingRatePerHr: null,
        tempAvg: null,
        risk: 'WATCH',
        riskScore: 0.5,
      );
    }

    // readings assumed newest-first
    double? latestMoist = _toDouble(readings.first['moisture']);
    double? latestTemp = _toDouble(readings.first['temperature']);
    final now = DateTime.tryParse(readings.first['timestamp']?.toString() ?? '') ?? DateTime.now();
    final cutoff = now.subtract(trendWindow);

    // Find a reading near the cutoff
    Map<String, dynamic>? past;
    for (final r in readings) {
      final ts = DateTime.tryParse(r['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      if (ts.isBefore(cutoff) || ts.isAtSameMomentAs(cutoff)) {
        past = r;
        break;
      }
    }
    final pastMoist = past == null ? null : _toDouble(past['moisture']);

    double? change;
    double? rate;
    if (latestMoist != null && pastMoist != null) {
      change = latestMoist - pastMoist;
      final dtHrs = trendWindow.inMinutes / 60.0;
      if (dtHrs > 0) rate = change / dtHrs; // % per hour
    }

    // temp avg over window (use available temps in window)
    final temps = <double>[];
    for (final r in readings) {
      final ts = DateTime.tryParse(r['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      if (ts.isBefore(cutoff)) break;
      final t = _toDouble(r['temperature']);
      if (t != null) temps.add(t);
    }
    final tempAvg = temps.isEmpty ? null : (temps.reduce((a, b) => a + b) / temps.length);

    final scoreVal = _riskScore(latestMoist, latestTemp, rate);
    final risk = _riskLabel(scoreVal);

    return _DeviceMetrics(
      deviceId: deviceId,
      friendlyName: friendlyName,
      latestMoisture: latestMoist,
      latestTemp: latestTemp,
      moistureChange: change,
      dryingRatePerHr: rate,
      tempAvg: tempAvg,
      risk: risk,
      riskScore: scoreVal,
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Color _riskColor(String r) {
    switch (r) {
      case 'HIGH':
        return Colors.red;
      case 'WATCH':
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _fmtNum(double? v, {int decimals = 1, String na = 'N/A'}) {
    if (v == null) return na;
    return v.toStringAsFixed(decimals);
  }

  String _fmtSigned(double? v, {int decimals = 1, String na = 'N/A'}) {
    if (v == null) return na;
    final s = v >= 0 ? '+' : '';
    return '$s${v.toStringAsFixed(decimals)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _metrics.isEmpty
                  ? const Center(child: Text('No devices / data yet'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _DashboardHeader(
                          perDeviceLimit: _perDeviceLimit,
                          hours: _trendWindow.inHours,
                        ),
                        const SizedBox(height: 12),
                        ..._metrics.map((m) => _DeviceMetricCard(
                              metrics: m,
                              riskColor: _riskColor(m.risk),
                              fmtNum: _fmtNum,
                              fmtSigned: _fmtSigned,
                            )),
                        const SizedBox(height: 12),
                        const _DashboardFooter(),
                      ],
                    ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final int perDeviceLimit;
  final int hours;

  const _DashboardHeader({
    Key? key,
    required this.perDeviceLimit,
    required this.hours,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Farm Health Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Using fast cached summaries • Last $perDeviceLimit rows per active farm • Trend window: last $hours hours'),
            const SizedBox(height: 8),
            const Text(
              'Tip: Group 1 prompts are for immediate field decisions. Group 2 prompts are for deeper agronomy insight.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardFooter extends StatelessWidget {
  const _DashboardFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: Text(
        'Risk is a quick decision aid built from moisture level, drying trend, and temperature. '
        'Use the advisor prompts for the agronomist-style interpretation.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _DeviceMetricCard extends StatelessWidget {
  final _DeviceMetrics metrics;
  final Color riskColor;
  final String Function(double?, {int decimals, String na}) fmtNum;
  final String Function(double?, {int decimals, String na}) fmtSigned;

  const _DeviceMetricCard({
    Key? key,
    required this.metrics,
    required this.riskColor,
    required this.fmtNum,
    required this.fmtSigned,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrics.friendlyName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: riskColor.withOpacity(0.6)),
                  ),
                  child: Text(
                    metrics.risk,
                    style: TextStyle(color: riskColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Device: ${metrics.deviceId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Moisture',
                    value: metrics.latestMoisture == null ? 'N/A' : '${fmtNum(metrics.latestMoisture)}%',
                    sub: 'Δ (window): ${fmtSigned(metrics.moistureChange)}%',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Drying rate',
                    value: metrics.dryingRatePerHr == null ? 'N/A' : '${fmtSigned(metrics.dryingRatePerHr)}%/hr',
                    sub: 'Lower = drying faster',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Temperature',
                    value: metrics.latestTemp == null ? 'N/A' : '${fmtNum(metrics.latestTemp)}°C',
                    sub: 'Avg: ${fmtNum(metrics.tempAvg)}°C',
                  ),
                ),
                Expanded(
                  child: _RiskLevelTile(riskScore: metrics.riskScore),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _MetricTile({
    Key? key,
    required this.label,
    required this.value,
    required this.sub,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(sub, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RiskLevelTile extends StatelessWidget {
  final double riskScore; // 0..1
  const _RiskLevelTile({Key? key, required this.riskScore}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pct = (riskScore * 100).round();
    final label = riskScore >= 0.66 ? 'HIGH' : (riskScore >= 0.33 ? 'MEDIUM' : 'LOW');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Risk level', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: riskScore.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.withOpacity(0.25),
          ),
        ),
        const SizedBox(height: 6),
        Text('$label • $pct%', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DeviceMetrics {
  final String deviceId;
  final String friendlyName;

  final double? latestMoisture;
  final double? latestTemp;

  final double? moistureChange; // over window
  final double? dryingRatePerHr; // change per hour

  final double? tempAvg; // avg in window

  final String risk; // GOOD / WATCH / HIGH
  final double riskScore; // 0..1

  _DeviceMetrics({
    required this.deviceId,
    required this.friendlyName,
    required this.latestMoisture,
    required this.latestTemp,
    required this.moistureChange,
    required this.dryingRatePerHr,
    required this.tempAvg,
    required this.risk,
    required this.riskScore,
  });
}

class GlobalFarmAdvisorPage extends StatefulWidget {
  final Map<String, String> devices; // deviceId -> friendlyName

  const GlobalFarmAdvisorPage({Key? key, required this.devices}) : super(key: key);

  @override
  State<GlobalFarmAdvisorPage> createState() => _GlobalFarmAdvisorPageState();
}

class _GlobalFarmAdvisorPageState extends State<GlobalFarmAdvisorPage> {
  final List<_ChatMessage> _messages = [];
  final ScrollController _chatScrollController = ScrollController();

  final Set<String> _selectedDeviceIds = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    // Default: select all registered devices
    _selectedDeviceIds.addAll(widget.devices.keys.where((id) => id != "farm3_dataset"));

    _messages.add(
      _ChatMessage(
        fromUser: false,
        text:
            "Hi 👋 I'm your farm advisor.\n"
            "I can compare live farms and dataset-backed farms with a practical agronomy view.\n\n"
            "Select one or more farms above, then tap one of the five prompts below.",
      ),
    );
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    super.dispose();
  }

  String _normalizeAnswer(String text) {
    return text
        .replaceAll('Â°C', '°C')
        .replaceAll('deg C', '°C')
        .replaceAll('Deg C', '°C');
  }

  Future<List<Map<String, dynamic>>> _fetchLatestReadingsForDevice(String deviceId,
      {int limit = 30}) async {
    // Farm 3 dataset is served by the FastAPI backend (CSV), not Amplify/AppSync.
    // Also cap to 15 to keep the LLM prompt smaller and faster.
    if (deviceId == "farm3_dataset") {
      final effectiveLimit = limit > 15 ? 15 : limit;
      final uri = Uri.parse('$farm3ReadingsEndpoint?limit=$effectiveLimit');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final readings = (decoded['readings'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Normalize to the same shape as AppSync items
      return readings.map((r) {
        return {
          'timestamp': r['timestamp'],
          'device_id': deviceId,
          'temperature': r['temperature'],
          'moisture': r['moisture'],
        };
      }).toList();
    }

    const graphQLDocument = r'''
      query ListTodoTablesFiltered($deviceId: String, $nextToken: String) {
        listTodoTables(
          filter: { device_id: { eq: $deviceId } }
          limit: 25
          nextToken: $nextToken
        ) {
          items {
            timestamp
            device_id
            temperature
            moisture
          }
          nextToken
        }
      }
    ''';

    List<Map<String, dynamic>> collected = [];
    String? token;

    while (collected.length < limit) {
      final operation = Amplify.API.query<String>(
        request: GraphQLRequest<String>(
          document: graphQLDocument,
          variables: {'deviceId': deviceId, 'nextToken': token},
        ),
      );

      final response = await operation.response;
      if (response.data == null) break;

      final decoded = jsonDecode(response.data!) as Map<String, dynamic>;
      final list = decoded['listTodoTables'] as Map<String, dynamic>?;

      final items =
          (list?['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      token = list?['nextToken'] as String?;

      collected.addAll(items);
      if (token == null) break;
    }

    collected.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    return collected.take(limit).toList();
  }

  Future<void> _sendPrompt(String promptId, String userLabel) async {
    if (_isSending) return;

    if (_selectedDeviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one farm')),
      );
      return;
    }

    setState(() {
      // Show what the farmer tapped as their “question”
      _messages.add(_ChatMessage(fromUser: true, text: userLabel));
      _isSending = true;
    });

    try {
      // Keep a stable order so Farm 1/Farm 2 is consistent
      final selected = _selectedDeviceIds.toList()..sort();

      // Build farmer-friendly labels
      final Map<String, String> farmLabels = {};
      for (int i = 0; i < selected.length; i++) {
        farmLabels[selected[i]] = widget.devices[selected[i]] ?? 'Farm ${i + 1}';
      }

      final results = await Future.wait(
        selected.map((id) => _fetchLatestReadingsForDevice(id, limit: 30)),
      );

      final Map<String, dynamic> readingsByDevice = {};
      for (int i = 0; i < selected.length; i++) {
        final deviceId = selected[i];
        final readings = results[i];
        readingsByDevice[deviceId] = readings
            .map((r) => {
                  'timestamp': r['timestamp'],
                  'temperature': r['temperature'],
                  'moisture': r['moisture'],
                })
            .toList();
      }

      final payload = {
        'device_ids': selected,
        'farm_labels': farmLabels,
        'prompt_id': promptId,
        // Optional: we send the button label as “question”
        'question': userLabel,
        'readings_by_device': readingsByDevice,
      };

      final resp = await http.post(
        Uri.parse(farmAdvisorMultiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode != 200) {
        throw Exception('Advisor error: HTTP ${resp.statusCode} ${resp.body}');
      }

      final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final rawAnswer = body['answer']?.toString() ?? 'No answer received.';
      final answer = _normalizeAnswer(rawAnswer);

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(fromUser: false, text: answer));
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('[GlobalFarmAdvisor] Error: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            fromUser: false,
            text: 'Sorry, I could not contact the advisor service.\nError: $e',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final deviceChips = widget.devices.entries.map((e) {
      final id = e.key;
      final name = e.value;
      final selected = _selectedDeviceIds.contains(id);

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(name),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedDeviceIds.add(id);
              } else {
                _selectedDeviceIds.remove(id);
              }
            });
          },
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Global Farm Advisor')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: deviceChips),
          ),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              controller: _chatScrollController,
              thumbVisibility: true,
              interactive: true,
              thickness: 6,
              radius: const Radius.circular(8),
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final alignment =
                      msg.fromUser ? Alignment.centerRight : Alignment.centerLeft;
                  final bubbleColor =
                      msg.fromUser ? Colors.green[100] : Colors.grey[300];

                  return Align(
                    alignment: alignment,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg.text),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSending)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE0B2),
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendPrompt('IMMEDIATE_IRRIGATION', 'Should I irrigate now?'),
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('Immediate Irrigation Decision'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE0B2),
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendPrompt('HEAT_STRESS_ALERT', 'Is my crop under heat stress right now?'),
                        icon: const Icon(Icons.thermostat_outlined),
                        label: const Text('Heat Stress Alert'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF9C4),
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendPrompt('YIELD_IMPACT', 'How will current conditions affect yield?'),
                        icon: const Icon(Icons.query_stats_outlined),
                        label: const Text('Yield Impact Prediction'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF9C4),
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendPrompt('CROP_RESPONSE', 'How is my crop responding to changing conditions?'),
                        icon: const Icon(Icons.timeline_outlined),
                        label: const Text('Crop Response Analysis'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF9C4),
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendPrompt('SOIL_NUTRIENT', 'Is soil limiting my crop performance?'),
                        icon: const Icon(Icons.grass_outlined),
                        label: const Text('Soil & Nutrient Insight'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String text;

  _ChatMessage({required this.fromUser, required this.text});
}
