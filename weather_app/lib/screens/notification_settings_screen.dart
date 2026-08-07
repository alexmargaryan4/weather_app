import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_localizations.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../services/weather_watcher_task.dart';
import '../widgets/glass_panel.dart';

/// Экран настроек уведомлений: ежедневная утренняя сводка (со временем
/// отправки) и алерты о резких изменениях погоды (дождь/скачок температуры).
///
/// Оба переключателя пишут в [NotificationSettingsService] и сразу же
/// (пере)регистрируют/снимают фоновую задачу [WeatherWatcherTask] и
/// системное расписание в [NotificationService], поэтому отдельной кнопки
/// "Сохранить" здесь нет — поведение включается/выключается сразу же по
/// тапу на переключатель, как это принято в системных настройках
/// уведомлений на iOS/Android.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationSettingsService _settings = NotificationSettingsService();

  bool _loading = true;
  bool _dailyEnabled = false;
  bool _severeEnabled = false;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 8, minute: 0);

  // null = ещё не проверяли; true/false = результат последней проверки.
  // Используется, чтобы показать предупреждение "уведомления отключены в
  // системных настройках", если пользователь включил переключатель здесь,
  // но реального системного разрешения нет (например, отозвал его вручную
  // в настройках телефона после первой установки).
  bool? _systemPermissionGranted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dailyEnabled = await _settings.getDailySummaryEnabled();
    final severeEnabled = await _settings.getSevereAlertsEnabled();
    final dailyTime = await _settings.getDailySummaryTime();
    final granted = await NotificationService.instance.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _dailyEnabled = dailyEnabled;
      _severeEnabled = severeEnabled;
      _dailyTime = dailyTime;
      _systemPermissionGranted = granted;
      _loading = false;
    });
  }

  Future<bool> _ensurePermission() async {
    final granted = await NotificationService.instance.areNotificationsEnabled();
    if (granted) return true;
    final requested = await NotificationService.instance.requestPermission();
    if (!mounted) return requested;
    setState(() => _systemPermissionGranted = requested);
    return requested;
  }

  Future<void> _toggleDaily(bool value) async {
    HapticFeedback.selectionClick();
    if (value) {
      final granted = await _ensurePermission();
      if (!granted) {
        setState(() => _systemPermissionGranted = false);
        return;
      }
    }
    setState(() => _dailyEnabled = value);
    await _settings.setDailySummaryEnabled(value);
    if (value) {
      await WeatherWatcherTask.rescheduleDailySummary();
    } else {
      await NotificationService.instance.cancelDailySummary();
    }
  }

  Future<void> _toggleSevere(bool value) async {
    HapticFeedback.selectionClick();
    if (value) {
      final granted = await _ensurePermission();
      if (!granted) {
        setState(() => _systemPermissionGranted = false);
        return;
      }
    }
    setState(() => _severeEnabled = value);
    await _settings.setSevereAlertsEnabled(value);
    await WeatherWatcherTask.updateRegistration();
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              surface: Color(0xFF1B2A55),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _dailyTime = picked);
    await _settings.setDailySummaryTime(picked);
    if (_dailyEnabled) {
      await WeatherWatcherTask.rescheduleDailySummary();
    }
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final statusBarHeight = MediaQuery.of(context).padding.top;
    final topInset = statusBarHeight + GlassStatusBar.toolbarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      extendBodyBehindAppBar: true,
      appBar: GlassStatusBar(
        title: l10n.notifications,
        leading: _GlassBackButton(onTap: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 32),
              children: [
                if (_systemPermissionGranted == false)
                  _PermissionWarningBanner(
                    text: l10n.notificationsPermissionDenied,
                    actionText: l10n.notificationsOpenSettings,
                    onTap: () async {
                      final granted =
                          await NotificationService.instance.requestPermission();
                      if (!mounted) return;
                      setState(() => _systemPermissionGranted = granted);
                    },
                  ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SwitchRow(
                      title: l10n.notificationsDailySummary,
                      subtitle: l10n.notificationsDailySummarySubtitle,
                      value: _dailyEnabled,
                      onChanged: _toggleDaily,
                    ),
                    if (_dailyEnabled) ...[
                      const _Divider(),
                      _NavigationRow(
                        title: l10n.notificationsDailySummaryTime,
                        value: _formatTime(_dailyTime),
                        onTap: _pickTime,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsGroup(
                  children: [
                    _SwitchRow(
                      title: l10n.notificationsSevereAlerts,
                      subtitle: l10n.notificationsSevereAlertsSubtitle,
                      value: _severeEnabled,
                      onChanged: _toggleSevere,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Круглая стеклянная кнопка "назад" в шапке — тот же стиль, что и кнопки
/// действий на главном экране (полупрозрачная заливка, без отдельного
/// блюра — блюр уже даёт GlassStatusBar под ней).
class _GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white70, size: 18),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 0.6, color: Colors.white.withOpacity(0.1)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.greenAccent.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PermissionWarningBanner extends StatelessWidget {
  final String text;
  final String actionText;
  final VoidCallback onTap;

  const _PermissionWarningBanner({
    required this.text,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined,
              color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
