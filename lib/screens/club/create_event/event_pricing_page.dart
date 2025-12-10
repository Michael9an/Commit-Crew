// event_pricing_page.dart
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
  final _refundPolicyController = TextEditingController();
  
  late EventModel _localEvent;
  bool _isFree = true;
  DateTime _publishTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _localEvent = widget.eventData;
    _isFree = _localEvent.isFree;
    _priceController.text = _localEvent.price == 0 ? '' : _localEvent.price.toString();
    _refundPolicyController.text = _localEvent.refundPolicy ?? '';
    
    // Set publish time from event data if exists
    if (_localEvent.publishTime != null) {
      final timestamp = int.tryParse(_localEvent.publishTime!);
      if (timestamp != null) {
        _publishTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
  }

  Future<void> _selectPublishTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _publishTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_publishTime),
      );
      if (time != null) {
        setState(() {
          _publishTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _saveAndContinue() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final price = _isFree ? 0.0 : double.tryParse(_priceController.text) ?? 0.0;
      
      final updated = _localEvent.copyWith(
        isFree: _isFree,
        price: price,
        refundPolicy: _refundPolicyController.text.isEmpty ? null : _refundPolicyController.text,
        publishTime: _publishTime.millisecondsSinceEpoch.toString(),
      );

      widget.onNext(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Free Event Toggle
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Free Event',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'This event is free for all students',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isFree,
                      onChanged: (value) {
                        setState(() {
                          _isFree = value;
                          if (value) {
                            _priceController.text = '';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Price (only show if not free)
            if (!_isFree) ...[
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Ticket Price *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (!_isFree && (value == null || value.isEmpty)) {
                    return 'Please enter ticket price';
                  }
                  final price = double.tryParse(value ?? '');
                  if (!_isFree && (price == null || price <= 0)) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
            ],

            // Refund Policy
            TextFormField(
              controller: _refundPolicyController,
              decoration: InputDecoration(
                labelText: 'Refund Policy',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: 'Describe your refund policy...',
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Publish Time
            GestureDetector(
              onTap: _selectPublishTime,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Publish Time',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                    hintText: 'When should this event go live?',
                  ),
                  controller: TextEditingController(
                    text: '${_publishTime.day}/${_publishTime.month}/${_publishTime.year} ${_publishTime.hour}:${_publishTime.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),

            // Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, 50),
                    ),
                    child: Text('Back'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(0, 50),
                    ),
                    child: Text('Next: Overview'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _refundPolicyController.dispose();
    super.dispose();
  }
}