import 'dart:math';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'file_classifier.dart';
import 'cng_container_builder.dart';
import 'cng_models.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCcDfWlW0q0QtIuSR--Mc3tA8c3_ydEwxo",
      appId: "1:265129801654:web:e484282f2f1d82f3837317",
      messagingSenderId: "265129801654",
      projectId: "knot-messenger-fe813",
      authDomain: "knot-messenger-fe813.firebaseapp.com",
      storageBucket: "knot-messenger-fe813.firebasestorage.app",
    ),
  );
  runApp(const KnotApp());
}

Future<void> _initCryptoIdentity() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw StateError("User must be authenticated before crypto init");
  }
  final uid = user.uid;
  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

  final firestoreKey = userDoc.data()?['x25519PublicKey'];

  try {
    await EncryptionService.loadIdentityPrivateKey(uid);

    if (firestoreKey != null) {
      debugPrint('Identity already initialized correctly');
      return;
    }
    return;
  } catch (_) {
    debugPrint('Generating new X25519 identity');
  }
  final publicKeyBase64 =
      await EncryptionService.generateAndStoreIdentityKeyPair(uid);

  await FirebaseFirestore.instance.collection('users').doc(uid).set(
    {
      'x25519PublicKey': publicKeyBase64,
      'keyType': 'X25519',
      'createdAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

class KnotApp extends StatelessWidget {
  const KnotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
        ),
        home: const SplashScreen());
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const ContentPage();
        }
        return const LoginPage();
      },
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _controller_one = TextEditingController();
  final TextEditingController _controller_two = TextEditingController();
  final TextEditingController _controller_three = TextEditingController();
  final _keyform = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _checkState() async {
    final formState = _keyform.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _controller_one.text.trim(),
        password: _controller_three.text.trim(),
      );
      String knotID = (10000 + Random().nextInt(90000)).toString();
      await userCredential.user?.updateDisplayName(_controller_two.text.trim());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _controller_two.text.trim(),
        'email': _controller_one.text.trim(),
        'knotID': knotID,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _initCryptoIdentity();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Registration Failed");
    } catch (e) {
      _showError("System Error: $e");
      print("Full Error Debug: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'serif',
              )),
          backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Knot Register Page",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/register_icon.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Container(
              /*width: double.infinity,
    height: double.infinity,
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/register_icon.jpeg'),
        fit: BoxFit.cover,
      ),
    ),*/
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 400,
                      ),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _keyform,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 10),
                                const Text(
                                  "Register",
                                  style: TextStyle(
                                    color: Color(0xffcda325),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                    fontFamily: 'serif',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _controller_one,
                                  decoration: InputDecoration(
                                    filled: true,
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                      color: Colors.teal,
                                    ),
                                    labelText: "Enter Your Email",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Kindly Fill All The Details.";
                                    }
                                    if (!value.contains('@')) {
                                      return "Kindly Enter A Valid Value.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _controller_two,
                                  decoration: InputDecoration(
                                    filled: true,
                                    prefixIcon: const Icon(
                                      Icons.person_outlined,
                                      color: Colors.teal,
                                    ),
                                    labelText: "Enter Your Name",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Kindly Fill All The Details.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _controller_three,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    prefixIcon: const Icon(
                                      Icons.key,
                                      color: Color(0xffea6636),
                                    ),
                                    labelText: "Set Your Password",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Kindly Fill All The Details.";
                                    }
                                    if (value.length < 6 || value.length > 12) {
                                      return "Password must be 6–12 characters.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _checkState,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "Register",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/main_icon.png',
              width: 100,
            ),
            const SizedBox(height: 80),
            const Text(
              "Knot",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
                fontFamily: 'roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _keyform = GlobalKey<FormState>();
  bool _isloading = false;

  Future<void> _updateRoute() async {
    if (!_keyform.currentState!.validate()) {
      return;
    }

    setState(() {
      _isloading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _initCryptoIdentity();

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ContentPage(),
          ));

      setState(() {
        _isloading = false;
      });
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred";
      if (e.code == 'user-not-found')
        message = "No user found for that email.";
      else if (e.code == 'wrong-password') message = "Wrong password provided.";

      _showError(message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
            )),
        backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Knot Login Page",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            )),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/icon.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 400,
                      ),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _keyform,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 10),
                                const Text(
                                  "Login",
                                  style: TextStyle(
                                    color: Color(0xffcda325),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                    fontFamily: 'serif',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                      color: Colors.teal,
                                    ),
                                    labelText: "Enter Your Email",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Kindly Fill All The Fields.";
                                    }
                                    if (!value.contains('@')) {
                                      return "Kindly Enter A Valid Email.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    prefixIcon: const Icon(
                                      Icons.key,
                                      color: Color(0xffea6636),
                                    ),
                                    labelText: "Enter Your Password",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Kindly Fill All The Fields.";
                                    }
                                    if (value.length < 6 || value.length > 12) {
                                      return "Kindly Enter Valid Password";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton(
                                    onPressed: _updateRoute,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isloading
                                        ? const CircularProgressIndicator(
                                            color: Colors.orange,
                                          )
                                        : const Text(
                                            "Login",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Don't Have An Account?",
                                    style: TextStyle(
                                      color: Color(0xff093e69),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xff0f5a12),
          brightness: Brightness.light,
        ),
      ),
      home: const ContentPage(),
    );
  }
}

class ContentPage extends StatefulWidget {
  const ContentPage({super.key});
  final selectedIndex = 0;

  @override
  State<ContentPage> createState() => _ContentPageState(selectedIndex: 0);
}

class _ContentPageState extends State<ContentPage> {
  _ContentPageState({required this.selectedIndex});
  int selectedIndex;
  final List<Widget> tabs = [
    const ChatScreen(),
    const ConversationScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: tabs[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined, color: Colors.blueAccent),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xff05345a)),
            label: "Chats",
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined, color: Colors.blueAccent),
            selectedIcon: Icon(Icons.group, color: Color(0xff05345a)),
            label: "Connections",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.blueAccent),
            selectedIcon: Icon(Icons.person, color: Color(0xff05345a)),
            label: "Profile",
          ),
        ],
        backgroundColor: Colors.white,
        height: 60,
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Knot",
            style: TextStyle(
              color: Color(0xff103553),
              fontWeight: FontWeight.bold,
              fontSize: 32,
              fontFamily: 'roboto',
            ),
          ),
          shadowColor: Colors.blueGrey,
          backgroundColor: Color(0xffc9f4cb),
          toolbarHeight: 56,
          /*leading: Image.asset(
              'assets/main_icon.png',
              width: 20,
            )*/
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(myUid)
                .collection('connections')
                .where('status', isEqualTo: 'connected')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No Active Chats. Connect With Friends To Start"),
                );
              }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String friendUid = doc.id;
                  String friendName = data['name'] ?? "User";

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.black, width: 1.0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade700,
                      child: Text(friendName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(
                      friendName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Tap to start Chatting"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => IndividualChatPage(
                                  receiverUid: friendUid,
                                  receiverName: friendName,
                                )),
                      );
                    },
                  );
                },
              );
            }));
  }
}

class IndividualChatPage extends StatefulWidget {
  final String receiverUid;
  final String receiverName;

  const IndividualChatPage(
      {super.key, required this.receiverUid, required this.receiverName});

  @override
  State<IndividualChatPage> createState() => _IndividualChatPageState();
}

class _IndividualChatPageState extends State<IndividualChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  SecretKey? _aesKey;

  String? _receiverPublicKey;
  late String chatRoomId;

  PlatformFile? _selectedFile;
  String? _selectedRisk;
  bool _isProcessingFile = false;

  late Future<Directory> directoryFuture;
  
  @override
  void initState() {
    super.initState();
    directoryFuture = getApplicationDocumentsDirectory();
    List<String> ids = [_auth.currentUser!.uid, widget.receiverUid];
    ids.sort();
    chatRoomId = ids.join('_');

    _loadKeys();
  }

  List<int>? _aesKeyBytes;
  Future<void> _loadKeys() async {
    final myUid = _auth.currentUser!.uid;
    try {
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverUid)
          .get();

      if (!receiverDoc.exists) {
        throw 'Receiver not found';
      }
      final receiverPublicKey = receiverDoc['x25519PublicKey'];
      final sharedSecret =
          await EncryptionService.deriveSharedSecret(myUid, receiverPublicKey);

      final aesKey = await EncryptionService.deriveAesKey(sharedSecret);
      final aesBytes = await aesKey.extractBytes();
      if (mounted) {
        setState(() {
          _receiverPublicKey = receiverPublicKey;
          _aesKey = aesKey;
          _aesKeyBytes = aesBytes;
        });
      }
    } catch (e) {
      print("KEY DERIVATION ERROR: $e");
    }
  }

  void sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _receiverPublicKey == null ||
        _aesKeyBytes == null) {
      print(
          "Error raised in the sendMessage() function. Cannot send the message, Key loaded: ${_aesKeyBytes != null}");

      if (_aesKeyBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Encryption keys not ready yet")),
        );
      }
      return;
    }

    String plainText = _messageController.text.trim();
    _messageController.clear();

    try {
      String encryptedMsg =
          await EncryptionService.encryptMessage(plainText, _aesKey!);

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': widget.receiverUid,
        'message': encryptedMsg,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Encryption/Sending Error: $e");
    }

    if (_aesKeyBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Encryption keys not ready yet")),
      );
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _isProcessingFile = true;
      });

      try{
      final file = result.files.first;
      final fileName = file.name;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();

      final classification = FileClassifier.classify(fileName);
      final container = CngContainerBuilder.buildContainer(
        originalFileName: fileName,
        fileBytes: bytes,
        classification: classification,
      );

      setState(() {
        _selectedFile = file;
        _selectedRisk = classification.riskLevel.name;
      });
      }
      catch(e){
        print("File processing error $e");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unsupported unsafe file"),
                         backgroundColor: Colors.red,
        );
      }
      finally{
        setState((){
          _isProcessingFile = false;
        });
      }
          
      /*final encryptedContainer =
          await EncryptionService.encryptMessage(container, _aesKey!);

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        "senderId": FirebaseAuth.instance.currentUser!.uid,
        "receiverId": widget.receiverUid,
        "type": "attachment",
        "payload": encryptedContainer,
        "fileName": fileName,
        "riskLevel": classification.riskLevel.name,
        "category": classification.category.name,
        "neutralized": classification.category == FileCategory.programming,
        "timestamp": FieldValue.serverTimestamp(),
      });*/
    }
  }

  Widget _buildMessageBubble(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    if (data['type'] == 'attachment') {
      return _buildAttachmentBubble(data,doc.id);
    }
    bool isMe = data['senderId'] == FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<String>(
      future: EncryptionService.decryptMessage(data['message'], _aesKey!),
      builder: (context, snapshot) {
        String displayMessage = snapshot.data ?? "...";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.teal : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                  ),
                ),
                child: Text(
                  displayMessage,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data['timestamp'] != null
                    ? (data['timestamp'] as Timestamp)
                        .toDate()
                        .toString()
                        .substring(11, 16)
                    : "",
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFullImage(File file){
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:(_){
        return GestureDetector(
          onTap: ()=> Navigator.pop(context),
          child: Stack(
            children:[
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX:10, sigmaY:10),
                child: Container(
                  color:Colors.black.withOpacity(0.6),
                ),
              ),
              Center(
                child: Hero(
                  tag: file.path,
                  child: InteractiveViewer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(file),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isImage(String fileName){
      final ext = fileName.split('.').last.toLowerCase();
      return ['jpg','jpeg','png'].contains(ext);
  }
  
  Widget _buildAttachmentBubble(Map<String, dynamic> data, String messageId) {
    bool isMe = data['senderId'] == _auth.currentUser!.uid;
    Color bgColor;
    Color borderColor;
    Color riskColor = Colors.teal;
    String currentRisk = data['riskLevel'];

    if (data['neutralized'] == true) {
      if (currentRisk == 'high') {
        currentRisk = "medium";
      } else if (currentRisk == "medium") {
        currentRisk = "low";
      }
    }

    switch (currentRisk) {
      case "high":
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade700;
        break;

      case "medium":
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade700;
        break;

      default:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade700;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.60,
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if(_isImage(data['fileName']))
              FutureBuilder(
                future: directoryFuture,
                builder: (context, snapshot){
                  if(!snapshot.hasData) return const SizedBox();

                  final directory = snapshot.data!;
                  final filePath = "${directory.path}/${data['fileName']}";
                  final file = File(filePath);

                  if(!file.existsSync()) return const SizedBox();
        
                  return Column(
                    children:[
                              GestureDetector(
                                onTap: (){
                                  _openFullImage(file);
                                },
                                child: Hero(
                                  tag: file.path,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      file,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          );
                        },
                      ),
              ),
              Text("📎${data['fileName']}"),
              const SizedBox(height: 4),
              Text(
                "Risk:${data['riskLevel'].toUpperCase()}",
                style:
                    TextStyle(color: borderColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(data['neutralized'] ? "Neutralized" : "Not Neutralized"),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () => downloadAttachment(data,messageId),
                child: const Text("Download"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File> _generateThumbnail(File originalFile) async {
    final bytes = await originalFile.readAsBytes();

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 200,
    );

    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final thumbBytes = byteData!.buffer.asUint8List();
    final thumbPath = originalFile.path.replaceAllMapped(
      RegExp(r'\.\w+$'),
      (match) => '_thumb.png',
    );

    final thumbFile = File(thumbPath);
    await thumbFile.writeAsBytes(thumbBytes);

    return thumbFile;
  }
  
  Future<void> downloadAttachment(Map<String, dynamic> data, String messageId) async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Download started")));

      if (_aesKey == null) {
        throw "Encryption key not ready";
      }

      final encryptedContainer = data['payload'];
      final fileName = data['fileName'];

      print("Download button pressed");

      final decryptedContainer =
          await EncryptionService.decryptMessage(encryptedContainer, _aesKey!);

      if(!decryptedContainer.contains("CNG-PAYLOAD") ||
         !decryptedContainer.contains("-----CNG-PAYLOAD-START-----")||
         !decryptedContainer.contains("-----CNG_PAYLOAD-END-----")){
        throw "Invalid container format";
         }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Decryption successful")),
      );

      final mimeType = lookupMimeType(fileName, headerBytes: bytes);
      
      if(_isImage(fileName)){
        if(mimeType == null || !mimeType.startsWith('image\'')){
          throw "Invalid image file";
        }
        if(bytes.length>5*1024*1024){
          throw "Image is too large to process safely";
          setState((){
            _isProcessingFile = false;
          });
        }
      }

      if(!decryptedContainer.contains('CNG-CONTAINER')){
        throw "Invalid container format";
      }
      
      final payload = decryptedContainer
          .split("-----CNG-PAYLOAD-START-----")[1]
          .split("-----CNG-PAYLOAD-END-----")[0]
          .trim();

      print("Downloading file: $fileName");
      print("Category: ${data['category']}");

      late List<int> bytes;
      try{
      if (data['category'] == "programming") {
        bytes = utf8.encode(payload);
      } else {
        bytes = base64Decode(payload);
      }
      }
      catch(e){
        throw "Invalid encoding format";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payload extracted")),
      );

      final mimeType = lookupMimeType(fileName, headerBytes: bytes);
      if(mimeType == null || !mimeType.startsWith("\image")){
        throw "Invalid mime Type";
        setState((){
          _isProcessingFile = false;
        })
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("The file is found to be malicious and cannot be neutralized, hence Restricted to access"),
            backgroundColor: Colors.red.shade700,
            duration: Duration(milliseconds:500),
          );
        ),
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File("${directory.path}/$fileName");

      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "File Downloaded Successfully",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    await FirebaseFirestore.instance
    .collection('chat_rooms')
    .doc(chatRoomId)
    .collection('messages')
    .doc(messageId)
    .update({
  "downloaded": true,
  });
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    } else {
      return "$bytes B";
    }
  }

  Widget _buildCenteredPreview() {
    if (_isProcessingFile) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text("Analyzing & Neutralizing..."),
          ],
        ),
      );
    }

    if (_selectedFile == null && !_isProcessingFile) {
      return const SizedBox();
    }

    Color borderColor;

    switch (_selectedRisk) {
      case "high":
        borderColor = Colors.red;
        break;
      case "medium":
        borderColor = Colors.orange;
        break;
      default:
        borderColor = Colors.green;
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildFilePreview(),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedFile!.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _formatFileSize(_selectedFile!.size),
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "Risk: ${_selectedRisk?.toUpperCase()}",
            style: TextStyle(color: borderColor),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedFile = null;
                    _selectedRisk = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white),
                ),
              ),

              // Send
              ElevatedButton(
                onPressed: sendAttachment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: borderColor,
                ),
                child: const Text(
                  "Send",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    if (_selectedFile == null) return const SizedBox();

    final file = _selectedFile!;
    final ext = file.name.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      if (file.bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            file.bytes!,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        );
      } else if (file.path != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(file.path!),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return _getFileIcon(file.name);
  }

  Icon _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      return const Icon(Icons.image, size: 50, color: Colors.blue);
    } else if (ext == 'pdf') {
      return const Icon(Icons.picture_as_pdf, size: 50, color: Colors.red);
    } else if (['zip', 'rar'].contains(ext)) {
      return const Icon(Icons.archive, size: 50, color: Colors.orange);
    } else if (['mp4', 'mov'].contains(ext)) {
      return const Icon(Icons.video_file, size: 50, color: Colors.purple);
    } else {
      return const Icon(Icons.insert_drive_file, size: 50, color: Colors.grey);
    }
  }

  Future<void> sendAttachment() async {
    if (_selectedFile == null || _aesKey == null) return;

    setState(() {
      _isProcessingFile = true;
    });

    final file = _selectedFile!;
    final newName = file.name;
    final fileName = newName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();

    if(file.size>10*1024*1024){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("File is too large MAX(10 MB)",
                        style: TextStyle(color: Colors.green,
                                        fontWeight: FontWeight.bold),
        ),
          backgroundColor: Colors.yellow,
          duration: Duration(milliseconds: 300),
          setState((){
            _isProcessingFile = false;
            return;
          })
      )
    }
        
    final classification = FileClassifier.classify(fileName);

    final container = CngContainerBuilder.buildContainer(
      originalFileName: fileName,
      fileBytes: bytes,
      classification: classification,
    );

    if(file.size>10*1024*1024){
      throw "File size is too large";
    }
    
    final encryptedContainer =
        await EncryptionService.encryptMessage(container, _aesKey!);

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      "senderId": FirebaseAuth.instance.currentUser!.uid,
      "receiverId": widget.receiverUid,
      "type": "attachment",
      "payload": encryptedContainer,
      "category": classification.category.name,
      "fileName": fileName,
      "riskLevel": _selectedRisk ?? "low",
      "neutralized": true,
      "timestamp": FieldValue.serverTimestamp(),
    });

    setState(() {
      _selectedFile = null;
      _selectedRisk = null;
      _isProcessingFile = false;
    });
  }

  Widget _buildPreviewOverlay() {
    return Positioned.fill(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: 1,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
            Center(
              child: _buildCenteredPreview(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName,
            style: TextStyle(color: Color(0xff0f5011))),
        backgroundColor: Color(0xffffffff),
        shadowColor: Color(0xffb5b1b1),
        actions: [
          Icon(_aesKeyBytes != null ? Icons.lock : Icons.lock_open, size: 18),
          const SizedBox(width: 15),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFFFF6F0),
            child: _aesKeyBytes == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.teal),
                        SizedBox(height: 16),
                        Text("Decrypting Secure Channel..."),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chat_rooms')
                              .doc(chatRoomId)
                              .collection('messages')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return ListView.builder(
                              reverse: true,
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) =>
                                  _buildMessageBubble(
                                      snapshot.data!.docs[index]),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    filled: true,
                                    hintText: "Message Encrypted ...",
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        width: 1.7,
                                        color: Color(0xff363535),
                                      ),
                                    ),
                                    prefixIcon: IconButton(
                                        icon: Icon(
                                          Icons.attach_file,
                                          color: Color(0xff6e6565),
                                        ),
                                        onPressed: pickFile,
                                        iconSize: 17),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.teal,
                                child: IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white),
                                  onPressed: sendMessage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      /*if (_selectedFile != null || _isProcessingFile)
                    Positioned.fill(
                        child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: 1,
                            child: Container(
                                color: Colors.black.withOpacity(0.4),
                                child: Center(
                                  child: _buildCenteredPreview(),
                                ))))*/
                    ],
                  ),
          ),
          if (_selectedFile != null || _isProcessingFile)
            _buildPreviewOverlay(),
        ],
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _searchcontroller = TextEditingController();
  Stream<QuerySnapshot>? _searchStream;

  void _searchUser() {
    String id = _searchcontroller.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _searchStream = FirebaseFirestore.instance
          .collection('users')
          .where('knotID', isEqualTo: id)
          .snapshots();
    });
  }

  bool _isProcessing = false;

  Future<void> (String fromUid, String? fromName) async {
    setState(() {
      _isProcessing = true;
    });

    bool success = false;
    const String statusConnected = 'connected';
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final receiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid);

      final receiverDocSnapshot = await receiverDoc.get();
      
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .get();

      if (!senderDoc.exists || senderDoc.data() == null) {
        throw "Sender document not found";
      }
      final senderPublicKey = senderDoc['x25519PublicKey'] as String;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('connections')
          .doc(fromUid)
          .set({
        'status': statusConnected,
        'name': fromName,
        'targetUid': fromUid,
        'keyType': 'X25519',
        'peerPublicKey': senderPublicKey,
      }, SetOptions(merge: true));

      if(receiverDocSnapshot.exists()){
        final receiverData = receiverDocSnapshot.data();
        if(!receiverData == null || !receiverData.isEmpty()){
          try{
      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .collection('connections')
          .doc(myUid)
          .set({
        'status': statusConnected,
        'targetUid': myUid,
        'keyType': 'X25519',
      }, SetOptions(merge: true));

      success = true;
      }
        }
      }
      catch(e){
        print("Error raised while updating the firebase doc");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Error raised: $e", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red),
      );
    }
    if (mounted && success) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are now connected with $fromName")),
      );
    }
  }

  Widget _buildSearchStreamResult() {
    return StreamBuilder<QuerySnapshot>(
      stream: _searchStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No user found with this knotID"));
        }

        var userDoc = snapshot.data!.docs.first;
        var userData = userDoc.data() as Map<String, dynamic>;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, color: Colors.white)),
            title: Text(userData['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                )),
            subtitle: Text("ID: ${userData['knotID']}"),
            trailing: ElevatedButton(
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                String targetUid = userDoc.id;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('connections')
                    .doc(targetUid)
                    .set({'status': 'request_sent', 'targetUid': targetUid});

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(targetUid)
                    .collection('connections')
                    .doc(currentUser.uid)
                    .set({
                  'status': 'request_received',
                  'fromName': currentUser.displayName,
                  'fromUid': currentUser.uid,
                });
              },
              child: const Text("Request"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.amberAccent.shade200,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingRequest() {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('connections')
          .where('status', isEqualTo: 'request_received')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No Pending Requests."),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['fromName'] ?? "Unkown"),
              subtitle: const Text("Sent you a request"),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _acceptRequest(doc.id, data['fromName']),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            TextField(
              controller: _searchcontroller,
              decoration: InputDecoration(
                filled: true,
                hintText: "Enter 6 Digit KnotID",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _searchUser,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Colors.teal,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            if (_searchStream != null) ...[
              const Text(
                "Search Result",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildSearchStreamResult(),
              const Divider(height: 30),
            ],
            Expanded(
              child: _buildPendingRequest(),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text("Error loading Profile"));
          }
          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  userData['name'] ?? "NO NAME",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "Knot ID : ${userData['knotID']}",
                    style: TextStyle(
                      color: Colors.brown,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Divider(height: 40, color: Colors.teal),
                ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: const Text("LogOut"),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      }
                    }),
              ],
            ),
          );
        },
      ),
    );
  }
}
