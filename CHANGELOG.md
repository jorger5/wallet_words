## [2.0.0]

- Updated to Dart 2.18 and Flutter 3.7

## [1.1.4]

- Allowed suggestions to show repeated words.

## [1.1.3]

- Changed from Set to List of chips to allow for duplicate words.

## [1.1.2]

- Add capability to allow the user to type non-sense words and hide the keyboard after a certain number

## [1.1.1]

- Add optional enable keyboard native suggestions for words typed.

## [1.1.0+3]

- Fix word adding on space bar pressed.

## [1.1.0+2]

- Fix word paste from Android native keyboard.

## [1.1.0+1]

- Provide pasted wordList to onChanged callback
- Clear hidden special characters from pasted items

## [1.1.0]

- Words are no longer added when pressing space as empty chips
- Created "suggestionsHeightFromTop" parameter which takes a double and allows to set the suggestion box from the top of the screen

## [1.0.7]

- Fix defunct state error by adding a if(mounted) on initState

## [1.0.6]

- Added adaptive textbox size and customizable tooltip box.
- Better 'Paste' logic for tooltip

## [1.0.5]

- Added better examples file and images.

## [1.0.4]

- Minor corrections and better comments.

## [1.0.3]

- Added paste words capability, now a user sees a tooltip and can paste.

## [1.0.2]

- Simplified feedback msg, now passing just a widget that renders if != null

## [1.0.1]

- Added close suggestion box on empty text box.
- Now word adds when user presses the space bar.

## [1.0.0]

- Initial release.
