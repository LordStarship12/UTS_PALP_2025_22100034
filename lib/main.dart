import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'add_receipt_page.dart';
import 'add_store_page.dart';
import 'edit_receipt_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "UAS PALP 2025 - Timothy Valentivo",
      theme: ThemeData(primarySwatch: Colors.lightBlue),
      debugShowCheckedModeBanner: false,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const ReceiptListPage(),
    const ReceiptDetailsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Receipts'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Details'),
        ],
      ),
    );
  }
}

class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({super.key});

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allReceipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReceiptsForStore();
  }

  Future<void> _loadReceiptsForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    List<DocumentSnapshot> allReceipts = [];

    for (var receipt in receiptsSnapshot.docs) {
      allReceipts.add(receipt);
    }

    setState(() {
      _storeRef = storeRef;
      _allReceipts = allReceipts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt List')),
      body: _loading
          ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
          : _allReceipts.isEmpty
              ? const Center(child: Text('Tidak ada produk.'))
              : ListView.builder(
                  itemCount: _allReceipts.length,
                  itemBuilder: (context, index) {
                    final document = _allReceipts[index];
                    final data = document.data() as Map<String, dynamic>;
                    final postDateRaw = data['post_date'];
                    final postDate = DateTime.tryParse(postDateRaw);
                    final formattedDate = postDate != null
                        ? DateFormat('yyyy-MM-dd').format(postDate)
                        : 'Invalid date';
                          return GestureDetector(
                            onTap: () async {
                                final result = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => EditReceiptModal(
                                    receiptRef: document.reference,
                                    receiptData: data,
                                  ),
                                ); 
                                if (result == 'deleted' || result == 'updated') {
                                  await _loadReceiptsForStore();
                                }
                              },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("No. Form: ${data['no_form']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("Post Date: $formattedDate"),
                                    Text("Grand Total: ${data['grandtotal']}"),
                                    Text("Item Total: ${data['item_total']}"),
                                    Text("Store: ${data['store_ref'].path}"),
                                    Text("Supplier: ${data['supplier_ref'].path}"),
                                    Text("Warehouse: ${data['warehouse_ref'].path}"),
                                    Text("Synced: ${data['synced'] ? 'Yes' : 'No'}"),
                                    Text("Created At: ${data['created_at'].toDate()}"),
                                  ],
                                ),
                              ),
                            ),
                          );
                  },
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddStorePage()),
              );
              await _loadReceiptsForStore();
            },
            child: const Text('Pengaturan Toko'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddReceiptPage()),
              );
              await _loadReceiptsForStore();
            },
            child: const Text('Tambah Receipt'),
          ),
        ],
      ),
    );
  }
}

class ReceiptDetailsPage extends StatefulWidget {
  const ReceiptDetailsPage({super.key});

  @override
  State<ReceiptDetailsPage> createState() => _ReceiptDetailsPageState();
}

class _ReceiptDetailsPageState extends State<ReceiptDetailsPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allDetails = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetailsForStore();
  }

  Future<void> _loadDetailsForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    List<DocumentSnapshot> allDetails = [];

    for (var receipt in receiptsSnapshot.docs) {
      final detailsSnapshot = await receipt.reference.collection('details').get();
      allDetails.addAll(detailsSnapshot.docs);
    }

    setState(() {
      _storeRef = storeRef;
      _allDetails = allDetails;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: _loading
          ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
          : _allDetails.isEmpty
              ? const Center(child: Text('Tidak ada detail produk.'))
              : ListView.builder(
                  itemCount: _allDetails.length,
                  itemBuilder: (context, index) {
                    final data = _allDetails[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Product Ref: ${data['product_ref'].path}"),
                            Text("Qty: ${data['qty']}"),
                            Text("Unit: ${data['unit_name']}"),
                            Text("Price: ${data['price']}"),
                            Text("Subtotal: ${data['subtotal']}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}