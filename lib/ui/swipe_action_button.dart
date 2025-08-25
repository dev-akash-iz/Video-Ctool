import 'package:flutter/material.dart';
import 'package:video_ctool/utils/class_entity/actions_builder.dart';

class SwipeButton extends StatefulWidget {
  final List<ActionBuilder>? actions;

  const SwipeButton({super.key, required this.actions});

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> {
  bool isSelectFile = true; // Tracks button state
  int currentButtonIndex = 0;
  int _actionLength = 0;
  bool _canSwipe = true;

  @override
  void initState() {
    super.initState();
    _actionLength = (widget.actions?.length ?? 0);
  }

  void _resetSwipe(DragEndDetails details) {
    setState(() {
      _canSwipe = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd:
          _resetSwipe, // reset on lift so again swipe to change another
      onVerticalDragUpdate: (details) {
        if (_canSwipe &&
            details.primaryDelta! < -6 &&
            (currentButtonIndex + 1) < _actionLength) {
          // logic is if it is swiped up and if

          setState(() {
            _canSwipe = false;
            ++currentButtonIndex;
          });
        } else if (_canSwipe &&
            details.primaryDelta! > 6 &&
            (currentButtonIndex - 1) > -1) {
          setState(() {
            _canSwipe = false;
            --currentButtonIndex;
          });
        }
      },
      child: ElevatedButton.icon(
        onPressed: () {
          widget.actions![currentButtonIndex].getOnSelectFun().call();
        },
        icon: Icon(widget.actions![currentButtonIndex].getIcon()),
        label: Text(widget.actions![currentButtonIndex].getName()),
      ),
    );
  }
}
