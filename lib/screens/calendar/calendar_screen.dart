import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

const _kGreen = Color(0xFF4CAF82);
const _kSurface = Color(0xFF1E1E1E);

enum EventType { feeding, spawning, hatching }

class CalendarEvent {
  final String title;
  final String subtitle;
  final EventType type;
  final Color color;

  const CalendarEvent({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.color,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<CalendarEvent>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<CalendarEvent> _getEvents(DateTime day) =>
      _events[_normalize(day)] ?? [];

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final results = await Future.wait([
        // 활성/홀드백 개체 (급여 주기 포함)
        client
            .from('reptiles')
            .select('id, name, feeding_interval_days')
            .eq('user_id', userId)
            .or('status.eq.active,status.eq.holdback'),
        // 최근 급여 기록 (개체별 최신 fed_at 산출용)
        client
            .from('feeding_logs')
            .select('reptile_id, fed_at')
            .order('fed_at', ascending: false)
            .limit(500),
        // 성공한 메이팅 기록 (암컷 이름 포함, 최신순)
        client
            .from('breeding_logs')
            .select('female_id, paired_at, female:reptiles!female_id(name)')
            .eq('success', true)
            .order('paired_at', ascending: false),
        // 산란 기록 (해칭 예정일 + 암컷 이름)
        client
            .from('egg_clutches')
            .select('female_id, expected_hatch_date, female:reptiles!female_id(name)'),
      ]);

      final reptiles = results[0] as List;
      final feedingLogs = results[1] as List;
      final breedingLogs = results[2] as List;
      final clutches = results[3] as List;

      final newEvents = <DateTime, List<CalendarEvent>>{};
      void add(DateTime date, CalendarEvent e) {
        final key = DateTime(date.year, date.month, date.day);
        newEvents.putIfAbsent(key, () => []).add(e);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // ── 급여 예정 ───────────────────────────────────────────────────────
      final latestFed = <String, DateTime>{};
      for (final l in feedingLogs) {
        final m = l as Map<String, dynamic>;
        final rid = m['reptile_id'] as String;
        final fedAt = DateTime.parse(m['fed_at'] as String).toLocal();
        if (!latestFed.containsKey(rid) || fedAt.isAfter(latestFed[rid]!)) {
          latestFed[rid] = fedAt;
        }
      }

      for (final r in reptiles) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String;
        final name = m['name'] as String;
        final interval = (m['feeding_interval_days'] as int?) ?? 7;
        final lastFed = latestFed[id];
        final rawNext = lastFed != null
            ? lastFed.add(Duration(days: interval))
            : today;
        final nextDay = DateTime(rawNext.year, rawNext.month, rawNext.day);
        add(
          nextDay,
          CalendarEvent(
            title: name,
            subtitle: '급여 예정 ($interval일 주기)',
            type: EventType.feeding,
            color: _kGreen,
          ),
        );
      }

      // ── 산란 예정 (메이팅 성공 + 클러치 없음 → 교배일+30일 추정) ────────
      final clutchFemaleIds = clutches
          .map((e) => (e as Map<String, dynamic>)['female_id'] as String)
          .toSet();

      // 암컷별 최신 교배 기록 (이미 내림차순 정렬됨)
      final latestPaired = <String, Map<String, dynamic>>{};
      for (final b in breedingLogs) {
        final m = b as Map<String, dynamic>;
        final fid = m['female_id'] as String?;
        if (fid == null || latestPaired.containsKey(fid)) continue;
        latestPaired[fid] = m;
      }

      for (final entry in latestPaired.entries) {
        if (clutchFemaleIds.contains(entry.key)) continue;
        final m = entry.value;
        final femaleName =
            (m['female'] as Map<String, dynamic>?)?['name'] as String? ?? '암컷';
        final pairedAt = DateTime.parse(m['paired_at'] as String).toLocal();
        final estimated = pairedAt.add(const Duration(days: 30));
        add(
          estimated,
          CalendarEvent(
            title: femaleName,
            subtitle: '산란 예정 (교배일+30일 추정)',
            type: EventType.spawning,
            color: const Color(0xFFFFA726),
          ),
        );
      }

      // ── 해칭 예정 ────────────────────────────────────────────────────────
      for (final c in clutches) {
        final m = c as Map<String, dynamic>;
        final raw = m['expected_hatch_date'] as String?;
        if (raw == null) continue;
        final hatchDate = DateTime.parse(raw);
        final femaleName =
            (m['female'] as Map<String, dynamic>?)?['name'] as String? ?? '암컷';
        add(
          hatchDate,
          CalendarEvent(
            title: femaleName,
            subtitle: '해칭 예정',
            type: EventType.hatching,
            color: const Color(0xFFEF5350),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEvents(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text('캘린더', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selectedDay = DateTime.now();
              _focusedDay = DateTime.now();
            }),
            child: const Text('오늘',
                style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(
              _calendarFormat == CalendarFormat.month
                  ? Icons.view_week_outlined
                  : Icons.calendar_view_month_outlined,
              color: Colors.white,
            ),
            tooltip: _calendarFormat == CalendarFormat.month ? '주간 뷰' : '월간 뷰',
            onPressed: () => setState(() {
              _calendarFormat = _calendarFormat == CalendarFormat.month
                  ? CalendarFormat.week
                  : CalendarFormat.month;
            }),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : Column(
              children: [
                // ── 캘린더 ─────────────────────────────────────────────────
                Container(
                  color: _kSurface,
                  child: TableCalendar<CalendarEvent>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    eventLoader: _getEvents,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) =>
                        setState(() => _calendarFormat = format),
                    onPageChanged: (focusedDay) =>
                        _focusedDay = focusedDay,
                    availableCalendarFormats: const {
                      CalendarFormat.month: '월간',
                      CalendarFormat.week: '주간',
                    },
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      leftChevronIcon:
                          Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon:
                          Icon(Icons.chevron_right, color: Colors.white),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle:
                          TextStyle(color: Color(0xFF888888), fontSize: 12),
                      weekendStyle:
                          TextStyle(color: Color(0xFF888888), fontSize: 12),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle:
                          const TextStyle(color: Colors.white),
                      weekendTextStyle:
                          const TextStyle(color: Colors.white),
                      outsideTextStyle:
                          const TextStyle(color: Color(0xFF444444)),
                      todayDecoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      selectedDecoration: const BoxDecoration(
                        color: _kGreen,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      markerSize: 5,
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (ctx, day, events) {
                        if (events.isEmpty) return const SizedBox.shrink();
                        final colors = events
                            .map((e) => e.color)
                            .toSet()
                            .take(3)
                            .toList();
                        return Positioned(
                          bottom: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: colors
                                .map((c) => Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    ))
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── 이벤트 목록 ─────────────────────────────────────────────
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                Expanded(
                  child: selectedEvents.isEmpty
                      ? const Center(
                          child: Text(
                            '일정이 없어요',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: selectedEvents.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _EventCard(event: selectedEvents[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  const _EventCard({required this.event});

  IconData get _icon => switch (event.type) {
        EventType.feeding => Icons.restaurant_outlined,
        EventType.spawning => Icons.egg_outlined,
        EventType.hatching => Icons.water_drop_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12)),
              ),
            ),
            const SizedBox(width: 14),
            Icon(_icon, color: event.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.subtitle,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
