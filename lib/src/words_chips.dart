import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wallet_words/src/constants.dart';
import 'package:wallet_words/src/extensions/extensions.dart';
import 'package:wallet_words/src/helpers.dart';
import 'package:wallet_words/src/models/type_defs.dart';
import 'package:wallet_words/src/suggestions_box_controller.dart';
import 'package:wallet_words/src/text_cursor.dart';

class WordsChip<T> extends StatefulWidget {
  const WordsChip({
    super.key,
    required this.chipBuilder,
    required this.onChanged,
    this.suggestionBuilder,
    this.findSuggestions,
    this.maxChips = 12,
    this.initialValue = const [],
    this.decoration = const InputDecoration(border: InputBorder.none),
    this.enabled = true,
    this.textStyle,
    this.suggestionsBoxMaxHeight,
    this.validator,
    this.textBoxDecoration = const BoxDecoration(),
    this.minTextBoxHeight = 200,
    this.textBoxWidth,
    this.textBoxPadding = const EdgeInsets.all(8),
    this.showSuggestionsOnTop = true,
    this.inputType = TextInputType.text,
    this.textOverflow = TextOverflow.clip,
    this.actionLabel,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.allowChipEditing = false,
    this.focusNode,
    this.initialSuggestions,
    this.suggestionsBoxDecoration = const BoxDecoration(),
    this.feedbackMsg,
    this.wordCountText,
    this.tooltip,
    this.tooltipBackgroundColor = const Color(0xff000000),
    this.tooltipArrowArc = 0.1,
    this.tooltipRadius = 5,
    this.tooltipArrowHeight = 4,
    this.tooltipArrowWidth = 10,
    this.tooltipHasArrow = false,
  })  : assert(
          initialValue.length <= maxChips,
          'Max chips must not be null and greater than initial value length ',
        ),
        assert(
          suggestionBuilder != null && findSuggestions != null,
          'Suggestion builder is not null, then find suggestions must not be null',
        );

  // Builders
  /// Builder used to create the chips.
  final ChipsBuilder<T> chipBuilder;

  /// Builder used to create the suggestions.
  final SuggestionsBuilder<T>? suggestionBuilder;

  /// Contains search logic to find the suggestions.
  final WordsChipSuggestions<T>? findSuggestions;

  /// Triggered when there's a new entry in the [List] of [T].
  final ValueChanged<List<T>> onChanged;

  /// Offers some customization for the text box.
  final InputDecoration decoration;

  /// [TextStyle] of the text written in the box.
  final TextStyle? textStyle;
  final bool enabled;

  /// Sets to show the suggestions on top of the text box.
  final bool showSuggestionsOnTop;

  /// [BoxDecoration] of the text box where the user writes the text.
  final BoxDecoration textBoxDecoration;

  /// Height of the text box.
  final double minTextBoxHeight;

  /// Width of the text box.
  final double? textBoxWidth;

  /// Padding for the chips in the text box.
  final EdgeInsets textBoxPadding;

  /// [List] of [T] with initial values to show
  final List<T> initialValue;

  /// Optional list of [T] to suggest
  final List<T>? initialSuggestions;

  /// Limit of the number of chips allowed.
  final int maxChips;

  /// Limit of the suggestions box height. It is compared with the minimun allowed space.
  final double? suggestionsBoxMaxHeight;

  /// Some text input customization.
  final TextInputType inputType;
  final TextOverflow textOverflow;

  /// What text to display in the text input control's action button..
  final String? actionLabel;

  /// What kind of action to request for the action button on the IME.
  final TextInputAction inputAction;

  /// [Brightness] of the keyboard.
  final Brightness? keyboardAppearance;

  /// Offers [TextCapitalization] options.
  final TextCapitalization textCapitalization;

  /// Sets to autofocus the text box as soon as widget is built.
  final bool autofocus;
  final bool allowChipEditing;

  /// Allows to set an external [FocusNode] for more control.
  final FocusNode? focusNode;

  final BoxDecoration suggestionsBoxDecoration;

  /// Optional function to validate input from user
  /// and show error message if input is invalid.
  final String Function(String)? validator;

  // Word counts
  /// Word count to show
  final Widget? wordCountText;

  // Status messsage
  /// Optionl message to show the user, providing feedback on what's been typed
  final Widget? feedbackMsg;

  /// Tooltip widget that may be displayed
  final Widget? tooltip;

  /// To allow tooltip arrow decoration as in iOS native tooltip.
  ///
  /// If false, you will have to provide your own decoration such as background color, borders, etc.
  final bool tooltipHasArrow;

  /// Tooltip background color for
  final Color tooltipBackgroundColor;

  /// Tooltip arrow arc
  final double tooltipArrowArc;

  /// Tooltip radius
  final double tooltipRadius;

  /// Tooltip arrow height
  final double tooltipArrowHeight;

  /// Tooltip arrow width
  final double tooltipArrowWidth;

  @override
  WordsChipState<T> createState() => WordsChipState<T>();
}

class WordsChipState<T> extends State<WordsChip<T>> implements TextInputClient {
  Set<T> _chips = <T>{};
  List<T?>? _suggestions;
  bool _showSuggestions = false;
  bool _showTooltip = false;
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
        actionLabel: widget.actionLabel,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance ??
            SchedulerBinding.instance.window.platformBrightness,
        textCapitalization: widget.textCapitalization,
        autocorrect: false,
      );

  bool get _hasInputConnection =>
      _textInputConnection != null && _textInputConnection!.attached;

  bool get _hasReachedMaxChips => _chips.length >= widget.maxChips;

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
    _showSuggestions = widget.suggestionBuilder != null;

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
    setState(() {
      _showTooltip = false;
    });
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
                child: Container(
                  decoration: widget.suggestionsBoxDecoration,
                  constraints: BoxConstraints(
                    maxHeight: suggestionBoxHeight,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (BuildContext context, int index) {
                      return (_suggestions != null && _showSuggestions)
                          ? widget.suggestionBuilder!(
                              context,
                              this,
                              _suggestions![index] as T,
                              _suggestions?.length ?? 0,
                            )
                          : Container();
                    },
                  ),
                ),
              );
              return Positioned(
                width: size.width,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: compositedTransformFollowerOffset,
                  child: showTop
                      ? FractionalTranslation(
                          translation: const Offset(0, -1),
                          child: suggestionsListView,
                        )
                      : suggestionsListView,
                ),
              );
            }
            return Container();
          },
        );
      },
    );
  }

  /// Sets the selected suggestions to the textbox
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

  /// Deletes the user tapped chip
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

  /// Handles the search for suggestions.
  Future<void> _onSearchChanged(String value) async {
    if (value.contains(' ') || value.isEmpty) {
      _suggestionsBoxController.close();
      return;
    }

    if (_showSuggestions && widget.findSuggestions != null) {
      final localId = ++_searchId;
      final results = await widget.findSuggestions!(value);
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
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection!.close();
      _textInputConnection = null;
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    final oldTextEditingValue = _value;
    if (value.text != oldTextEditingValue.text) {
      setState(() {
        _value = value;
      });
      if (_value.text.contains(' ')) {
        final updatedText = _value.text.replaceAll(' ', '');
        final updatex = updatedText.substring(_chips.length);

        setState(
          () {
            _suggestions = null;
            _chips = _chips..add(updatex as T);
          },
        );
        _updateTextInputState(replaceText: true);
        widget.onChanged(_chips.toList(growable: false));

        _suggestionsStreamController.add(_suggestions);
      } else if (value.replacementCharactersCount <
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

  void _updateTextInputState({
    bool replaceText = false,
    String putText = '',
  }) {
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
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

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
          children: [
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: requestKeyboard,
              onLongPressEnd: (_) => setState(() {
                _showTooltip = true;
              }),
              child: InputDecorator(
                decoration: widget.decoration,
                isFocused: _effectiveFocusNode.hasFocus,
                isEmpty: _value.text.isEmpty && _chips.isEmpty,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        minHeight: widget.minTextBoxHeight,
                      ),
                      width: widget.textBoxWidth ?? double.maxFinite,
                      decoration: widget.textBoxDecoration,
                      padding: widget.textBoxPadding,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: chipsChildren,
                      ),
                    ),
                    if (widget.tooltip != null && _showTooltip)
                      TextButton(
                        onPressed: () async {
                          final copiedString =
                              (await Clipboard.getData(Clipboard.kTextPlain))
                                      ?.text ??
                                  '';
                          final wordList = copiedString.split(' ');

                          final length = min(widget.maxChips, wordList.length);
                          // Copies only the words that are allowed by maxChips variable
                          for (var i = 0; i < length; i++) {
                            selectSuggestion(wordList[i] as T);
                          }

                          setState(() {
                            _showTooltip = false;
                          });
                        },
                        child: widget.tooltipHasArrow
                            ? DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: widget.tooltipBackgroundColor,
                                  shape: TooltipShapeBorder(
                                    arrowArc: widget.tooltipArrowArc,
                                    radius: widget.tooltipRadius,
                                    arrowHeight: widget.tooltipArrowHeight,
                                    arrowWidth: widget.tooltipArrowWidth,
                                  ),
                                ),
                                child: widget.tooltip,
                              )
                            : Container(
                                child: widget.tooltip,
                              ),
                      ),
                  ],
                ),
              ),
            ),
            CompositedTransformTarget(
              link: _layerLink,
              child: const SizedBox.shrink(),
            ),
            if (widget.wordCountText != null)
              Align(
                alignment: Alignment.centerRight,
                child: widget.wordCountText,
              ),
            if (widget.feedbackMsg != null) widget.feedbackMsg!,
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
