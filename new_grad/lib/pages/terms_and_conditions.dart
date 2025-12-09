import 'package:flutter/material.dart';

class TermsAndConditions extends StatelessWidget {
  const TermsAndConditions({super.key});

  @override
  Widget build(BuildContext context) {
    bool isChecked = false;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF5E5D1),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 44),

                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Image(
                    image: AssetImage('assets/images/terms.png'),
                    width: 292,
                    height: 285,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Almost Finished!',
                  style: TextStyle(
                    fontFamily: 'Sail',
                    fontSize: 35,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'By checking the box, you confirm that you are at least 18 years old and that you agree to our Terms of Use and have read our Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),

                StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isChecked,
                              activeColor: Colors.black,
                              onChanged: (value) {
                                setState(() {
                                  isChecked = value!;
                                });
                              },
                            ),

                            Expanded(
                              // <-- FIX: lets the text wrap instead of overflow
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: const Color(
                                          0xFFF5E5D1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: const Text(
                                          'Terms & Conditions',
                                          style: TextStyle(
                                            fontFamily: 'Sail',
                                            fontSize: 28,
                                            color: Colors.black,
                                          ),
                                        ),
                                        content: const SingleChildScrollView(
                                          child: Text(
                                            '1. About Tourasna\n'
                                            'Tourasna is a tourism application providing:\n'
                                            '• AI-based monument recognition\n'
                                            '• 3D model viewing\n'
                                            '• Location-based discovery\n'
                                            '• Personalized recommendations\n'
                                            '• User profiles and saved favorites\n\n'
                                            '2. User Accounts\n'
                                            '• You must provide accurate information.\n'
                                            '• You are responsible for securing your account.\n'
                                            '• Accounts involved in abuse or illegal activity may be suspended.\n'
                                            '• You may request account deletion at any time.\n\n'
                                            '3. AI Recognition Disclaimer\n'
                                            '• AI results are predictions and may not be accurate.\n'
                                            '• Tourasna is not responsible for incorrect outputs.\n\n'
                                            '4. Location & Map Data\n'
                                            '• Location is used to enhance recommendations.\n'
                                            '• We do not guarantee route accuracy or safety.\n\n'
                                            '5. 3D Models & Media Content\n'
                                            '• 3D models are for reference only.\n'
                                            '• Some assets may be inaccurate or unavailable.\n'
                                            '• Reuse or redistribution is prohibited.\n\n'
                                            '6. User-Generated Content\n'
                                            '• You grant us permission to store and display submitted content.\n'
                                            '• You must own the rights to what you upload.\n'
                                            '• Illegal or copyrighted content may be removed.\n\n'
                                            '7. Data & Privacy\n'
                                            '• Data is handled according to our Privacy Policy.\n'
                                            '• Authentication and storage use Supabase.\n\n'
                                            '8. Recommendations\n'
                                            '• Suggestions are generated automatically.\n'
                                            '• They may not always match your interests.\n\n'
                                            '9. App Availability\n'
                                            '• The app may be temporarily unavailable.\n'
                                            '• No guarantee of uninterrupted access.\n\n'
                                            '10. Limitation of Liability\n'
                                            'Tourasna is not liable for:\n'
                                            '• Inaccurate tourism information\n'
                                            '• Travel issues or missed opportunities\n'
                                            '• Injuries, losses, or legal problems\n'
                                            '• Third-party services\n\n'
                                            '11. Intellectual Property\n'
                                            '• All assets and designs belong to Tourasna.\n'
                                            '• Copying or reverse engineering is prohibited.\n\n'
                                            '12. Termination\n'
                                            '• We may suspend accounts or remove content if terms are violated.\n\n'
                                            '13. Changes to Terms\n'
                                            '• Terms may be updated. Continued use means acceptance.\n\n'
                                            '14. Contact\n'
                                            'Email: tourasnahelpcener@gmail.com\n\n'
                                            'A simple agreement built on respect.',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Close',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: const Text(
                                  'Tap here to view the Terms & Conditions and\nPrivacy Policy before confirming your agreement.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isChecked
                                ? () {
                                    Navigator.pushNamed(
                                      context,
                                      '/preferences',
                                    );
                                  }
                                : null,
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
