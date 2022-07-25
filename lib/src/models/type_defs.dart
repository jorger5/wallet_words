import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wallet_words/src/words_chips.dart';

/// [List] of selected [T] to search in for the [query] the [WordsChip]
typedef WordsChipSuggestions<T> = FutureOr<List<T>> Function(String query);

/// [Builder] that returns a [Widget] to display chips of selected words.
typedef ChipsBuilder<T> = Widget Function(
  BuildContext context,
  WordsChipState<T> state,
  T data,
);

/// [Builder] that returns a [Widget] to display a list of suggestions.
typedef SuggestionsBuilder<T> = Widget Function(
  BuildContext context,
  WordsChipState<T> state,
  T data,
  int suggestionsQty,
);
typedef WordSelected<T> = void Function(T data, bool selected);
