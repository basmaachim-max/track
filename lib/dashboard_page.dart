import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'map_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? selectedRep;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة تحكم المدير 📊", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) Navigator.pushReplacementNamed(context, "/login");
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("visits").snapshots(),
        builder: (context, visitsSnapshot) {
          if (!visitsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final visits = visitsSnapshot.data!.docs;

          // Offline visits
          final offlineVisits = visits.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data["endTime"] != null;
          }).toList();

          // Reps list for dropdown
          final reps = visits
              .map((doc) => (doc.data() as Map<String, dynamic>)["username"] ?? "")
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

          // Filter offline visits
          final filteredOffline = selectedRep == null
              ? offlineVisits
              : offlineVisits.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data["username"] ?? "") == selectedRep;
          }).toList();

          // Sort from newest to oldest
          filteredOffline.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final endA = dataA["endTime"];
            final endB = dataB["endTime"];

            if (endA == null && endB == null) return 0;
            if (endA == null) return 1;
            if (endB == null) return -1;

            return (endB as Timestamp).compareTo(endA as Timestamp);
          });

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .where("isSharingLocation", isEqualTo: true)
                .snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final onlineUsers = usersSnapshot.data!.docs;

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // Dropdown لاختيار المندوب
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DropdownButtonFormField2<String>(
                        isExpanded: true,
                        value: selectedRep,
                        decoration: const InputDecoration(
                          labelText: "اختر المندوب",
                          border: OutlineInputBorder(),
                        ),
                        items: reps.map((rep) {
                          return DropdownMenuItem<String>(
                            value: rep,
                            child: Row(
                              children: [
                                Text(rep, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                const Icon(Icons.person, color: Colors.deepPurple, size: 20),
                              ],
                            ),
                          );
                        }).toList(),
                        selectedItemBuilder: (context) {
                          return reps.map((rep) => Row(
                            children: [
                              const Icon(Icons.person, color: Colors.deepPurple, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rep,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )).toList();
                        },
                        onChanged: (value) {
                          setState(() {
                            selectedRep = value;
                          });
                        },
                        dropdownStyleData: const DropdownStyleData(isOverButton: false, maxHeight: 300),
                      ),
                    ),

                    // Map of online reps
                    Expanded(
                      flex: 2,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(30.0444, 31.2357),
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(
                            markers: onlineUsers.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final lat = data["latitude"];
                              final lng = data["longitude"];

                              // 🔹 استخدم username بدل repName
                              final repName = data.containsKey("username") ? data["username"] : "غير معروف";

                              if (lat == null || lng == null) return null;

                              return Marker(
                                point: LatLng(lat, lng),
                                width: 80,
                                height: 80,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
                                      ),
                                      child: Text(
                                        repName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.location_on, color: Colors.red, size: 40),
                                  ],
                                ),
                              );
                            }).whereType<Marker>().toList(),
                          )
                        ],
                      ),
                    ),

                    // Offline visits list
                    Expanded(
                      flex: 3,
                      child: ListView.builder(
                        itemCount: filteredOffline.length,
                        itemBuilder: (context, index) {
                          final data = filteredOffline[index].data() as Map<String, dynamic>;
                          final repName = data["username"] ?? "غير معروف";
                          final clientName = data["clientName"] ?? "بدون عميل";
                          final address = data["address"] ?? "بدون عنوان";
                          final notes = data["notes"] ?? "لا يوجد";
                          final startTime = data["startTime"]?.toDate()?.toString() ?? "";
                          final endTime = data["endTime"]?.toDate()?.toString() ?? "";

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [const Icon(Icons.person, size: 20, color: Colors.deepPurple), const SizedBox(width: 6), Text("اسم المندوب: $repName")]),
                                  const SizedBox(height: 6),
                                  Row(children: [const Icon(Icons.business, size: 20, color: Colors.deepPurple), const SizedBox(width: 6), Text("اسم العميل: $clientName")]),
                                  const SizedBox(height: 6),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.location_on, size: 20, color: Colors.deepPurple), const SizedBox(width: 6), Expanded(child: Text("العنوان: $address"))]),
                                  const SizedBox(height: 6),
                                  Row(children: [const Icon(Icons.play_arrow, size: 20, color: Colors.green), const SizedBox(width: 6), Text("من: $startTime")]),
                                  const SizedBox(height: 6),
                                  Row(children: [const Icon(Icons.stop, size: 20, color: Colors.red), const SizedBox(width: 6), Text("إلى: $endTime")]),
                                  const SizedBox(height: 6),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.notes, size: 20, color: Colors.deepPurple), const SizedBox(width: 6), Expanded(child: Text("ملاحظات: $notes"))]),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
