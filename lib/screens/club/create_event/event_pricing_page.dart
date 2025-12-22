import 'package:flutter/material.dart';
import '../../../models/event.dart';

class EventPricingPage extends StatefulWidget {
  final EventModel eventData;
  final ValueChanged<EventModel> onNext;
  final VoidCallback onBack;

  const EventPricingPage({super.key, 
    required this.eventData,
    required this.onNext,
    required this.onBack,
  });

  @override
  _EventPricingPageState createState() => _EventPricingPageState();
}

class _EventPricingPageState extends State<EventPricingPage> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _refundMethodController = TextEditingController();
  final _refundDaysController = TextEditingController();
  
  late EventModel _localEvent;
  bool _isFree = true;
  bool _refundEnabled = false;

  @override
  void initState() {
    super.initState();
    _localEvent = widget.eventData;
    _isFree = _localEvent.isFree;
    _refundEnabled = _localEvent.refundEnabled;
    
    _priceController.text = _localEvent.price == 0 ? '' : _localEvent.price.toString();
    _refundMethodController.text = _localEvent.refundMethodDetails;
    _refundDaysController.text = _localEvent.refundDeadlineDays.toString();
  }

  void _saveAndContinue() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final price = _isFree ? 0.0 : double.tryParse(_priceController.text) ?? 0.0;
      final days = int.tryParse(_refundDaysController.text) ?? 0;
      
      // Auto-generate a readable policy string for backward compatibility
      String readablePolicy = "No refunds available.";
      if (!_isFree && _refundEnabled) {
        readablePolicy = "Refunds allowed up to $days days before event via ${_refundMethodController.text}.";
      } else if (_isFree) {
        readablePolicy = "Free event. Registration cancellation allowed.";
      }

      final updated = _localEvent.copyWith(
        isFree: _isFree,
        price: price,
        // Save new policy fields
        refundEnabled: _isFree ? false : _refundEnabled,
        refundDeadlineDays: _isFree ? 0 : days,
        refundMethodDetails: _isFree ? '' : _refundMethodController.text,
        refundPolicy: readablePolicy, // Keep legacy field populated
      );

      widget.onNext(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // 1. FREE EVENT TOGGLE
            SwitchListTile(
              title: const Text("Free Event", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Participants can join without payment"),
              value: _isFree,
              onChanged: (val) {
                setState(() {
                  _isFree = val;
                  if (val) _priceController.clear();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),

            // 2. PAID EVENT SETTINGS
            if (!_isFree) ...[
              const SizedBox(height: 10),
              Text("Pricing Configuration", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Ticket Price (RM)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => (val == null || val.isEmpty || double.tryParse(val) == 0) ? "Enter a valid price" : null,
              ),
              const SizedBox(height: 20),

              Text("Refund Policy", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              
              // Enable Refunds Switch
              Container(
                decoration: BoxDecoration(
                  color: _refundEnabled ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _refundEnabled ? Colors.green : Colors.red),
                ),
                child: SwitchListTile(
                  title: Text(_refundEnabled ? "Refunds Allowed" : "No Refunds", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_refundEnabled ? "Participants can request money back" : "All ticket sales are final"),
                  value: _refundEnabled,
                  onChanged: (val) => setState(() => _refundEnabled = val),
                ),
              ),

              // Detailed Refund Settings (Only if enabled)
              if (_refundEnabled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _refundDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Deadline (Days)',
                          hintText: 'e.g. 3',
                          helperText: 'Days before event',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey[100],
                        child: const Text("Users cannot request refund after this deadline.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _refundMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Refund Method / Instructions',
                    hintText: 'e.g. Manual transfer to user bank within 7 days',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (val) => (val == null || val.isEmpty) ? "Please explain how you will refund" : null,
                ),
              ],
            ],

            const SizedBox(height: 40),
            
            // NAVIGATION BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: widget.onBack, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), child: const Text('Back')),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(onPressed: _saveAndContinue, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)), child: const Text('Next')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}