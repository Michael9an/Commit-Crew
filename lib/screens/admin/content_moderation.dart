import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'report_review_screen.dart';

class ContentModerationScreen extends StatelessWidget {
	const ContentModerationScreen({Key? key}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					const Text('Content Moderation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
					const SizedBox(height: 12),
					const Text('Review and moderate reported content, events, and posts.'),
					const SizedBox(height: 18),

					// Quick action: open report review
					Card(
						child: ListTile(
							leading: const Icon(Icons.report, color: Colors.red),
							title: const Text('Review Reports'),
							subtitle: const Text('View pending reports submitted by users'),
							trailing: StreamBuilder<QuerySnapshot>(
								stream: FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'pending').snapshots(),
								builder: (context, snapshot) {
									final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
									return Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											if (count > 0)
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
													decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
													child: Text(count.toString(), style: const TextStyle(color: Colors.white)),
												),
											const SizedBox(width: 8),
											ElevatedButton(
												onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportReviewScreen())),
												child: const Text('Open'),
											),
										],
									);
								},
							),
						),
					),
				],
			),
		);
	}
}