import 'package:mydatatools/models/tables/collection.dart';
import 'package:flutter/material.dart';

class ChangeCollectionNotification extends Notification {
  final Collection? val;
  ChangeCollectionNotification(this.val);
}
