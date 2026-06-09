import 'package:flutter/material.dart';
import 'package:flutter_native_data_detector/flutter_native_data_detector.dart';

/// Shared visual tokens for the example app, mirroring the reference
/// react-native-data-detector example.
abstract final class C {
  static const bg = Color(0xFF0B0C10);
  static const surface = Color(0xFF16181D);
  static const surfaceHi = Color(0xFF1E2128);
  static const border = Color(0x14FFFFFF); // white @ 8%
  static const text = Color(0xFFF4F4F6);
  static const muted = Color(0xFF8B8D98);
  static const accent = Color(0xFF6366F1);
}

/// Horizontal screen inset. Shared so full-bleed rows can cancel it precisely.
const screenPadding = 20.0;

const sampleText =
    'Call me at (555) 123-4567 or email john@example.com tomorrow at 9:30pm.';

/// Sentence auto-typed by the Demo button — hits all five entity types.
const demoText =
    "Tomorrow, I'll be at 1 Infinite Loop. Give me a call at (555) 123-4567, "
    'or email john@example.com. You can check the details at example.com';

/// Chip colors reuse the package's palette so all surfaces stay in sync.
const typeColors = defaultEntityColors;

const typeLabels = <DetectionType, String>{
  DetectionType.phoneNumber: 'Phone',
  DetectionType.link: 'Link',
  DetectionType.email: 'Email',
  DetectionType.address: 'Address',
  DetectionType.date: 'Date',
};

/// The 15 language models supported by ML Kit Entity Extraction (Android).
const languages = <(ModelLanguage, String)>[
  (ModelLanguage.ar, 'Arabic'),
  (ModelLanguage.nl, 'Dutch'),
  (ModelLanguage.en, 'English'),
  (ModelLanguage.fr, 'French'),
  (ModelLanguage.de, 'German'),
  (ModelLanguage.it, 'Italian'),
  (ModelLanguage.ja, 'Japanese'),
  (ModelLanguage.ko, 'Korean'),
  (ModelLanguage.pl, 'Polish'),
  (ModelLanguage.pt, 'Portuguese'),
  (ModelLanguage.ru, 'Russian'),
  (ModelLanguage.es, 'Spanish'),
  (ModelLanguage.th, 'Thai'),
  (ModelLanguage.tr, 'Turkish'),
  (ModelLanguage.zh, 'Chinese'),
];

String languageName(ModelLanguage code) => languages
    .firstWhere((l) => l.$1 == code, orElse: () => (code, code.name))
    .$2;
