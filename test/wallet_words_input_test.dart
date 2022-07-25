import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_words/wallet_words.dart';

void main() {
  const words = [
    'Hello',
    'Desk',
    'Abandone',
    'Jane Smith',
  ];

  testWidgets('Chips Inputs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordsChip<String>(
            initialValue: words.sublist(1, 3),
            maxChips: 3,
            findSuggestions: (String query) => query.isNotEmpty
                ? words
                    .where((_) => _.toLowerCase().contains(query.toLowerCase()))
                    .toList()
                : const [],
            onChanged: (contacts) {
              debugPrint(contacts.toString());
            },
            chipBuilder: (context, state, contact) {
              return InputChip(
                key: ValueKey(contact),
                label: Text(contact),
                onDeleted: () => state.deleteChip(contact),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            },
            suggestionBuilder: (context, state, contact, qty) {
              return ListTile(
                key: ValueKey(contact),
                title: Text(contact),
                onTap: () => state.selectSuggestion(contact),
              );
            },
          ),
        ),
      ),
    );
  });
}
