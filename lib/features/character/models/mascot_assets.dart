import 'package:ticky/features/character/models/mascot_mood.dart';

/// The only place that knows which image shows which mood.
///
/// Every image is a transparent PNG cut from the concept sheet at roughly
/// 150px tall. They are sharp at the sizes used on Home (about 130dp) but will
/// look soft if enlarged much further; swap in higher-resolution art here
/// without touching any widget.
abstract final class MascotAssets {
  static const _expressions = 'assets/ticky_asset_pack/character/expressions';
  static const _actions = 'assets/ticky_asset_pack/character/actions';

  /// Alternate idle poses, by id. These are the poses the item shop unlocks;
  /// each id is the file name in the actions folder.
  static const poses = <String>{
    'relax',
    'thumbs_up',
    'walking',
    'cheer',
    'jumping',
    'running',
  };

  /// Image for [mood]. While idle, [idlePose] (an id from [poses]) replaces
  /// the plain idle picture; an unknown id falls back to it.
  static String pathFor(MascotMood mood, {String? idlePose}) {
    if (mood == MascotMood.idle && poses.contains(idlePose)) {
      return poseAsset(idlePose!);
    }
    return switch (mood) {
      MascotMood.idle => '$_actions/idle.png',
      MascotMood.happy => '$_expressions/happy.png',
      MascotMood.excited => '$_expressions/excited.png',
      MascotMood.thinking => '$_expressions/thinking.png',
      MascotMood.sleepy => '$_expressions/sleepy.png',
      MascotMood.surprised => '$_expressions/surprised.png',
      MascotMood.celebrating => '$_actions/celebrate.png',
      MascotMood.reminding => '$_actions/point.png',
      MascotMood.overdue => '$_expressions/sad.png',
    };
  }

  /// Image for the pose [id]. Also used to preview a pose in the shop.
  static String poseAsset(String id) => '$_actions/$id.png';

  /// The plain idle picture, shown in the shop for the free default.
  static const classicIdle = '$_actions/idle.png';
}
