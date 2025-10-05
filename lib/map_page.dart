import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "الخريطة الكاملة 🗺️",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // سهم الرجوع
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // نجيب المندوبين اللي عاملين مشاركة موقع (لايف)
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("isSharingLocation", isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final onlineUsers = snapshot.data!.docs;

          return FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(30.0444, 31.2357), // القاهرة كمثال
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: onlineUsers.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lat = data["latitude"];
                  final lng = data["longitude"];
                  final repName = data["repName"] ?? "مندوب";

                  if (lat == null || lng == null) return null;

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 80,
                    height: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            repName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  );
                }).whereType<Marker>().toList(),
              )
            ],
          );
        },
      ),
    );
  }
}
