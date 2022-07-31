import 'package:appsize/appsize.dart';
import 'package:flutter/material.dart';
import 'package:wallet_words/wallet_words.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet words',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // brightness: Brightness.dark,
      ),
      home: const MyHomePage(),
      builder: (context, child) {
        return AppSize(builder: (context, orientation, deviceType) => child!);
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _chipKey = GlobalKey<WordsChipState>();
  int _wordCount = 0;

  @override
  Widget build(BuildContext context) {
    const mockWords = [
      'abandon',
      'hello',
      'cliff',
      'desk',
      'office',
      'phone',
      'food',
      'pizza',
      'car',
      'motorcycle',
      'bus'
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet words Input Example')),
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              WordsChip<String>(
                key: _chipKey,
                chipBuilder: (context, state, String word) {
                  return InputChip(
                    key: ObjectKey(word),
                    label: Text(word),
                    onDeleted: () => state.deleteChip(word),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
                suggestionBuilder: (context, state, String word, qty) {
                  return ListTile(
                    key: ObjectKey(word),
                    title: Text(word),
                    onTap: () => state.selectSuggestion(word),
                  );
                },
                findSuggestions: (String query) {
                  if (query.isNotEmpty) {
                    final lowercaseQuery = query.toLowerCase();
                    return mockWords.where((word) {
                      return word.toLowerCase().contains(query.toLowerCase());
                    }).toList(growable: false)
                      ..sort(
                        (a, b) =>
                            a.toLowerCase().indexOf(lowercaseQuery).compareTo(
                                  b.toLowerCase().indexOf(lowercaseQuery),
                                ),
                      );
                  }
                  return mockWords;
                },
                onChanged: (List<String> data) {
                  setState(() {
                    _wordCount = data.length;
                  });
                },
                keyboardAppearance: Brightness.dark,
                textCapitalization: TextCapitalization.words,
                textBoxDecoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(
                  height: 1.5,
                  fontFamily: 'Roboto',
                  fontSize: 16,
                ),
                validator: (data) {
                  if (data.isEmpty) {
                    return 'Please select at least one person';
                  }
                  return 'error';
                },
                showSuggestionsOnTop: false,
                feedbackMsg: Row(
                  children: const [
                    Icon(Icons.cancel, size: 20, color: Colors.red),
                    Text('Custom Error msg'),
                  ],
                ),
                wordCountText: Text('$_wordCount words'),
                tooltip: SizedBox(
                  width: 70.sp,
                  height: 35.sp,
                  child: const Center(
                    child: Text(
                      'Paste',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                tooltipArrowHeight: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
