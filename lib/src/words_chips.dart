import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wallet_words/src/constants.dart';
import 'package:wallet_words/src/extensions/extensions.dart';
import 'package:wallet_words/src/helpers.dart';

import 'package:wallet_words/src/suggestions_box_controller.dart';
import 'package:wallet_words/src/text_cursor.dart';
import 'package:wallet_words/src/type_defs/type_defs.dart';

class WordsChip<T> extends StatefulWidget {
  const WordsChip({
    super.key,
    required this.chipBuilder,
    required this.suggestionBuilder,
    required this.findSuggestions,
    required this.onChanged,
    required this.maxChips,
    this.initialValue = const [],
    this.decoration = const InputDecoration(border: InputBorder.none),
    this.enabled = true,
    this.textStyle,
    this.suggestionsBoxMaxHeight,
    this.textBoxDecoration = const BoxDecoration(),
    this.textBoxHeight = 200,
    this.showSuggestionsOnTop = true,
    this.inputType = TextInputType.text,
    this.textOverflow = TextOverflow.clip,
    this.obscureText = false,
    this.autocorrect = false,
    this.actionLabel,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.allowChipEditing = false,
    this.focusNode,
    this.initialSuggestions,
    this.suggestionsBoxDecoration = const BoxDecoration(),
  }) : assert(
          maxChips == null || initialValue.length <= maxChips,
          'Max chips must not be null and greater than initial value length ',
        );

  final InputDecoration decoration;
  final TextStyle? textStyle;
  final bool enabled;
  final WordsChipSuggestions<T> findSuggestions;
  final ValueChanged<List<T>> onChanged;
  final ChipsBuilder<T> chipBuilder;
  final SuggestionsBuilder<T> suggestionBuilder;
  final bool showSuggestionsOnTop;
  final BoxDecoration textBoxDecoration;
  final double textBoxHeight;
  final List<T> initialValue;
  final int? maxChips;
  final double? suggestionsBoxMaxHeight;
  final TextInputType inputType;
  final TextOverflow textOverflow;
  final bool obscureText;
  final bool autocorrect;
  final String? actionLabel;
  final TextInputAction inputAction;
  final Brightness keyboardAppearance;
  final bool autofocus;
  final bool allowChipEditing;
  final FocusNode? focusNode;
  final List<T>? initialSuggestions;
  final BoxDecoration suggestionsBoxDecoration;

  final TextCapitalization textCapitalization;

  @override
  WordsChipState<T> createState() => WordsChipState<T>();
}

class WordsChipState<T> extends State<WordsChip<T>> implements TextInputClient {
  Set<T> _chips = <T>{};
  List<T?>? _suggestions;
  final StreamController<List<T?>?> _suggestionsStreamController =
      StreamController<List<T>?>.broadcast();
  int _searchId = 0;
  TextEditingValue _value = TextEditingValue.empty;
  TextInputConnection? _textInputConnection;
  late SuggestionsBoxController _suggestionsBoxController;
  final _layerLink = LayerLink();
  final Map<T?, String> _enteredTexts = <T, String>{};

  TextInputConfiguration get textInputConfiguration => TextInputConfiguration(
        inputType: widget.inputType,
        autocorrect: widget.autocorrect,
        actionLabel: widget.actionLabel,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance,
        textCapitalization: widget.textCapitalization,
      );

  bool get _hasInputConnection =>
      _textInputConnection != null && _textInputConnection!.attached;

  bool get _hasReachedMaxChips =>
      widget.maxChips != null && _chips.length >= widget.maxChips!;

  FocusNode? _focusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_focusNode ??= FocusNode());
  late FocusAttachment _nodeAttachment;

  RenderBox? get renderBox => context.findRenderObject() as RenderBox?;

  bool get _canRequestFocus => widget.enabled;

  @override
  void initState() {
    super.initState();
    _chips.addAll(widget.initialValue);
    final initialText =
        String.fromCharCodes(_chips.map((_) => kObjectReplacementChar));
    _value = TextEditingValue(
      text: initialText,
      selection: TextSelection.collapsed(offset: initialText.length),
    );
    _suggestions = widget.initialSuggestions
        ?.where((r) => !_chips.contains(r))
        .toList(growable: false);
    _suggestionsBoxController = SuggestionsBoxController(context);

    _effectiveFocusNode.addListener(_handleFocusChanged);
    _nodeAttachment = _effectiveFocusNode.attach(context);
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final renderBox = context.findRenderObject() as RenderBox?;
      assert(
        renderBox != null,
        "This cannot be null because it's called after the build",
      );

      _initOverlayEntry(renderBox!);
      if (mounted && widget.autofocus) {
        FocusScope.of(context).autofocus(_effectiveFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _closeInputConnectionIfNeeded();
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _focusNode?.dispose();
    _suggestionsStreamController.close();
    _suggestionsBoxController.close();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_effectiveFocusNode.hasFocus) {
      _openInputConnection();
      _suggestionsBoxController.open();
    } else {
      _closeInputConnectionIfNeeded();
      _suggestionsBoxController.close();
    }
    if (mounted) {
      setState(() {
        /*rebuild so that _TextCursor is hidden.*/
      });
    }
  }

  void requestKeyboard() {
    if (_effectiveFocusNode.hasFocus) {
      _openInputConnection();
    } else {
      FocusScope.of(context).requestFocus(_effectiveFocusNode);
    }
  }

  void _initOverlayEntry(RenderBox renderBox) {
    _suggestionsBoxController.overlayEntry = OverlayEntry(
      builder: (context) {
        final size = renderBox.size;
        final renderBoxOffset = renderBox.localToGlobal(Offset.zero);
        final showTop = widget.showSuggestionsOnTop;
        var suggestionBoxHeight =
            UIHelpers.getSuggestedBoxHeight(context, size, renderBoxOffset);
        if (widget.suggestionsBoxMaxHeight != null) {
          suggestionBoxHeight =
              min(suggestionBoxHeight, widget.suggestionsBoxMaxHeight!);
        }

        final compositedTransformFollowerOffset =
            showTop ? Offset(0, -size.height) : Offset.zero;

        return StreamBuilder<List<T?>?>(
          stream: _suggestionsStreamController.stream,
          initialData: _suggestions,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final suggestionsListView = Material(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: suggestionBoxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: widget.suggestionsBoxDecoration,
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _suggestions != null
                            ? widget.suggestionBuilder(
                                context,
                                this,
                                _suggestions![index] as T,
                                _suggestions?.length ?? 0,
                              )
                            : Container();
                      },
                    ),
                  ),
                ),
              );
              return Positioned(
                width: size.width,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: compositedTransformFollowerOffset,
                  child: !showTop
                      ? suggestionsListView
                      : FractionalTranslation(
                          translation: const Offset(0, -1),
                          child: suggestionsListView,
                        ),
                ),
              );
            }
            return Container();
          },
        );
      },
    );
  }

  void selectSuggestion(T data) {
    if (!_hasReachedMaxChips) {
      setState(() => _chips = _chips..add(data));
      if (widget.allowChipEditing) {
        final enteredText = _value.normalCharactersText;
        if (enteredText.isNotEmpty) _enteredTexts[data] = enteredText;
      }
      _updateTextInputState(replaceText: true);
      setState(() => _suggestions = null);
      _suggestionsStreamController.add(_suggestions);
      if (_hasReachedMaxChips) _suggestionsBoxController.close();
      widget.onChanged(_chips.toList(growable: false));
    } else {
      _suggestionsBoxController.close();
    }
  }

  void deleteChip(T data) {
    if (widget.enabled) {
      setState(() => _chips.remove(data));
      if (_enteredTexts.containsKey(data)) _enteredTexts.remove(data);
      _updateTextInputState();
      widget.onChanged(_chips.toList(growable: false));
    }
  }

  void _openInputConnection() {
    if (!_hasInputConnection) {
      _textInputConnection = TextInput.attach(this, textInputConfiguration);
      _textInputConnection!.show();
      _updateTextInputState();
    } else {
      _textInputConnection?.show();
    }

    _scrollToVisible();
  }

  void _scrollToVisible() {
    Future.delayed(const Duration(milliseconds: 300), () {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final renderBox = context.findRenderObject();
        if (renderBox != null) {
          await Scrollable.of(context)?.position.ensureVisible(renderBox);
        }
      });
    });
  }

  Future<void> _onSearchChanged(String value) async {
    final localId = ++_searchId;
    final results = await widget.findSuggestions(value);
    if (_searchId == localId && mounted) {
      setState(
        () => _suggestions =
            results.where((r) => !_chips.contains(r)).toList(growable: false),
      );
    }
    _suggestionsStreamController.add(_suggestions ?? []);
    if (!_suggestionsBoxController.isOpened && !_hasReachedMaxChips) {
      _suggestionsBoxController.open();
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection!.close();
      _textInputConnection = null;
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    //print("updateEditingValue FIRED with ${value.text}");
    // _receivedRemoteTextEditingValue = value;
    final oldTextEditingValue = _value;
    if (value.text != oldTextEditingValue.text) {
      setState(() => _value = value);
      if (value.replacementCharactersCount <
          oldTextEditingValue.replacementCharactersCount) {
        final removedChip = _chips.last;
        setState(
          () => _chips = Set.of(_chips.take(value.replacementCharactersCount)),
        );
        widget.onChanged(_chips.toList(growable: false));
        String? putText = '';
        if (widget.allowChipEditing && _enteredTexts.containsKey(removedChip)) {
          putText = _enteredTexts[removedChip] ?? '';
          _enteredTexts.remove(removedChip);
        }
        _updateTextInputState(putText: putText);
      } else {
        _updateTextInputState();
      }
      _onSearchChanged(_value.normalCharactersText);
    }
  }

  void _updateTextInputState({bool replaceText = false, String putText = ''}) {
    if (replaceText || putText != '') {
      final updatedText =
          String.fromCharCodes(_chips.map((_) => kObjectReplacementChar)) +
              (replaceText ? '' : _value.normalCharactersText) +
              putText;
      setState(
        () => _value = _value.copyWith(
          text: updatedText,
          selection: TextSelection.collapsed(offset: updatedText.length),
          //composing: TextRange(start: 0, end: text.length),
          composing: TextRange.empty,
        ),
      );
    }
    // _closeInputConnectionIfNeeded(); //Hack for #34 (https://github.com/danvick/wallet_words/issues/34#issuecomment-684505282). TODO: Find permanent fix
    _textInputConnection ??= TextInput.attach(this, textInputConfiguration);
    _textInputConnection?.setEditingState(_value);
    _textInputConnection?.show();
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.send:
      case TextInputAction.search:
        if (_suggestions?.isNotEmpty ?? false) {
          selectSuggestion(_suggestions!.first as T);
        } else {
          _effectiveFocusNode.unfocus();
        }
        break;

      // others
      case TextInputAction.none:
      case TextInputAction.unspecified:
      case TextInputAction.next:
      case TextInputAction.previous:
      case TextInputAction.continueAction:
      case TextInputAction.join:
      case TextInputAction.route:
      case TextInputAction.emergencyCall:
      case TextInputAction.newline:
        _effectiveFocusNode.unfocus();
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    //TODO
  }

  @override
  void didUpdateWidget(covariant WordsChip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // print(point);
  }

  @override
  void connectionClosed() {
    //print('TextInputClient.connectionClosed()');
  }

  @override
  TextEditingValue get currentTextEditingValue => _value;

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  Widget build(BuildContext context) {
    _nodeAttachment.reparent();
    final chipsChildren = _chips
        .map<Widget>((data) => widget.chipBuilder(context, this, data))
        .toList();

    final theme = Theme.of(context);

    chipsChildren.add(
      SizedBox(
        height: 30,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                _value.normalCharactersText,
                maxLines: 1,
                overflow: widget.textOverflow,
                style: widget.textStyle ??
                    theme.textTheme.subtitle1!.copyWith(height: 1.5),
              ),
            ),
            Flexible(
              flex: 0,
              child: TextCursor(resumed: _effectiveFocusNode.hasFocus),
            ),
          ],
        ),
      ),
    );

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (SizeChangedLayoutNotification val) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _suggestionsBoxController.overlayEntry?.markNeedsBuild();
        });
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Column(
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: requestKeyboard,
              child: InputDecorator(
                decoration: widget.decoration,
                isFocused: _effectiveFocusNode.hasFocus,
                isEmpty: _value.text.isEmpty && _chips.isEmpty,
                child: Container(
                  height: widget.textBoxHeight,
                  decoration: widget.textBoxDecoration,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: chipsChildren,
                  ),
                ),
              ),
            ),
            CompositedTransformTarget(
              link: _layerLink,
              child: Container(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void showToolbar() {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}
}
