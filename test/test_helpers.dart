import 'package:flutter/material.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

Widget wrapWithLocalization(Widget widget, {Locale locale = const Locale('id')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: widget,
  );
}
