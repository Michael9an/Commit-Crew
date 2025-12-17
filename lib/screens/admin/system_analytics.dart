import 'package:flutter/material.dart';

class SystemAnalyticsScreen extends StatelessWidget {
	const SystemAnalyticsScreen({Key? key}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Center(
				child: Padding(
					padding: const EdgeInsets.all(16.0),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: const [
							Icon(Icons.analytics, size: 64, color: Colors.blue),
							SizedBox(height: 12),
							Text('System Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
							SizedBox(height: 8),
							Text('Overview of system-wide usage, events, and metrics.'),
						],
					),
				),
			),
		);
	}
}
