import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class PlaceholderCompra extends StatelessWidget {
  const PlaceholderCompra({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.shopping_placeholder_title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.shopping_placeholder_body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 8,
          child: IgnorePointer(
            ignoring: true,
            child: FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: Colors.grey.withValues(alpha: 0),
              elevation: 0,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!
                        .shopping_placeholder_top,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_upward,
                    color: Colors.grey,
                    size: 38,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
