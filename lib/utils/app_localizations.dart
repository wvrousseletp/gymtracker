import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'title': 'Los Mooscles',
      'workout': 'Workout',
      'diet': 'Diet',
      'routines': 'Routines',
      'progress': 'Progress',
      'settings': 'Settings',
      'offline_banner': 'You are offline. Changes will be synced later.',
      'export_data': 'Export Data',
      'cancel': 'Cancel',
      'save': 'Save',
    },
    'pt': {
      'title': 'Los Mooscles',
      'workout': 'Treino',
      'diet': 'Dieta',
      'routines': 'Rotinas',
      'progress': 'Progresso',
      'settings': 'Configurações',
      'offline_banner': 'Você está offline. Alterações serão sincronizadas depois.',
      'export_data': 'Exportar Dados',
      'cancel': 'Cancelar',
      'save': 'Salvar',
    },
  };

  String translateKey(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
