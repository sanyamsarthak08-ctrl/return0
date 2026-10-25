import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive dependency flowchart. Feed it the task maps returned by shredProject
/// (or read from Firestore). Needs: id/localId, title, depends_on, estimated_hours, skill, coins.
/// The longest chain by hours (the critical path) is drawn in the primary colour.
class DependencyGraph extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final void Function(Map<String, dynamic> task)? onTap;
  const DependencyGraph({super.key, required this.tasks, this.onTap});

  static const double nodeW = 170, nodeH = 66, gapX = 64, gapY = 28, pad = 24;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = [for (final t in tasks) (t['localId'] ?? t['id']).toString()];
    final byId = <String, Map<String, dynamic>>{for (var i = 0; i < tasks.length; i++) ids[i]: tasks[i]};

    List<String> depsOf(String id) => [
          for (final d in (byId[id]!['depends_on'] as List? ?? const [])) d.toString(),
        ].where(byId.containsKey).toList();

    // column = longest chain of dependencies before this task
    final layer = <String, int>{};
    int layerOf(String id, Set<String> seen) {
      if (layer.containsKey(id)) return layer[id]!;
      if (!seen.add(id)) return 0; // safety against cycles
      var l = 0;
      for (final d in depsOf(id)) {
        l = math.max(l, layerOf(d, seen) + 1);
      }
      seen.remove(id);
      return layer[id] = l;
    }

    // critical path = chain with the most total hours
    final finish = <String, int>{};
    final pred = <String, String?>{};
    int finishOf(String id, Set<String> seen) {
      if (finish.containsKey(id)) return finish[id]!;
      if (!seen.add(id)) return 0;
      var best = 0;
      String? bestDep;
      for (final d in depsOf(id)) {
        final v = finishOf(d, seen);
        if (bestDep == null || v > best) {
          best = v;
          bestDep = d;
        }
      }
      seen.remove(id);
      pred[id] = bestDep;
      final h = (byId[id]!['estimated_hours'] as num?)?.toInt() ?? 1;
      return finish[id] = best + h;
    }

    for (final id in ids) {
      layerOf(id, {});
      finishOf(id, {});
    }
    final critical = <String>{};
    if (ids.isNotEmpty) {
      var cur = ids.reduce((a, b) => finish[a]! >= finish[b]! ? a : b);
      String? node = cur;
      while (node != null) {
        critical.add(node);
        node = pred[node];
      }
    }

    // positions
    final rowsInLayer = <int, int>{};
    final pos = <String, Offset>{};
    for (final id in ids) {
      final l = layer[id]!;
      final r = rowsInLayer[l] = (rowsInLayer[l] ?? -1) + 1;
      pos[id] = Offset(pad + l * (nodeW + gapX), pad + r * (nodeH + gapY));
    }
    final cols = (layer.values.isEmpty ? 0 : layer.values.reduce(math.max)) + 1;
    final rows = rowsInLayer.values.isEmpty ? 1 : rowsInLayer.values.reduce(math.max) + 1;
    final width = pad * 2 + cols * nodeW + (cols - 1) * gapX;
    final height = pad * 2 + rows * nodeH + (rows - 1) * gapY;

    final edges = <_Edge>[
      for (final id in ids)
        for (final d in depsOf(id))
          _Edge(pos[d]! + const Offset(nodeW, nodeH / 2), pos[id]! + const Offset(0, nodeH / 2),
              critical.contains(id) && critical.contains(d) && pred[id] == d),
    ];

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 2,
      boundaryMargin: const EdgeInsets.all(80),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _EdgePainter(edges, cs.primary, cs.outline))),
          for (final id in ids)
            Positioned(
              left: pos[id]!.dx,
              top: pos[id]!.dy,
              width: nodeW,
              height: nodeH,
              child: _Node(task: byId[id]!, id: id, isCritical: critical.contains(id), onTap: onTap),
            ),
        ]),
      ),
    );
  }
}

class _Edge {
  final Offset from, to;
  final bool critical;
  const _Edge(this.from, this.to, this.critical);
}

class _EdgePainter extends CustomPainter {
  final List<_Edge> edges;
  final Color critical, normal;
  _EdgePainter(this.edges, this.critical, this.normal);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final p = Paint()
        ..color = e.critical ? critical : normal.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.critical ? 3 : 1.5;
      final dx = (e.to.dx - e.from.dx) / 2;
      final path = Path()
        ..moveTo(e.from.dx, e.from.dy)
        ..cubicTo(e.from.dx + dx, e.from.dy, e.to.dx - dx, e.to.dy, e.to.dx, e.to.dy);
      canvas.drawPath(path, p);
      final arrow = Path()
        ..moveTo(e.to.dx, e.to.dy)
        ..lineTo(e.to.dx - 9, e.to.dy - 5)
        ..lineTo(e.to.dx - 9, e.to.dy + 5)
        ..close();
      canvas.drawPath(arrow, Paint()..color = p.color);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => old.edges != edges;
}

class _Node extends StatelessWidget {
  final Map<String, dynamic> task;
  final String id;
  final bool isCritical;
  final void Function(Map<String, dynamic>)? onTap;
  const _Node({required this.task, required this.id, required this.isCritical, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isCritical ? cs.primary : cs.outlineVariant, width: isCritical ? 2.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null ? null : () => onTap!(task),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$id  ${task['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 2),
            Text('${task['skill'] ?? ''} · ${task['estimated_hours'] ?? '?'}h · ${task['coins'] ?? '?'} coins',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
