import 'package:flutter/widgets.dart';
import 'package:komodo_go/core/extensions/icon_data_x.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract class AppIcons {
  const AppIcons._();

  // Navigation
  static const IconData home = LucideIcons.house;
  static const IconData resources = LucideIcons.layoutGrid;
  static const IconData containers = LucideIcons.box;
  static const IconData notifications = LucideIcons.bell;
  static const IconData notificationsActive = LucideIcons.bellRing;
  static const IconData settings = LucideIcons.settings;

  // Common
  static const IconData add = LucideIcons.plus;
  static const IconData close = LucideIcons.x;
  static const IconData moreVertical = LucideIcons.ellipsisVertical;
  static const IconData logout = LucideIcons.logOut;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData download = LucideIcons.download;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData network = LucideIcons.network;
  static const IconData wifi = LucideIcons.wifi;
  static const IconData cpu = LucideIcons.cpu;
  static const IconData activity = LucideIcons.activity;
  static const IconData memory = LucideIcons.memoryStick;
  static const IconData hardDrive = LucideIcons.hardDrive;
  static const IconData package = LucideIcons.package;
  static const IconData plug = LucideIcons.plug;
  static const IconData pause = LucideIcons.pause;
  static const IconData play = LucideIcons.play;
  static const IconData stop = LucideIcons.square;
  static const IconData user = LucideIcons.user;
  static const IconData clock = LucideIcons.clock;
  static const IconData factory = LucideIcons.factory;

  // Directional
  static IconData chevron = LucideIcons.chevronRight.dir();

  // Status / states
  static const IconData loading = LucideIcons.loader;
  static const IconData ok = LucideIcons.circleCheck;
  static const IconData warning = LucideIcons.circleAlert;
  static const IconData error = LucideIcons.octagonAlert;
  static const IconData unknown = LucideIcons.circleQuestionMark;
  static const IconData canceled = LucideIcons.circleX;
  static const IconData paused = LucideIcons.circlePause;
  static const IconData stopped = LucideIcons.circleStop;
  static const IconData pending = LucideIcons.circle;
  static const IconData waiting = LucideIcons.hourglass;

  // Forms / settings
  static const IconData server = LucideIcons.server;
  static const IconData disconnect = LucideIcons.link2Off;
  static const IconData key = LucideIcons.key;
  static const IconData lock = LucideIcons.lock;
  static const IconData tag = LucideIcons.tag;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData theme = LucideIcons.palette;
  static const IconData themeSystem = LucideIcons.sunMoon;
  static const IconData themeLight = LucideIcons.sun;
  static const IconData themeDark = LucideIcons.moon;
  static const IconData check = LucideIcons.check;
  static const IconData formError = LucideIcons.triangleAlert;

  // Resources
  static const IconData deployments = LucideIcons.rocket;
  static const IconData stacks = LucideIcons.layers;
  static const IconData repos = LucideIcons.gitBranch;
  static const IconData builds = LucideIcons.hammer;
  static const IconData procedures = LucideIcons.route;
  static const IconData actions = LucideIcons.zap;
  static const IconData syncs = LucideIcons.refreshCw;
  static const IconData maintenance = LucideIcons.wrench;
  static const IconData updateAvailable = LucideIcons.cloudDownload;
  static const IconData widgets = LucideIcons.blocks;
  static const IconData dot = LucideIcons.dot;
}
