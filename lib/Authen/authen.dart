import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Homepage/home.dart';
import '../Service/mt_request_api.dart';
import '../Service/theme_provider.dart';

/// Login page responsible for authenticating the user and caching session data.
class Authen extends StatefulWidget {
  const Authen({super.key});

  // Stored auth token after successful login (nullable)
  static String? token;
  // Optional user info populated from login response
  static String? userName;
  static String? division;
  static int? requesterId;
  static int? dpId;
  // Additional fields extracted from login
  static int? lId;
  static String? departmentName;
  static String? loginUsername;

  @override
  State<Authen> createState() => _AuthenState();
}

class _AuthenState extends State<Authen> {
  late double screenWidth, screenHeight;
  bool redEye = true;
  bool isLoading = false;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppTheme.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme.removeListener(_onThemeChanged);
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Rebuild the page when the shared theme toggles.
  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    final isDark = AppTheme.isDarkMode;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF232526), Color(0xFF414345)],
                ),
              )
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB3C7E6),
                    Color(0xFFEFEFEF),
                  ], // ฟ้าอ่อน + เทาอ่อน
                ),
              ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.1),
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                      color: isDark ? const Color(0xFF232526) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.asset(
                        'Images/logojaroonrat.png',
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ระบบแจ้งซ่อม Jaroonrat',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  buildTextField(
                    controller: usernameController,
                    labelText: 'ชื่อผู้ใช้',
                    prefixIcon: Icons.person,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  buildPasswordField(isDark: isDark),
                  const SizedBox(height: 30),
                  // location selection removed
                  buildLoginButton(isDark: isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Styled text field used by both username and password inputs.
  Widget buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    required bool isDark,
  }) {
    return Container(
      width: screenWidth * 0.8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(
            prefixIcon,
            color: isDark ? Colors.lightBlue[200] : Colors.blue,
          ),
          labelText: labelText,
          labelStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF232526) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: isDark ? Colors.lightBlueAccent : Colors.blue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  /// Password input with show/hide toggle to keep the login flow compact.
  Widget buildPasswordField({required bool isDark}) {
    return Container(
      width: screenWidth * 0.8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: passwordController,
        obscureText: redEye,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.lock_outline,
            color: isDark ? Colors.lightBlue[200] : Colors.blue,
          ),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                redEye = !redEye;
              });
            },
            icon: Icon(
              redEye ? Icons.visibility_off : Icons.visibility,
              color: isDark ? Colors.lightBlue[200] : Colors.blue,
            ),
          ),
          labelText: 'รหัสผ่าน',
          labelStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF232526) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: isDark ? Colors.lightBlueAccent : Colors.blue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  /// Login button that reflects the current submitting state.
  Widget buildLoginButton({required bool isDark}) {
    return Container(
      width: screenWidth * 0.6,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.lightBlueAccent.withOpacity(0.2)
                : Colors.blue.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.lightBlueAccent : Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: isLoading ? null : handleLogin,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'เข้าสู่ระบบ',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// Validate credentials, call the login API, and cache the returned session.
  Future<void> handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty) {
      showSnackbar('กรุณากรอก ชื่อผู้ใช้', backgroundColor: Colors.red);
      return;
    }
    if (password.isEmpty) {
      showSnackbar('กรุณากรอก รหัสผ่าน', backgroundColor: Colors.red);
      return;
    }
    setState(() {
      isLoading = true;
    });

    final url = MtRequestApi.uri('/mtrequest/login');
    final body = jsonEncode({'username': username, 'password': password});

    try {
      final response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(MtRequestApi.requestTimeout);

      // Debug: log status and body
      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        String message = 'เข้าสู่ระบบสำเร็จ';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'].toString();
          }

          // Try to extract token and basic user info from common fields
          String? extractedToken;
          String? extractedName;
          String? extractedDivision;

          if (data is Map) {
            // Token candidates
            if (data['token'] != null) {
              extractedToken = data['token'].toString();
            } else if (data['access_token'] != null)
              extractedToken = data['access_token'].toString();
            else if (data['data'] is Map && data['data']['token'] != null) {
              extractedToken = data['data']['token'].toString();
            } else if (data['result'] is Map &&
                data['result']['token'] != null) {
              extractedToken = data['result']['token'].toString();
            }

            // Name candidates
            if (data['name'] != null) {
              extractedName = data['name'].toString();
            } else if (data['username'] != null)
              extractedName = data['username'].toString();
            else if (data['displayName'] != null)
              extractedName = data['displayName'].toString();
            else if (data['data'] is Map && data['data']['name'] != null) {
              extractedName = data['data']['name'].toString();
            } else if (data['user'] is Map && data['user']['name'] != null) {
              extractedName = data['user']['name'].toString();
            }

            // Division / department candidates
            if (data['division'] != null) {
              extractedDivision = data['division'].toString();
            } else if (data['department'] != null)
              extractedDivision = data['department'].toString();
            else if (data['dp'] != null)
              extractedDivision = data['dp'].toString();
            else if (data['data'] is Map && data['data']['division'] != null) {
              extractedDivision = data['data']['division'].toString();
            } else if (data['user'] is Map &&
                data['user']['division'] != null) {
              extractedDivision = data['user']['division'].toString();
            }
          }

          // Try to extract numeric IDs
          try {
            if (data is Map) {
              // requester/user id
              final idCandidates = [
                data['id'],
                data['user_id'],
                data['userId'],
                data['requester_id'],
                data['requesterId'],
                data['data'] is Map ? data['data']['id'] : null,
                data['user'] is Map ? data['user']['id'] : null,
              ];
              for (var c in idCandidates) {
                if (c != null) {
                  final parsed = int.tryParse(c.toString());
                  if (parsed != null) {
                    Authen.requesterId = parsed;
                    debugPrint('Saved requesterId: ${Authen.requesterId}');
                    break;
                  }
                }
              }

              // dp / department id
              final dpCandidates = [
                data['dp_id'],
                data['dpId'],
                data['department_id'],
                data['departmentId'],
                data['dp'],
                data['data'] is Map ? data['data']['dp_id'] : null,
              ];
              for (var c in dpCandidates) {
                if (c != null) {
                  final parsed = int.tryParse(c.toString());
                  if (parsed != null) {
                    Authen.dpId = parsed;
                    debugPrint('Saved dpId: ${Authen.dpId}');
                    break;
                  }
                }
              }
              // l_id / location id candidates
              final lCandidates = [
                data['l_id'],
                data['lId'],
                data['location_id'],
                data['locationId'],
                data['l'],
                data['data'] is Map ? data['data']['l_id'] : null,
                data['user'] is Map ? data['user']['l_id'] : null,
              ];
              for (var c in lCandidates) {
                if (c != null) {
                  final parsed = int.tryParse(c.toString());
                  if (parsed != null) {
                    Authen.lId = parsed;
                    debugPrint('Saved lId: ${Authen.lId}');
                    break;
                  }
                }
              }

              // department_name candidates
              final deptNameCandidates = [
                data['department_name'],
                data['departmentName'],
                data['dept_name'],
                data['deptName'],
                data['department'],
                data['data'] is Map ? data['data']['department_name'] : null,
                data['user'] is Map ? data['user']['department_name'] : null,
              ];
              for (var c in deptNameCandidates) {
                if (c != null && c.toString().trim().isNotEmpty) {
                  Authen.departmentName = c.toString();
                  debugPrint('Saved departmentName: ${Authen.departmentName}');
                  break;
                }
              }
            }
          } catch (_) {}

          if (extractedToken != null && extractedToken.isNotEmpty) {
            Authen.token = extractedToken;
            debugPrint('Saved auth token: ${Authen.token}');
          }
          if (extractedName != null && extractedName.isNotEmpty) {
            Authen.userName = extractedName;
            debugPrint('Saved user name: ${Authen.userName}');
          }
          if (extractedDivision != null && extractedDivision.isNotEmpty) {
            Authen.division = extractedDivision;
            debugPrint('Saved division: ${Authen.division}');
          }
          // Save the raw login username (from login form)
          if (username.isNotEmpty) {
            Authen.loginUsername = username;
            debugPrint('Saved loginUsername: ${Authen.loginUsername}');
          }
          // Debug: print extracted/saved auth info and full parsed response
          debugPrint(
            'Login saved values: token=${Authen.token}, userName=${Authen.userName}, division=${Authen.division}, requesterId=${Authen.requesterId}, dpId=${Authen.dpId}, lId=${Authen.lId}, departmentName=${Authen.departmentName}, loginUsername=${Authen.loginUsername}',
          );
          try {
            debugPrint('Login parsed data: ${jsonEncode(data)}');
          } catch (_) {
            debugPrint('Login parsed data (raw): $data');
          }
        } catch (_) {}

        showSnackbar(message, backgroundColor: Colors.green);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PurchaseReportPage()),
          );
        }
      } else {
        String error = 'เข้าสู่ระบบไม่สำเร็จ (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['error'] != null) {
            error = data['error'].toString();
          }
        } catch (_) {}
        showSnackbar(error, backgroundColor: Colors.red);
      }
    } catch (e) {
      showSnackbar('ข้อผิดพลาด: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showSnackbar(String message, {Color backgroundColor = Colors.blue}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }
}
