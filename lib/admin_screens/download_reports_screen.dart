import 'package:flutter/material.dart';

class DownloadReportsScreen extends StatelessWidget {
  const DownloadReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Download Reports'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Text(
          "Download Reports Page",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
