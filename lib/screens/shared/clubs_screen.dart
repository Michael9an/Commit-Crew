import 'package:flutter/material.dart';
import '../../widgets/bottom_nav.dart';

class ClubsScreen extends StatelessWidget {
  const ClubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Clubs')),
      body: Center(child: Text('Clubs Screen')),
      bottomNavigationBar: BottomNav(selectedIndex: 2),
    );
  }
}