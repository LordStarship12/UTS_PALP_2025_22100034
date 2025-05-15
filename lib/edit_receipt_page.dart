import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditReceiptModal extends StatefulWidget {
  final DocumentReference receiptRef;
  final Map<String, dynamic> receiptData;

  const EditReceiptModal({
    super.key,
    required this.receiptRef,
    required this.receiptData,
  });

  @override
  State<EditReceiptModal> createState() => _EditReceiptModalState();
}

class _EditReceiptModalState extends State<EditReceiptModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _formNumberController = TextEditingController();

  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _suppliers = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];

  final List<_DetailItem> _productDetails = [];

  int get itemTotal => _productDetails.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _productDetails.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void initState() {
    super.initState();
    _formNumberController.text = widget.receiptData['no_form'] ?? '';
    _selectedSupplier = widget.receiptData['supplier_ref'];
    _selectedWarehouse = widget.receiptData['warehouse_ref'];
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    final suppliers = await FirebaseFirestore.instance.collection('suppliers').get();
    final warehouses = await FirebaseFirestore.instance.collection('warehouses').get();
    final products = await FirebaseFirestore.instance.collection('products').get();
    final detailsSnapshot = await widget.receiptRef.collection('details').get();

    setState(() {
      _suppliers = suppliers.docs;
      _warehouses = warehouses.docs;
      _products = products.docs;
      _productDetails.clear();
      for (var doc in detailsSnapshot.docs) {
        _productDetails.add(_DetailItem.fromMap(doc.data(), _products, doc.reference));
      }
    });
  }

  void _updateReceipt() async {
    if (!_formKey.currentState!.validate() ||
        _selectedSupplier == null ||
        _selectedWarehouse == null ||
        _productDetails.isEmpty) return;

    await widget.receiptRef.update({
      'no_form': _formNumberController.text.trim(),
      'supplier_ref': _selectedSupplier,
      'warehouse_ref': _selectedWarehouse,
      'item_total': itemTotal,
      'grandtotal': grandTotal,
      'updated_at': DateTime.now(),
    });

    final detailsRef = widget.receiptRef.collection('details');
    final existingDetails = await detailsRef.get();
    for (var doc in existingDetails.docs) {
      await doc.reference.delete();
    }
    for (var item in _productDetails) {
      await detailsRef.add(item.toMap());
    }

    if(mounted){Navigator.pop(context, 'updated');}
  }

  void _removeProductRow(int index) {
    setState(() => _productDetails.removeAt(index));
  }

  void _addProductRow() {
    setState(() => _productDetails.add(_DetailItem(products: _products)));
  }

  void _confirmDeleteReceipt() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Yakin ingin menghapus receipt ini? Semua detail akan ikut terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final detailsRef = widget.receiptRef.collection('details');
    final detailDocs = await detailsRef.get();
    for (var doc in detailDocs.docs) {
      await doc.reference.delete();
    }

    await widget.receiptRef.delete();

    await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .doc(widget.receiptRef.id)
        .delete();

    if(mounted){Navigator.pop(context, 'deleted');};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Receipt')),
      body: _products.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _formNumberController,
                      decoration: InputDecoration(labelText: 'No. Form'),
                      validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    DropdownButtonFormField<DocumentReference>(
                      value: _selectedSupplier,
                      items: _suppliers.map((doc) {
                        return DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedSupplier = value),
                      decoration: InputDecoration(labelText: 'Supplier'),
                      validator: (value) => value == null ? 'Pilih supplier' : null,
                    ),
                    DropdownButtonFormField<DocumentReference>(
                      value: _selectedWarehouse,
                      items: _warehouses.map((doc) {
                        return DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedWarehouse = value),
                      decoration: InputDecoration(labelText: 'Warehouse'),
                      validator: (value) => value == null ? 'Pilih warehouse' : null,
                    ),
                    SizedBox(height: 24),
                    Text("Detail Produk", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ..._productDetails.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              DropdownButtonFormField<DocumentReference>(
                                value: item.productRef,
                                items: _products.map((doc) {
                                  return DropdownMenuItem(
                                    value: doc.reference,
                                    child: Text(doc['name']),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() {
                                  item.productRef = value;
                                  item.unitName = value!.id == '1' ? 'pcs' : 'dus';
                                }),
                                decoration: InputDecoration(labelText: "Produk"),
                                validator: (value) => value == null ? 'Pilih produk' : null,
                              ),
                              TextFormField(
                                initialValue: item.price.toString(),
                                decoration: InputDecoration(labelText: "Harga"),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  item.price = int.tryParse(val) ?? 0;
                                }),
                                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                              ),
                              TextFormField(
                                initialValue: item.qty.toString(),
                                decoration: InputDecoration(labelText: "Jumlah"),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  item.qty = int.tryParse(val) ?? 1;
                                }),
                                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                              ),
                              SizedBox(height: 8),
                              Text("Satuan: ${item.unitName}"),
                              Text("Subtotal: ${item.subtotal}"),
                              SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: () => _removeProductRow(index),
                                icon: Icon(Icons.remove_circle, color: Colors.red),
                                label: Text("Hapus Produk"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ElevatedButton.icon(
                      onPressed: _addProductRow,
                      icon: Icon(Icons.add),
                      label: Text('Tambah Produk'),
                    ),
                    SizedBox(height: 16),
                    Text("Item Total: $itemTotal"),
                    Text("Grand Total: $grandTotal"),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updateReceipt,
                      child: Text('Update Receipt'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _confirmDeleteReceipt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Hapus Receipt'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DetailItem {
  DocumentReference? productRef;
  int price;
  int qty;
  String unitName;
  final List<DocumentSnapshot> products;
  final DocumentReference? docRef;

  _DetailItem({
    this.productRef,
    this.price = 0,
    this.qty = 1,
    this.unitName = 'unit',
    required this.products,
    this.docRef,
  });

  factory _DetailItem.fromMap(Map<String, dynamic> data, List<DocumentSnapshot> products, DocumentReference ref) {
    return _DetailItem(
      productRef: data['product_ref'],
      price: data['price'],
      qty: data['qty'],
      unitName: data['unit_name'] ?? 'unit',
      products: products,
      docRef: ref,
    );
  }

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'price': price,
      'qty': qty,
      'unit_name': unitName,
      'subtotal': subtotal,
    };
  }
}
