import 'package:flutter/material.dart';

class GetstartedScreen extends StatelessWidget {
  const GetstartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "CostMate",
                        style: TextStyle(
                          color: Color.fromARGB(178, 0, 50, 90),
                          fontSize: 65,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        "assets/images/qrcode.jpg",
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          "CostMate is a free and collaborative expense tracker and to-do list app designed for groups, families, roommates, friends, or teams who want to manage shared finances and responsibilities. With CostMate, users can create or join groups, add members, track expenses, assign tasks, and maintain transparency — all in one place.",
                          style: TextStyle(
                            color: Color.fromARGB(255, 60, 60, 60),
                            fontSize: 16,
                            height: 1.5, // Line height
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.justify, // Makes text block look neat
                        ),
                      ),
                    ),
                    
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 50, 90),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
                    child: const Text(
                      "Get Started",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}