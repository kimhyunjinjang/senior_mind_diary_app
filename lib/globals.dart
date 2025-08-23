import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

//library globals;

bool isGuardianMode = false; // 보호자 모드 여부
String? linkedUserId; // 시니어 UID
final ValueNotifier<bool> isLinkedNotifier = ValueNotifier(false); // 공유 상태