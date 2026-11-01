import 'package:ticky/features/character/models/mascot_assets.dart';

/// Something Ticky can unlock with coins. The catalog lives here, in code;
/// the database only stores which keys were bought.
///
/// There is no accessory art yet, so today's items are alternate idle poses
/// cut from Ticky's own artwork. Ticky shows the equipped pose while he has
/// nothing to react to; his other moods are unchanged.
class ShopItem {
  const ShopItem({
    required this.key,
    required this.name,
    required this.pose,
    required this.price,
  });

  /// Stable id, stored in `unlocked_items` and `app_settings`.
  final String key;
  final String name;

  /// Id from [MascotAssets.poses].
  final String pose;

  /// Coins.
  final int price;

  String get asset => MascotAssets.poseAsset(pose);
}

/// In the order they appear in the shop: cheapest first.
const shopItems = <ShopItem>[
  ShopItem(key: 'pose_relax', name: 'Relaxed', pose: 'relax', price: 20),
  ShopItem(
    key: 'pose_thumbs_up',
    name: 'Thumbs up',
    pose: 'thumbs_up',
    price: 30,
  ),
  ShopItem(
    key: 'pose_walking',
    name: 'Out for a walk',
    pose: 'walking',
    price: 40,
  ),
  ShopItem(key: 'pose_cheer', name: 'Cheering', pose: 'cheer', price: 50),
  ShopItem(key: 'pose_jumping', name: 'Jumping', pose: 'jumping', price: 60),
  ShopItem(key: 'pose_running', name: 'On the run', pose: 'running', price: 80),
];

/// The catalog entry for [key], or null for none or an unknown key.
ShopItem? shopItemFor(String? key) {
  for (final item in shopItems) {
    if (item.key == key) return item;
  }
  return null;
}
