import 'package:flutter/material.dart';

class Compagnie extends StatelessWidget {
  const Compagnie({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confiance"),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Text(
          "Page Confiance 🔒",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
