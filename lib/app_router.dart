import 'package:flutter/material.dart';
import 'package:alzheimers_project/cognitive_check_page.dart';
import 'package:alzheimers_project/medication_page.dart';
import 'package:alzheimers_project/profile_page.dart'; // Import the new ProfilePage
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alzheimers Project',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allow body to extend behind the navigation bar
      resizeToAvoidBottomInset: false, // Prevent resize when keyboard appears
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: <Widget>[
          HomePage(onTabSelected: _onItemTapped),
          const CognitiveCheckPage(), // Placeholder for Check
          const MedicationPage(), // Placeholder for Medications
          const ProfilePage(), // Use the new ProfilePage
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white, // White background
        selectedItemColor: Colors.blue, // Blue for selected item
        unselectedItemColor: Colors.blueGrey, // Darker gray for unselected items for contrast
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 20.0),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline, size: 20.0),
            label: 'Check',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined, size: 20.0),
            label: 'Medications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 20.0),
            label: 'Profile',
          ),
        ],
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}