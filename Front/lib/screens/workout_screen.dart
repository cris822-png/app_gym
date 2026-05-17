import 'package:flutter/material.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entreno en curso'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Fuerza - Piernas'),
                subtitle: const Text('Sentadillas, Peso muerto, Lunges'),
                trailing: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Comenzar'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: List.generate(
                  5,
                  (index) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Ejercicio ${index + 1}'),
                      subtitle: const Text('3 series x 8-10 reps'),
                      trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.check_circle_outline)),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
