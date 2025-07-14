import 'package:flutter/material.dart';

class PetDetailScreen extends StatelessWidget {
  final Map<String, dynamic> pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pet['name'] ?? 'Detay')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  pet['image'],
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet['name'] ?? 'İsimsiz',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    infoRow(Icons.pets, 'Tür', pet['type']),
                    infoRow(Icons.cake, 'Yaş', pet['age'].toString()),
                    infoRow(Icons.male, 'Cinsiyet', pet['gender']),
                    infoRow(Icons.vaccines, 'Aşılı',
                        pet['vaccinated'] == true ? 'Evet' : 'Hayır'),
                    infoRow(Icons.cut, 'Kısırlaştırılmış',
                        pet['neutered'] == true ? 'Evet' : 'Hayır'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 8),
          Text(
            "$label: $value",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
