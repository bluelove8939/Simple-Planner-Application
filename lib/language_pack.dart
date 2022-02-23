import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class Translations {
  final Locale locale;
  Map<String, String> _sentences = {};

  Translations(this.locale);

  static Translations of(BuildContext context) {
    return Localizations.of<Translations>(context, Translations)!;
  }

  Future<bool> load() async {
    String data = await rootBundle.loadString('assets/locale/${locale.languageCode}.json'); // 경로 유의
    Map<String, dynamic> _result = json.decode(data);

    _sentences = {};
    _result.forEach((String key, dynamic value) {
      _sentences[key] = value.toString();
    });

    return true;
  }

  String trans(String key) {
    return _sentences[key]!;
  }
}


class TranslationsDelegate extends LocalizationsDelegate<Translations> {
  const TranslationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ko', 'en'].contains(locale.languageCode);

  @override
  Future<Translations> load(Locale locale) async {
    Translations localizations = Translations(locale);
    await localizations.load();

    print("Load ${locale.languageCode}");

    return localizations;
  }

  @override
  bool shouldReload(TranslationsDelegate old) => false;
}