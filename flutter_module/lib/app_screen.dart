import 'package:flutter/material.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  final List<String> cities = [
    'Tokyo',
    'New York',
    'London',
    'Paris',
    'Singapore',
    'Dubai',
    'Rome',
    'Barcelona',
    'Sydney',
    'Hong Kong',
    'Berlin',
    'Moscow',
    'Toronto',
    'Amsterdam',
    'Seoul',
    'Mumbai',
    'Bangkok',
    'Istanbul',
    'Rio de Janeiro',
    'Vienna',
    'Prague',
    'Cape Town',
    'Stockholm',
    'Buenos Aires',
    'Madrid',
    'Venice',
    'San Francisco',
    'Vancouver',
    'Copenhagen',
    'Dublin',
    'Davao'
  ];

  List<String> generateRandomCities() {
    List<String> randomCities = [];
    for (int i = 0; i < 1000; i++) {
      randomCities.add('${cities[i % cities.length]} #${i + 1}');
    }
    return randomCities;
  }

  @override
  Widget build(BuildContext context) {
    final randomCities = generateRandomCities();

    return Scaffold(
      appBar: AppBar(
        title: const Text('World Cities'),
        elevation: 2,
      ),
      body: ListView.builder(
        itemCount: randomCities.length,
        itemExtent: 72.0,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(randomCities[index]),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Handle tap event
                debugPrint('Tapped on ${randomCities[index]}');
              },
            ),
          );
        },
      ),
    );
  }
}
