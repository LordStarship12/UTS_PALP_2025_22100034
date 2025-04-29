import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddStorePage extends StatefulWidget{
  const AddStorePage({super.key});

  @override
  _AddStorePageState createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  

  void _saveStore() async {    
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await FirebaseFirestore.instance.collection('stores').add({
        'code': int.parse(_nimController.text.trim()),
        'name': _nameController.text.trim(),
      });
      prefs.setInt('code', int.parse(_nimController.text.trim())); 
      prefs.setString('name', _nameController.text.trim());

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tambah Toko")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nimController,
                decoration: InputDecoration(labelText: "Kode Toko"),
                validator: (value) =>
                  value!.isEmpty ? 'NIM tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nama Toko"),
                validator: (value) =>
                  value!.isEmpty ? 'Nama Toko tidak boleh kosong' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveStore,
                child: Text('Simpan Toko'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}