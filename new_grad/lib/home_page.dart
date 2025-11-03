import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF5E5D1)),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ),
        body: const Center(),
        floatingActionButton: FloatingActionButton.large(
          onPressed: () {},
          backgroundColor: const Color(0xFFF5E5D1),
          foregroundColor: const Color(0xFF555555),
          elevation: 8.0,
          shape: const CircleBorder(),
          child: const Icon(Icons.camera_alt_outlined, size: 40),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          color: const Color(0xFFF5E5D1),
          height: 70,
          notchMargin: 8.0,
          elevation: 1.0,
          shadowColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.home_filled, color: Color(0xFF555555)),
                        SizedBox(height: 4),
                        Text(
                          "Explore",
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.star, color: Color(0xFF555555)),
                        SizedBox(height: 4),
                        Text(
                          "FAVs",
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.settings, color: Color(0xFF555555)),
                        SizedBox(height: 4),
                        Text(
                          "Settings",
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person, color: Color(0xFF555555)),
                        SizedBox(height: 4),
                        Text(
                          "Profile",
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
