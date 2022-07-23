# wallet_words

Flutter package used for building an input field that uses chips as wallet input by the user.
Inspired by [Flutter Chips Input](https://pub.dev/packages/flutter_chips_input)

## Usage

### Installation

Follow installation instructions [here](https://pub.dartlang.org/packages/wallet_words#-installing-tab-)

### Import

```dart
import 'package:wallet_words/wallet_words.dart';
```

### Example

#### WordsInput

```dart
WordsChip(
    initialValue: [
        AppProfile('John Doe', 'jdoe@flutter.io', 'https://d2gg9evh47fn9z.cloudfront.net/800px_COLOURBOX4057996.jpg')
    ],
    decoration: InputDecoration(
        labelText: "Select People",
    ),
    maxChips: 3,
    findSuggestions: (String query) {
        if (query.length != 0) {
            var lowercaseQuery = query.toLowerCase();
            return mockResults.where((profile) {
                return profile.name.toLowerCase().contains(query.toLowerCase()) || profile.email.toLowerCase().contains(query.toLowerCase());
            }).toList(growable: false)
                ..sort((a, b) => a.name
                    .toLowerCase()
                    .indexOf(lowercaseQuery)
                    .compareTo(b.name.toLowerCase().indexOf(lowercaseQuery)));
        } else {
            return const <AppProfile>[];
        }
    },
    onChanged: (data) {
        print(data);
    },
    chipBuilder: (context, state, profile) {
        return InputChip(
            key: ObjectKey(profile),
            label: Text(profile.name),
            avatar: CircleAvatar(
                backgroundImage: NetworkImage(profile.imageUrl),
            ),
            onDeleted: () => state.deleteChip(profile),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    },
    suggestionBuilder: (context, state, profile) {
        return ListTile(
            key: ObjectKey(profile),
            leading: CircleAvatar(
                backgroundImage: NetworkImage(profile.imageUrl),
            ),
            title: Text(profile.name),
            subtitle: Text(profile.email),
            onTap: () => state.selectSuggestion(profile),
        );
    },
)
```
