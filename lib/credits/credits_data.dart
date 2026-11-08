import 'dart:convert';

import 'package:flutter/services.dart';

/// `assets/credits.json`, written by `tool/credits/build_credits.py` from the
/// lock files, the package graph, the venvs and the provenance records. Every
/// item says how far it is from the game: 0 the base it's built on, 1 used
/// directly, 2 used by something we use, and so on.
///
/// `openspec/changes/add-credits-roll/specs/credits-roll/spec.md`.
class CreditsData {
  const CreditsData({
    required this.lead,
    required this.name,
    required this.items,
    this.music,
  });

  static const asset = 'assets/credits.json';

  /// "Built using" and "Tillandsias.org".
  final String lead;
  final String name;
  final List<CreditItem> items;
  final CreditsMusic? music;

  static Future<CreditsData> load([AssetBundle? bundle]) async =>
      CreditsData.fromJson(
        jsonDecode(await (bundle ?? rootBundle).loadString(asset))
            as Map<String, dynamic>,
      );

  factory CreditsData.fromJson(Map<String, dynamic> json) {
    final header = (json['header'] as Map?)?.cast<String, dynamic>() ?? {};
    final music = (json['music'] as Map?)?.cast<String, dynamic>();
    return CreditsData(
      lead: header['lead'] as String? ?? 'Built using',
      name: header['name'] as String? ?? 'Tillandsias.org',
      items: [
        for (final raw in json['items'] as List? ?? const [])
          CreditItem.fromJson((raw as Map).cast<String, dynamic>()),
      ],
      music: music == null || music['opus'] == null
          ? null
          : CreditsMusic(
              opus: music['opus'] as String,
              aac: music['aac'] as String? ?? music['opus'] as String,
              standIn: music['status'] == 'stand-in',
            ),
    );
  }

  /// Items at [degree]; with [orDeeper], that degree and every one past it.
  List<CreditItem> at(int degree, {bool orDeeper = false}) => [
    for (final item in items)
      if (orDeeper ? item.degree >= degree : item.degree == degree) item,
  ];
}

class CreditItem {
  const CreditItem({
    required this.name,
    required this.kind,
    required this.degree,
    this.version,
    this.role,
    this.via,
    this.build = false,
  });

  factory CreditItem.fromJson(Map<String, dynamic> json) => CreditItem(
    name: json['name'] as String,
    kind: json['kind'] as String? ?? 'tool',
    degree: (json['degree'] as num?)?.toInt() ?? 1,
    version: json['version'] as String?,
    role: json['role'] as String?,
    via: json['via'] as String?,
    build: json['build'] == true,
  );

  final String name;

  /// platform, tool, model, font, dart, rust, python or node.
  final String kind;
  final int degree;
  final String? version;
  final String? role;
  final String? via;

  /// Used to build the game, not shipped in it.
  final bool build;

  String get label => version == null ? name : '$name $version';
}

/// What plays under the roll. [standIn] until credits music is made.
class CreditsMusic {
  const CreditsMusic({required this.opus, required this.aac, this.standIn = false});
  final String opus;
  final String aac;
  final bool standIn;
}
