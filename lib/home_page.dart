import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:async'; // ✅ عشان Timer

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLive = false;
  bool stopped = false;
  final TextEditingController notesController = TextEditingController();
  bool canSend = false;
  String? selectedClient;
  String? currentVisitId;
  Timer? locationTimer;

  @override
  void initState() {
    super.initState();
    notesController.addListener(() {
      setState(() {
        canSend = notesController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    notesController.dispose();
    locationTimer?.cancel();
    super.dispose();
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("خدمة الموقع غير مفعلة");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception("تم رفض إذن الوصول للموقع");
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("إذن الموقع مرفوض بشكل دائم");
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> _getAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks.first;
      return "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
    } catch (e) {
      return "العنوان غير متاح";
    }
  }

  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("إضافة عميل جديد", textAlign: TextAlign.center),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: "اسم العميل", alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: "رقم التليفون", alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: "عنوان العميل", alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.deepPurple),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection("clients").doc(nameController.text.trim()).set({
                  "name": nameController.text.trim(),
                  "phone": phoneController.text.trim(),
                  "address": addressController.text.trim(),
                  "createdAt": DateTime.now(),
                });
                Navigator.pop(context);
              },
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text("📍 الصفحة الرئيسية", style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
          centerTitle: true,
          backgroundColor: Colors.deepPurple,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, "/login");
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("اختر العميل:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("clients").snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final clients = snapshot.data!.docs;
                    if (clients.isEmpty) return const Text("لا يوجد عملاء مضافين بعد");

                    return DropdownButton2<String>(
                      isExpanded: true,
                      alignment: Alignment.centerRight,
                      hint: const Text("اختر العميل", textAlign: TextAlign.right),
                      underline: const SizedBox.shrink(),
                      items: clients.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(doc['name'], textAlign: TextAlign.right),
                                const Icon(Icons.person, color: Colors.deepPurple),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      value: selectedClient,
                      onChanged: (value) {
                        setState(() {
                          selectedClient = value;
                        });
                      },
                      selectedItemBuilder: (context) {
                        return clients.map((doc) {
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (selectedClient != null && selectedClient == doc.id) ...[
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedClient = null;
                                      });
                                    },
                                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                const Icon(Icons.person, color: Colors.deepPurple),
                                const SizedBox(width: 8),
                                Text(doc['name'], textAlign: TextAlign.right),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      dropdownStyleData: const DropdownStyleData(maxHeight: 300),
                      menuItemStyleData: const MenuItemStyleData(padding: EdgeInsets.only(right: 12)),
                      buttonStyleData: ButtonStyleData(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (!stopped)
                  ElevatedButton.icon(
                    onPressed: selectedClient == null ? _showAddClientDialog : null,
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    label: const Text(
                      "إضافة عميل جديد",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedClient == null ? Colors.deepPurple : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 20),
                if (!stopped)
                  if (!isLive)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (selectedClient == null || currentVisitId != null) ? null : () async {
                        try {
                          final position = await _getCurrentLocation();
                          final address = await _getAddress(position.latitude, position.longitude);
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) throw Exception("المستخدم غير مسجل دخول");

                          final clientDoc = await FirebaseFirestore.instance.collection("clients").doc(selectedClient).get();
                          if (!clientDoc.exists) throw Exception("العميل غير موجود");
                          final clientName = clientDoc["name"];

                          final repDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
                          final repData = repDoc.data() as Map<String, dynamic>?;

                          if (repData == null || !repData.containsKey("username")) throw Exception("حقل username غير موجود للمندوب");

                          final repName = repData["username"];

                          final doc = await FirebaseFirestore.instance.collection("visits").add({
                            "clientId": selectedClient,
                            "clientName": clientName,
                            "repName": repName,
                            "startTime": DateTime.now(),
                            "latitude": position.latitude,
                            "longitude": position.longitude,
                            "address": address,
                            "endTime": null,
                            "notes": "",
                            "userId": user.uid,
                            "lastUpdate": DateTime.now(),
                          });

                          await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
                            "isSharingLocation": true,
                            "latitude": position.latitude,
                            "longitude": position.longitude,
                            "lastUpdate": DateTime.now(),
                          });

                          locationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
                            try {
                              final newPos = await _getCurrentLocation();
                              final newAddress = await _getAddress(newPos.latitude, newPos.longitude);
                              await FirebaseFirestore.instance.collection("visits").doc(doc.id).update({
                                "latitude": newPos.latitude,
                                "longitude": newPos.longitude,
                                "address": newAddress,
                                "lastUpdate": DateTime.now(),
                              });
                              await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
                                "latitude": newPos.latitude,
                                "longitude": newPos.longitude,
                                "lastUpdate": DateTime.now(),
                              });
                            } catch (e) {
                              debugPrint("خطأ أثناء تحديث الموقع: $e");
                            }
                          });

                          setState(() {
                            isLive = true;
                            stopped = false;
                            currentVisitId = doc.id;
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                        }
                      },
                      child: const Text("ابدأ مشاركة موقعك", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    )
                  else if (!stopped)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        locationTimer?.cancel();
                        await FirebaseFirestore.instance.collection("visits").doc(currentVisitId).update({"endTime": DateTime.now()});
                        await FirebaseFirestore.instance.collection("users").doc(user?.uid).update({"isSharingLocation": false});
                        setState(() {
                          isLive = false;
                          stopped = true;
                        });
                      },
                      child: const Text("أوقف مشاركة الموقع", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                const SizedBox(height: 20),
                if (stopped) ...[
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: "✏️ ملاحظات",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSend ? Colors.deepPurple : Colors.deepPurple.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: canSend
                        ? () async {
                      await FirebaseFirestore.instance.collection("visits").doc(currentVisitId).update({
                        "endTime": DateTime.now(),
                        "notes": notesController.text.trim(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم حفظ الزيارة")));
                      setState(() {
                        stopped = false;
                        isLive = false;
                        notesController.clear();
                        currentVisitId = null;
                      });
                    }
                        : null,
                    child: const Text("إرسال", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
