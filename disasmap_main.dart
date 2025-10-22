// DISASMAP — A simple Flutter demo app
// Features: Sign Up, Login, Home, Interactive Map (friends & incidents),
// Disaster Relief Resources (articles + simple AI helper), and basic state mgmt.
// -----------------------------------------------------------------------------
// 📦 Add these to your pubspec.yaml under `dependencies:`
//   flutter:
//     sdk: flutter
//   provider: ^6.1.2
//   flutter_map: ^6.2.1
//   latlong2: ^0.9.0
//   url_launcher: ^6.3.1
//   uuid: ^4.5.1
//   intl: ^0.19.0
// (No API keys required; uses OpenStreetMap via flutter_map.)
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const DisasMapApp());
}

// ===== MODELS =====
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String password; // ⚠️ Demo only. Don't store passwords like this in production.

  UserModel({required this.id, required this.email, required this.fullName, required this.password});
}

enum IncidentType { earthquake, avalanche, landfall }

class IncidentModel {
  final String id;
  final IncidentType type;
  final String title;
  final String description;
  final LatLng location;
  final DateTime createdAt;
  final String reportedByUserId;

  IncidentModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.createdAt,
    required this.reportedByUserId,
  });
}

class PersonModel {
  final String id;
  final String name;
  final LatLng lastKnownLocation;
  final String relation; // e.g., Friend, Family

  PersonModel({required this.id, required this.name, required this.lastKnownLocation, required this.relation});
}

class ResourceArticle {
  final String id;
  final String title;
  final String summary;
  final String url;
  final List<String> tags;

  ResourceArticle({required this.id, required this.title, required this.summary, required this.url, required this.tags});
}

class ChatMessage {
  final String id;
  final String sender; // 'user' or 'bot'
  final String text;
  final DateTime time;

  ChatMessage({required this.id, required this.sender, required this.text, required this.time});
}

// ===== APP STATE =====
class AppState extends ChangeNotifier {
  final _uuid = const Uuid();

  final List<UserModel> _users = [
    // Demo seed user
    UserModel(id: const Uuid().v4(), email: 'demo@disasmap.org', fullName: 'Demo User', password: 'demo1234'),
  ];

  UserModel? _currentUser;

  final List<PersonModel> _people = [
    PersonModel(id: const Uuid().v4(), name: 'Ayşe', lastKnownLocation: LatLng(41.0863, 29.0416), relation: 'Family'),
    PersonModel(id: const Uuid().v4(), name: 'Mehmet', lastKnownLocation: LatLng(41.0082, 28.9784), relation: 'Friend'),
    PersonModel(id: const Uuid().v4(), name: 'Zeynep', lastKnownLocation: LatLng(40.9780, 29.0930), relation: 'Friend'),
  ];

  final List<IncidentModel> _incidents = [];

  final List<ResourceArticle> _resources = [
    ResourceArticle(
      id: const Uuid().v4(),
      title: 'Earthquake Preparedness Checklist',
      summary: 'Step‑by‑step actions to prepare your household for seismic events.',
      url: 'https://www.ready.gov/earthquakes',
      tags: ['earthquake', 'preparedness'],
    ),
    ResourceArticle(
      id: const Uuid().v4(),
      title: 'Avalanche Safety Basics',
      summary: 'Essential safety tips and gear for winter backcountry travel.',
      url: 'https://avalanche.org/safety-education/',
      tags: ['avalanche', 'safety'],
    ),
    ResourceArticle(
      id: const Uuid().v4(),
      title: 'Landslide & Landfall Awareness',
      summary: 'Recognizing signs and staying safe near unstable slopes and coasts.',
      url: 'https://www.usgs.gov/programs/landslide-hazards',
      tags: ['landslide', 'landfall'],
    ),
    ResourceArticle(
      id: const Uuid().v4(),
      title: 'Community Disaster Relief Volunteering',
      summary: 'Find and join local efforts to support affected communities.',
      url: 'https://www.ifrc.org/volunteer',
      tags: ['relief', 'volunteer'],
    ),
  ];

  final List<ChatMessage> _chat = [];

  // Getters
  UserModel? get currentUser => _currentUser;
  List<PersonModel> get people => List.unmodifiable(_people);
  List<IncidentModel> get incidents => List.unmodifiable(_incidents);
  List<ResourceArticle> get resources => List.unmodifiable(_resources);
  List<ChatMessage> get chat => List.unmodifiable(_chat);

  // Auth
  String? signUp({required String email, required String fullName, required String password}) {
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already in use';
    }
    final user = UserModel(id: _uuid.v4(), email: email, fullName: fullName, password: password);
    _users.add(user);
    _currentUser = user;
    notifyListeners();
    return null;
  }

  String? login({required String email, required String password}) {
    final user = _users.firstWhere(
      (u) => u.email.toLowerCase() == email.toLowerCase() && u.password == password,
      orElse: () => UserModel(id: '', email: '', fullName: '', password: ''),
    );
    if (user.id.isEmpty) {
      return 'Invalid credentials';
    }
    _currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // People
  void updatePersonLocation(String personId, LatLng newLoc) {
    final idx = _people.indexWhere((p) => p.id == personId);
    if (idx != -1) {
      _people[idx] = PersonModel(
        id: _people[idx].id,
        name: _people[idx].name,
        lastKnownLocation: newLoc,
        relation: _people[idx].relation,
      );
      notifyListeners();
    }
  }

  // Incidents
  void addIncident({required IncidentType type, required String title, required String description, required LatLng location}) {
    final inc = IncidentModel(
      id: _uuid.v4(),
      type: type,
      title: title,
      description: description,
      location: location,
      createdAt: DateTime.now(),
      reportedByUserId: _currentUser?.id ?? 'anonymous',
    );
    _incidents.insert(0, inc);
    notifyListeners();
  }

  void removeIncident(String id) {
    _incidents.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // Chatbot (very simple rule‑based demo)
  void sendUserMessage(String text) {
    _chat.add(ChatMessage(id: _uuid.v4(), sender: 'user', text: text.trim(), time: DateTime.now()));
    notifyListeners();
    _respond(text.trim());
  }

  void _respond(String text) {
    final lower = text.toLowerCase();
    String reply;

    if (lower.contains('earthquake') || lower.contains('deprem')) {
      reply = 'If you feel shaking: Drop, Cover, and Hold On. After the quake, check gas leaks and use text/SMS to contact family. See: ready.gov/earthquakes';
    } else if (lower.contains('avalanche')) {
      reply = 'Avoid slopes 30°–45° in unstable conditions. Carry transceiver, probe, shovel. Check local avalanche forecast before travel.';
    } else if (lower.contains('landslide') || lower.contains('landfall')) {
      reply = 'Watch for cracks, bulging ground, or doors that stick. Move away from slide path and to higher ground if safe.';
    } else if (lower.contains('kit') || lower.contains('go bag') || lower.contains('bag')) {
      reply = 'A good go‑bag: water, food, meds, flashlight, power bank, first aid kit, whistle, copies of documents, cash, and local maps.';
    } else if (lower.contains('help') || lower.contains('where') && lower.contains('shelter')) {
      reply = 'For shelters, check local municipality/emergency management pages and radio. In DisasMap, open Resources → filter by "relief".';
    } else {
      reply = 'I can help with safety tips, go‑bag checklists, and pointing you to resources. Try asking: "earthquake safety", "find shelters", or "what to pack".';
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _chat.add(ChatMessage(id: _uuid.v4(), sender: 'bot', text: reply, time: DateTime.now()));
      notifyListeners();
    });
  }
}

// ===== ROOT APP =====
class DisasMapApp extends StatelessWidget {
  const DisasMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'DisasMap',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/signup': (_) => const SignUpPage(),
          '/home': (_) => const HomePage(),
          '/map': (_) => const MapPage(),
          '/resources': (_) => const ResourcesPage(),
          '/chat': (_) => const ChatBotPage(),
        },
      ),
    );
  }
}

// ===== AUTH PAGES =====
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController(text: 'demo@disasmap.org');
  final _passCtrl = TextEditingController(text: 'demo1234');
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.public, color: cs.primary, size: 32),
                        const SizedBox(width: 8),
                        Text('DisasMap', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Welcome back', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Login to access the map, resources, and AI helper.'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final err = context.read<AppState>().login(email: _emailCtrl.text, password: _passCtrl.text);
                          if (err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          } else {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Log in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                      child: const Text('No account? Create one'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.public, color: cs.primary, size: 32),
                        const SizedBox(width: 8),
                        Text('DisasMap', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Create your account', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final err = context.read<AppState>().signUp(
                                email: _emailCtrl.text,
                                fullName: _nameCtrl.text,
                                password: _passCtrl.text,
                              );
                          if (err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          } else {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Sign up'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Already have an account? Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== HOME =====
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DisasMap — Home'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              context.read<AppState>().logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _HomeCard(
            icon: Icons.map_outlined,
            title: 'Interactive Map',
            subtitle: 'View loved ones & report incidents',
            onTap: () => Navigator.pushNamed(context, '/map'),
          ),
          _HomeCard(
            icon: Icons.article_outlined,
            title: 'Relief Resources',
            subtitle: 'Guides, articles & sources',
            onTap: () => Navigator.pushNamed(context, '/resources'),
          ),
          _HomeCard(
            icon: Icons.smart_toy_outlined,
            title: 'AI Helper',
            subtitle: 'Ask safety & prep questions',
            onTap: () => Navigator.pushNamed(context, '/chat'),
          ),
          _HomeCard(
            icon: Icons.people_alt_outlined,
            title: 'My People',
            subtitle: '${context.watch<AppState>().people.length} saved contacts',
            onTap: () => _showPeople(context),
          ),
          _HomeCard(
            icon: Icons.warning_amber_outlined,
            title: 'Recent Incidents',
            subtitle: '${context.watch<AppState>().incidents.length} reports',
            onTap: () => _showIncidents(context),
          ),
        ],
      ),
      bottomNavigationBar: user == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Signed in as ${user.fullName} • ${user.email}', textAlign: TextAlign.center),
            ),
    );
  }

  void _showPeople(BuildContext context) {
    final people = context.read<AppState>().people;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(people[i].name),
          subtitle: Text('${people[i].relation} • Lat: ${people[i].lastKnownLocation.latitude.toStringAsFixed(3)}, Lng: ${people[i].lastKnownLocation.longitude.toStringAsFixed(3)}'),
          trailing: const Icon(Icons.chevron_right),
        ),
        separatorBuilder: (_, __) => const Divider(),
        itemCount: people.length,
      ),
    );
  }

  void _showIncidents(BuildContext context) {
    final incidents = context.read<AppState>().incidents;
    final df = DateFormat('MMM d, HH:mm');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final inc = incidents[i];
          return ListTile(
            leading: CircleAvatar(backgroundColor: _incidentColor(inc.type), child: Icon(_incidentIcon(inc.type), color: Colors.white)),
            title: Text(inc.title),
            subtitle: Text('${inc.description}\n${df.format(inc.createdAt)} — Lat ${inc.location.latitude.toStringAsFixed(3)}, Lng ${inc.location.longitude.toStringAsFixed(3)}'),
            isThreeLine: true,
          );
        },
        separatorBuilder: (_, __) => const Divider(),
        itemCount: incidents.length,
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== MAP PAGE =====
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng _center = LatLng(41.0082, 28.9784); // Istanbul
  LatLng? _pendingTap; // For placing a new incident

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final peopleMarkers = app.people
        .map((p) => Marker(
              width: 36,
              height: 36,
              point: p.lastKnownLocation,
              child: Tooltip(
                message: '${p.name} (${p.relation})',
                child: const Icon(Icons.person_pin_circle, size: 32, color: Colors.blueAccent),
              ),
            ))
        .toList();

    final incidentMarkers = app.incidents
        .map((i) => Marker(
              width: 40,
              height: 40,
              point: i.location,
              child: Tooltip(
                message: '${_incidentTypeLabel(i.type)}: ${i.title}',
                child: Icon(_incidentIcon(i.type), size: 30, color: _incidentColor(i.type)),
              ),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DisasMap — Interactive Map'),
        actions: [
          IconButton(
            tooltip: 'Center on Istanbul',
            onPressed: () => setState(() => _center = LatLng(41.0082, 28.9784)),
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Show incident list',
            onPressed: () => _showIncidentList(context),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 11,
                onTap: (tapPos, latLng) {
                  setState(() => _pendingTap = latLng);
                  _openAddIncident(context, latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.disasmap.app',
                ),
                MarkerLayer(markers: [...peopleMarkers, ...incidentMarkers]),
              ],
            ),
          ),
          if (_pendingTap != null)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tap location selected: ${_pendingTap!.latitude.toStringAsFixed(4)}, ${_pendingTap!.longitude.toStringAsFixed(4)}')),
                  TextButton(
                    onPressed: () => _openAddIncident(context, _pendingTap!),
                    child: const Text('Report incident here'),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddIncident(context, _center),
        icon: const Icon(Icons.report_gmailerrorred_outlined),
        label: const Text('Report incident'),
      ),
    );
  }

  void _showIncidentList(BuildContext context) {
    final incidents = context.read<AppState>().incidents;
    final df = DateFormat('MMM d, HH:mm');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: incidents.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final inc = incidents[i];
          return ListTile(
            leading: CircleAvatar(backgroundColor: _incidentColor(inc.type), child: Icon(_incidentIcon(inc.type), color: Colors.white)),
            title: Text('${_incidentTypeLabel(inc.type)} — ${inc.title}'),
            subtitle: Text('${inc.description}\n${df.format(inc.createdAt)} • lat ${inc.location.latitude.toStringAsFixed(3)}, lng ${inc.location.longitude.toStringAsFixed(3)}'),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context.read<AppState>().removeIncident(inc.id);
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAddIncident(BuildContext context, LatLng at) async {
    final result = await showDialog<_NewIncidentData>(
      context: context,
      builder: (_) => _AddIncidentDialog(initial: at),
    );
    if (result != null) {
      context.read<AppState>().addIncident(
            type: result.type,
            title: result.title,
            description: result.description,
            location: result.location,
          );
      setState(() => _pendingTap = null);
    }
  }
}

class _NewIncidentData {
  final IncidentType type;
  final String title;
  final String description;
  final LatLng location;
  _NewIncidentData({required this.type, required this.title, required this.description, required this.location});
}

class _AddIncidentDialog extends StatefulWidget {
  final LatLng initial;
  const _AddIncidentDialog({required this.initial});

  @override
  State<_AddIncidentDialog> createState() => _AddIncidentDialogState();
}

class _AddIncidentDialogState extends State<_AddIncidentDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  IncidentType _type = IncidentType.earthquake;
  late double _lat;
  late double _lng;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _lat = widget.initial.latitude;
    _lng = widget.initial.longitude;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report New Incident'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<IncidentType>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: IncidentType.earthquake, child: Text('Earthquake')),
                  DropdownMenuItem(value: IncidentType.avalanche, child: Text('Avalanche')),
                  DropdownMenuItem(value: IncidentType.landfall, child: Text('Landfall / Landslide')),
                ],
                onChanged: (v) => setState(() => _type = v ?? IncidentType.earthquake),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined), labelText: 'Type'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _lat.toStringAsFixed(6),
                      decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.explore_outlined)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (v) => _lat = double.tryParse(v) ?? _lat,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _lng.toStringAsFixed(6),
                      decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.explore_outlined)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (v) => _lng = double.tryParse(v) ?? _lng,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Tip: You can also tap the map to pre‑fill coordinates.', style: Theme.of(context).textTheme.bodySmall),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _NewIncidentData(
                  type: _type,
                  title: _titleCtrl.text.trim(),
                  description: _descCtrl.text.trim(),
                  location: LatLng(_lat, _lng),
                ),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

IconData _incidentIcon(IncidentType t) {
  switch (t) {
    case IncidentType.earthquake:
      return Icons.vibration; // representation icon
    case IncidentType.avalanche:
      return Icons.downhill_skiing_outlined;
    case IncidentType.landfall:
      return Icons.terrain_outlined;
  }
}

Color _incidentColor(IncidentType t) {
  switch (t) {
    case IncidentType.earthquake:
      return Colors.redAccent;
    case IncidentType.avalanche:
      return Colors.indigo;
    case IncidentType.landfall:
      return Colors.brown;
  }
}

String _incidentTypeLabel(IncidentType t) {
  switch (t) {
    case IncidentType.earthquake:
      return 'Earthquake';
    case IncidentType.avalanche:
      return 'Avalanche';
    case IncidentType.landfall:
      return 'Landfall / Landslide';
  }
}

// ===== RESOURCES PAGE =====
class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filtered = state.resources.where((r) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return r.title.toLowerCase().contains(q) || r.summary.toLowerCase().contains(q) || r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Relief Resources')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search resources (e.g., earthquake, relief, avalanche)...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = filtered[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.library_books_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r.summary),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: r.tags.map((t) => Chip(label: Text(t))).toList(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(r.url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open resource'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.pushNamed(context, '/chat'),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Ask AI about resources'),
            ),
          )
        ],
      ),
    );
  }
}

// ===== CHATBOT PAGE =====
class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<AppState>().chat;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Helper')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              reverse: true,
              padding: const EdgeInsets.all(12),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: chat.length,
              itemBuilder: (_, i) {
                final msg = chat[chat.length - 1 - i];
                final isUser = msg.sender == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isUser ? Colors.teal.shade600 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.smart_toy_outlined, size: 14),
                                SizedBox(width: 4),
                                Text('DisasBot', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          Text(
                            msg.text,
                            style: TextStyle(color: isUser ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(msg.time),
                            style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(hintText: 'Ask safety or resource questions...'),
                      onSubmitted: (_) => _send(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: () => _send(context), icon: const Icon(Icons.send), label: const Text('Send')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send(BuildContext context) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    context.read<AppState>().sendUserMessage(text);
    _ctrl.clear();
  }
}

// ===== UTILS (optional demo generator) =====
LatLng randomNearby(LatLng center, {double maxDeltaKm = 10}) {
  final rnd = Random();
  final distance = rnd.nextDouble() * maxDeltaKm; // km
  final bearing = rnd.nextDouble() * 2 * pi; // radians
  const earthRadiusKm = 6371.0;
  final lat1 = center.latitude * pi / 180;
  final lon1 = center.longitude * pi / 180;
  final lat2 = asin(sin(lat1) + cos(lat1) * cos(distance / earthRadiusKm) * cos(bearing));
  final lon2 = lon1 + atan2(sin(bearing) * sin(distance / earthRadiusKm) * cos(lat1), cos(distance / earthRadiusKm) - sin(lat1) * sin(lat2));
  return LatLng(lat2 * 180 / pi, lon2 * 180 / pi);
}
