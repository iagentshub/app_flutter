import 'package:flutter/foundation.dart';

import '../../core/storage/local_store.dart';
import '../services/native_app_icon_service.dart';

enum BrandIconVariant {
  agentCoordinator,
  coordinatorWhiteOnRed,
  coordinatorRedOnBlack,
  coordinatorBlackOnRed,
  coordinatorRedOnWhite;

  String get assetPath => switch (this) {
    BrandIconVariant.agentCoordinator =>
      'assets/icons/coordinator/agent_coordinator_icon.png',
    BrandIconVariant.coordinatorWhiteOnRed =>
      'assets/icons/coordinator/coordinator_white_on_red.png',
    BrandIconVariant.coordinatorRedOnBlack =>
      'assets/icons/coordinator/coordinator_red_on_black.png',
    BrandIconVariant.coordinatorBlackOnRed =>
      'assets/icons/coordinator/coordinator_black_on_red.png',
    BrandIconVariant.coordinatorRedOnWhite =>
      'assets/icons/coordinator/coordinator_red_on_white.png',
  };

  String? get nativeIconName =>
      this == BrandIconVariant.coordinatorWhiteOnRed ? null : name;
}

/// Preferencia local de identidad visual y sincronización con el icono nativo
/// en las plataformas compatibles.
class BrandIconController extends ChangeNotifier {
  BrandIconController._(this._selected);

  static const storageKey = 'brand_icon';
  static const defaultVariant = BrandIconVariant.coordinatorWhiteOnRed;

  static const _legacyVariants = <String, BrandIconVariant>{
    'iaInterWhiteOnRed': BrandIconVariant.coordinatorWhiteOnRed,
    'iaInterRedOnBlack': BrandIconVariant.coordinatorRedOnBlack,
    'iaInterBlackOnRed': BrandIconVariant.coordinatorBlackOnRed,
    'iaInterRedOnWhite': BrandIconVariant.coordinatorRedOnWhite,
  };

  BrandIconVariant _selected;

  BrandIconVariant get selected => _selected;
  String get assetPath => _selected.assetPath;

  static Future<BrandIconController> bootstrap() async {
    final prefs = await LocalStore.instance();
    final stored = prefs.getString(storageKey);
    final selected =
        _legacyVariants[stored] ??
        BrandIconVariant.values.firstWhere(
          (variant) => variant.name == stored,
          orElse: () => defaultVariant,
        );
    if (stored != null && stored != selected.name) {
      await prefs.setString(storageKey, selected.name);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      await NativeAppIconService.setIcon(
        selected.nativeIconName,
        selected.assetPath,
      );
    }
    return BrandIconController._(selected);
  }

  Future<void> select(BrandIconVariant variant) async {
    if (_selected == variant) return;
    await NativeAppIconService.setIcon(
      variant.nativeIconName,
      variant.assetPath,
    );
    _selected = variant;
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(storageKey, variant.name);
  }
}
