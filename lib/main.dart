import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uts_palp_2025_22100034/firebase_options.dart';
import 'package:uts_palp_2025_22100034/add_store_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "UAS PALP 2025 - Timothy Valentivo",
      theme: ThemeData(primarySwatch: Colors.lightBlue),
      home: StorePage(),
    );
  }
}

class StorePage extends StatefulWidget {
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final CollectionReference purchaseGoodsReceipts =
      FirebaseFirestore.instance.collection('purchaseGoodsReceipts');
  final CollectionReference details =
      FirebaseFirestore.instance.collection('details');
  
  Future _read() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getInt('code') ?? "";
    final name = prefs.getString('name') ?? "";
    print('$code, $name');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('UAS PALP 2025 - Timothy Valentivo')),
        body: Center(
            child: Column(children: [
          StreamBuilder<QuerySnapshot>(
              stream: purchaseGoodsReceipts
                  .where('store_ref', isEqualTo: '/stores/7')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Tidak ada produk.'));
                }
                return ListView(
                  children:
                      snapshot.data!.docs.map((DocumentSnapshot document) {
                    final data = document.data()! as Map<String, dynamic>;

                    return Card(
                        child: ListTile(
                      title: Text(data['no_form'] ?? '-'),
                      subtitle: Text(data['post_date'] ?? ''),
                    ));
                  }).toList(),
                );
              }),
          SizedBox(height: 20),
          ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => AddStorePage()));
              },
              child: Text('Tambah Nama Toko')
            ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _read,
            child: Text("Nama Toko"),
          )
        ]
      )
    ));
  }
}


