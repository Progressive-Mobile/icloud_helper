import 'package:cloud_helper/cloud_helper_method_channel.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _containerId = 'iCloud.com.cloud.example';

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _phraseController = TextEditingController();
  CloudHelper? cloudHelper;
  String? data;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            TextFormField(
              controller: _idController,
            ),
            TextFormField(
              controller: _nameController,
            ),
            TextFormField(
              controller: _phraseController,
            ),
            ElevatedButton(
              onPressed: () async {
                cloudHelper ??= await CloudHelper.create(_containerId);
                try {
                  await cloudHelper?.addRecord(
                    data: {
                      'phrase': _phraseController.text,
                      'name': _nameController.text,
                    },
                    id: _idController.text,
                    type: 'Seed',
                  );
                } catch (err) {
                  print(err);
                  // Error saving record <CKRecordID: 0x131ef0840; recordName=test, zoneID=_defaultZone:__defaultOwner__> to server: record to insert already exists
                }
              },
              child: const Text('upload'),
            ),
            ElevatedButton(
              onPressed: () async {
                cloudHelper ??= await CloudHelper.create(_containerId, "A");
                try {
                  final a = await cloudHelper?.getAllRecords(
                    type: 'Seed',
                  );
                  setState(() {
                    data = a?.join('\n');
                  });
                } catch (err) {
                  print(err);
                }
              },
              child: const Text('get'),
            ),
            ElevatedButton(
              onPressed: () async {
                cloudHelper ??= await CloudHelper.create(_containerId, "");
                cloudHelper
                    ?.deleteRecord(
                      id: _idController.text,
                    )
                    .then((value) => setState(() {
                          data = null;
                        }));
              },
              child: const Text('delete'),
            ),
            ElevatedButton(
              onPressed: () async {
                cloudHelper ??= await CloudHelper.create(_containerId);
                try {
                  await cloudHelper?.editRecord(
                    id: _idController.text,
                    data: {
                      'phrase': _phraseController.text,
                      'name': _nameController.text,
                    },
                  );
                } catch (err) {
                  print(err);
                }
              },
              child: const Text('edit'),
            ),
            Text(data ?? ''),
          ],
        ),
      ),
    );
  }
}
