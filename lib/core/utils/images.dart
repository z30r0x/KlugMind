class Images {
  Images._();

  static const String _base = 'assets/images';

  static const String appIcon = '$_base/klugmind_logo.png';

  // Prototype's avatar placeholder (Profile screen) — TODO: replace with
  // real default-avatar asset once design hands one off.
  static const String defaultAvatar = '$_base/default_avatar.png';

  // Empty-state illustrations referenced by screen name; add as designed.
  static const String emptyCalendar = '$_base/empty_calendar.png';
  static const String emptyNotes = '$_base/empty_notes.png';
}
