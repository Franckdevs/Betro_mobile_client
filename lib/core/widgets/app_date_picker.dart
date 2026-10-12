import 'package:flutter/material.dart';

/// Calendrier de l'application, présenté en feuille du bas.
///
/// Remplace `showDatePicker` partout : un appui sur un jour le sélectionne
/// et ferme la feuille. Les jours hors de [firstDate]–[lastDate] sont grisés.
/// Renvoie la date choisie (à minuit) ou `null` si la feuille est fermée.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AppCalendar(
      initialDate: _jour(initialDate),
      firstDate: _jour(firstDate),
      lastDate: _jour(lastDate),
    ),
  );
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

class _AppCalendar extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _AppCalendar({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_AppCalendar> createState() => _AppCalendarState();
}

class _AppCalendarState extends State<_AppCalendar> {
  static const _ink = Color(0xFF1C1A17);
  static const _amber = Color(0xFFFFC107);
  static const _sand = Color(0xFFF4F2EE);
  static const _muted = Color(0xFF8F897F);
  static const _disabled = Color(0xFFCFCAC2);

  static const _mois = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _jours = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late DateTime _mois1er;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    _mois1er = DateTime(d.year, d.month);
  }

  bool get _peutReculer => _mois1er
      .isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
  bool get _peutAvancer => _mois1er
      .isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _changerMois(int delta) => setState(
      () => _mois1er = DateTime(_mois1er.year, _mois1er.month + delta));

  @override
  Widget build(BuildContext context) {
    final aujourdhui = _jour(DateTime.now());
    final nbJours = DateTime(_mois1er.year, _mois1er.month + 1, 0).day;
    // Semaine commençant le lundi : nombre de cases vides avant le 1er.
    final decalage = _mois1er.weekday - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE0DCD4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Mois + navigation ──────────────────────────────────
            Row(children: [
              Expanded(
                child: Text(
                  '${_mois[_mois1er.month - 1]} ${_mois1er.year}',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              _navButton(Icons.chevron_left_rounded, _peutReculer,
                  () => _changerMois(-1)),
              const SizedBox(width: 6),
              _navButton(Icons.chevron_right_rounded, _peutAvancer,
                  () => _changerMois(1)),
            ]),
            const SizedBox(height: 18),
            // ── Jours de la semaine ────────────────────────────────
            Row(
              children: _jours
                  .map((j) => Expanded(
                        child: Center(
                          child: Text(j,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _muted)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // ── Grille ─────────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: decalage + nbJours,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (_, i) {
                if (i < decalage) return const SizedBox.shrink();
                final date =
                    DateTime(_mois1er.year, _mois1er.month, i - decalage + 1);
                final actif = !date.isBefore(widget.firstDate) &&
                    !date.isAfter(widget.lastDate);
                final choisi = date == widget.initialDate;
                final estAujourdhui = date == aujourdhui;

                return GestureDetector(
                  onTap: actif ? () => Navigator.pop(context, date) : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: choisi ? _ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: estAujourdhui && !choisi
                          ? Border.all(color: _amber, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            choisi ? FontWeight.w800 : FontWeight.w600,
                        color: choisi
                            ? _amber
                            : actif
                                ? _ink
                                : _disabled,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled ? _sand : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: enabled ? _ink : _disabled, size: 22),
        ),
      ),
    );
  }
}
