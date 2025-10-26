import 'package:flutter/material.dart';

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Start.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(color: Colors.white.withOpacity(0.25)),

          Center(
            child: Image.asset(
              'assets/images/new logo.png',
              width: 292,
              height: 415,
            ),
          ),
        ],
      ),
    );
  }
}
