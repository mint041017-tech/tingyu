import re
from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

s, n = re.subn(
    r'( *)label: nav\[i\],',
    lambda m: f"{m.group(1)}excludeSemantics: true,\n"
    f"{m.group(1)}label: i == 1 && pomo.running\n"
    f"{m.group(1)}    ? '专注 ${{pomo.clock}}'\n"
    f"{m.group(1)}    : nav[i],",
    s,
)
print('nav labels patched', n)

s, n = re.subn(
    r'( *)label: PomoPhase\.values\[i\]\.label,',
    lambda m: f"{m.group(1)}excludeSemantics: true,\n{m.group(1)}label: PomoPhase.values[i].label,",
    s,
)
print('phase labels patched', n)

old = """                    .map(
                      (item) => OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: c.theme == item.$1
                              ? p.soft
                              : p.surface,
                          side: BorderSide(
                            color: c.theme == item.$1 ? p.accent : p.border,
                          ),
                        ),
                        onPressed: () => c.setTheme(item.$1),
                        icon: Icon(item.$3, size: 18),
                        label: Text(
                          item.$2,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),"""
new = """                    .map((item) {
                      final selected = c.theme == item.$1;
                      return Tactile(
                        pressedScale: .95,
                        hoverScale: 1.015,
                        child: AnimatedContainer(
                          duration: NookMotion.base,
                          curve: NookMotion.enterCurve,
                          decoration: BoxDecoration(
                            color: selected
                                ? p.accent.withValues(alpha: .12)
                                : p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? p.accent : p.border,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => c.setTheme(item.$1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.$3,
                                      size: 18,
                                      color: selected ? p.accent : p.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: selected ? p.accent : p.text,
                                      ),
                                    ),
                                    if (selected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: p.accent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),"""
assert old in s, 'theme block not found'
s = s.replace(old, new)

old = """        final timerCard = _pomoTimerCard(context);
        final side = Column(
          children: [_pomoSettingsCard(context), _pomoStatsCard(context)],
        );"""
new = """        final timerCard = _pomoTimerCard(context);
        final settingsCard = _pomoSettingsCard(context);
        final statsCard = _pomoStatsCard(context);"""
assert old in s, 'pomo layout top not found'
s = s.replace(old, new)

old = """                if (box.maxWidth >= 820) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: timerCard),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: side),
                    ],
                  );
                }
                return Column(
                  children: [
                    timerCard,
                    const SizedBox(height: 18),
                    side,
                  ],
                );"""
new = """                if (box.maxWidth >= 820) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            timerCard,
                            const SizedBox(height: 2),
                            statsCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: settingsCard),
                    ],
                  );
                }
                return Column(
                  children: [
                    timerCard,
                    const SizedBox(height: 18),
                    settingsCard,
                    statsCard,
                  ],
                );"""
assert old in s, 'pomo layout body not found'
s = s.replace(old, new)

s = s.replace(
    ".min(292.0, math.max(206.0, box.maxWidth - 16))",
    ".min(330.0, math.max(206.0, box.maxWidth - 16))",
)
p.write_text(s, encoding='utf-8')
print('patched')
