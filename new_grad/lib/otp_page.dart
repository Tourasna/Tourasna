import 'dart:async';
import 'package:flutter/material.dart';
import 'package:new_grad/Login_page.dart';

class OTPPage extends StatefulWidget {
  const OTPPage({Key? key}) : super(key: key);

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  bool invalidOtp = false;
  int resendTime = 60;
  late Timer countdownTimer;
  TextEditingController txt1 = TextEditingController();
  TextEditingController txt2 = TextEditingController();
  TextEditingController txt3 = TextEditingController();
  TextEditingController txt4 = TextEditingController();
  TextEditingController txt5 = TextEditingController();
  TextEditingController txt6 = TextEditingController();

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  startTimer() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        resendTime = resendTime - 1;
      });
      if (resendTime < 1) {
        countdownTimer.cancel();
      }
    });
  }

  stopTimer() {
    if (countdownTimer.isActive) {
      countdownTimer.cancel();
    }
  }

  String strFormatting(n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E5D1),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Enter the 6-digits code sent to you at :',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Colors.black),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '+1 81234 56789',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          myInputBox(context, txt1),
                          myInputBox(context, txt2),
                          myInputBox(context, txt3),
                          myInputBox(context, txt4),
                          myInputBox(context, txt5),
                          myInputBox(context, txt6),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Didn’t Receive?",
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          resendTime == 0
                              ? InkWell(
                                  onTap: () {
                                    invalidOtp = false;
                                    resendTime = 60;
                                    startTimer();
                                  },
                                  child: const Text(
                                    'Resend Code',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : const SizedBox(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      resendTime != 0
                          ? Text(
                              'You can resend OTP after ${strFormatting(resendTime)} second(s)',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            )
                          : const SizedBox(),
                      const SizedBox(height: 20),
                      Text(
                        invalidOtp ? 'Invalid otp!' : '',
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ Buttons pinned at bottom
            Padding(
              padding: const EdgeInsets.only(
                bottom: 30,
                left: 24,
                right: 24,
                top: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 130,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: () {
                        final otp =
                            txt1.text +
                            txt2.text +
                            txt3.text +
                            txt4.text +
                            txt5.text +
                            txt6.text;
                        if (otp == '198975') {
                          stopTimer();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        } else {
                          setState(() {
                            invalidOtp = true;
                          });
                        }
                      },
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget myInputBox(BuildContext context, TextEditingController controller) {
  return Container(
    height: 60,
    width: 50,
    decoration: BoxDecoration(
      border: Border.all(width: 1.5, color: Colors.black),
      borderRadius: BorderRadius.circular(8),
    ),
    child: TextField(
      controller: controller,
      maxLength: 1,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        counterText: '',
        border: InputBorder.none,
      ),
      onChanged: (value) {
        if (value.length == 1) {
          FocusScope.of(context).nextFocus();
        }
      },
    ),
  );
}
