import 'package:flutter/material.dart';
import '../services/context_service.dart';
import '../services/auth_service.dart';

class ContextBottomSheet extends StatefulWidget {
  const ContextBottomSheet({super.key});

  @override
  State<ContextBottomSheet> createState() => _ContextBottomSheetState();
}

class _ContextBottomSheetState extends State<ContextBottomSheet> {
  final ContextService contextService = ContextService(AuthService());

  String? _selectedBudget;
  String? _selectedTravelType;
  bool _loading = false;

  final List<String> budgets = ['low', 'medium', 'high'];
  final List<String> travelTypes = ['solo', 'couple', 'family', 'luxury'];

  Future<void> _submit() async {
    if (_selectedBudget == null || _selectedTravelType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select budget and travel type')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await contextService.setContext(
        budget: _selectedBudget!,
        travelType: _selectedTravelType!,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save trip preferences')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan your trip',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            const Text('Budget', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: budgets.map((b) {
                final selected = _selectedBudget == b;
                return ChoiceChip(
                  label: Text(b.toUpperCase()),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedBudget = b),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            const Text(
              'Travel type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: travelTypes.map((t) {
                final selected = _selectedTravelType == t;
                return ChoiceChip(
                  label: Text(t.toUpperCase()),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTravelType = t),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
