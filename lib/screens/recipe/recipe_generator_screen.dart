import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/recipe_viewmodel.dart';

class RecipeGeneratorScreen extends StatefulWidget {
  const RecipeGeneratorScreen({super.key});

  @override
  State<RecipeGeneratorScreen> createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends State<RecipeGeneratorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<RecipeViewModel>().fetchInventory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (vm.allItems.isEmpty)
                  const Center(child: CircularProgressIndicator()),

                if (vm.allItems.isNotEmpty)
                  CheckboxListTile(
                    title: const Text("Select All"),
                    value: vm.isAllSelected(),
                    onChanged: (val) => vm.toggleSelectAll(val ?? false),
                  ),

                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: vm.allItems.map((item) {
                    return FilterChip(
                      label: Text(item),
                      selected: vm.isItemSelected(item),
                      onSelected: (_) => vm.toggleItem(item),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text("Generate Recipe"),
                  onPressed: vm.loading ? null : vm.generateRecipe,
                ),

                const SizedBox(height: 20),

                if (vm.loading) const CircularProgressIndicator(),

                if (vm.result != null)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(vm.result!),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
