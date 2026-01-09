import 'package:flutter/material.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';
import 'package:geges_smartbarber/utils/locale_provider.dart';
import 'package:provider/provider.dart';

Widget wrapWithLocalization(Widget widget, {Locale locale = const Locale('id')}) {
  return ChangeNotifierProvider(
    create: (_) => LocaleProvider()..setLocale(locale),
    child: Builder(
      builder: (context) {
        final provider = Provider.of<LocaleProvider>(context);
        return MaterialApp(
          locale: provider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: widget,
        );
      },
    ),
  );
}