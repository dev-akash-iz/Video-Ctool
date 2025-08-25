import 'package:flutter/material.dart';

class ActionBuilder {
  final String _name;
  final IconData _icon;
  final Function _onSelect;

  ActionBuilder(this._name, this._icon, this._onSelect);

  String getName() {
    return _name;
  }

  IconData getIcon() {
    return _icon;
  }

  Function getOnSelectFun() {
    return _onSelect;
  }
}
