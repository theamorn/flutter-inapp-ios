import 'package:flutter/material.dart';

class ActionButtonWidget extends StatefulWidget {
  final VoidCallback onPressed;
  final String title;
  final MaterialAccentColor color;
  final Alignment align;

  const ActionButtonWidget(
    this.color,
    this.title,
    this.align,
    this.onPressed, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButtonWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: widget.align,
        child: SizedBox(
            width: 100,
            child: TextButton(
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(widget.color.shade200),
                    foregroundColor: MaterialStateProperty.all(Colors.white)),
                onPressed: () {
                  widget.onPressed();
                },
                child: Text(widget.title))));
  }
}
