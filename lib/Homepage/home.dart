import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String location;
  final int? locationId;

  const HomePage({super.key, required this.location, this.locationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(child: Text('Welcome! Location: $location')),
    );
  }
}
