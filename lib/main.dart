import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const DanmakuApp());

class DanmakuApp extends StatelessWidget {
  const DanmakuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '星屑弾幕',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};
  late final Ticker _ticker;
  final math.Random _rng = math.Random();
  final List<_Bullet> _enemyBullets = [];
  final List<_Bullet> _playerBullets = [];
  final List<_Particle> _particles = [];

  Size _size = Size.zero;
  Offset _player = const Offset(0.5, 0.82);
  bool _started = false;
  bool _paused = false;
  bool _gameOver = false;
  int _frame = 0;
  int _score = 0;
  int _lives = 3;
  int _invulnerable = 0;
  double _enemyX = 0.5;
  double _enemyY = 0.16;
  double _enemyDir = 1;
  int _enemyHp = 100;
  int _pattern = 0;
  int _patternTimer = 0;
  int _shotCooldown = 0;
  int _spawnTimer = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    _enemyBullets.clear();
    _playerBullets.clear();
    _particles.clear();
    _player = const Offset(0.5, 0.82);
    _enemyX = 0.5;
    _enemyY = 0.16;
    _enemyDir = 1;
    _frame = 0;
    _score = 0;
    _lives = 3;
    _invulnerable = 90;
    _enemyHp = 100;
    _pattern = 0;
    _patternTimer = 0;
    _shotCooldown = 0;
    _spawnTimer = 0;
    _gameOver = false;
    _paused = false;
    _started = true;
    _focus.requestFocus();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    if (!_started || _paused || _gameOver || _size.isEmpty) {
      setState(() {});
      return;
    }
    _frame++;
    final w = _size.width;
    final h = _size.height;
    final slow = _keys.contains(LogicalKeyboardKey.shiftLeft) ||
        _keys.contains(LogicalKeyboardKey.shiftRight);
    final speed = (slow ? 2.5 : 4.8) / math.max(w, h) * 700;
    double dx = 0, dy = 0;
    if (_keys.contains(LogicalKeyboardKey.arrowLeft) ||
        _keys.contains(LogicalKeyboardKey.keyA)) dx--;
    if (_keys.contains(LogicalKeyboardKey.arrowRight) ||
        _keys.contains(LogicalKeyboardKey.keyD)) dx++;
    if (_keys.contains(LogicalKeyboardKey.arrowUp) ||
        _keys.contains(LogicalKeyboardKey.keyW)) dy--;
    if (_keys.contains(LogicalKeyboardKey.arrowDown) ||
        _keys.contains(LogicalKeyboardKey.keyS)) dy++;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len > 0) {
      _player = Offset(
        (_player.dx + dx / len * speed / w).clamp(0.035, 0.965).toDouble(),
        (_player.dy + dy / len * speed / h).clamp(0.08, 0.94).toDouble(),
      );
    }

    // Player's focused, automatic shot.
    if (_shotCooldown > 0) _shotCooldown--;
    if (_shotCooldown == 0) {
      _shotCooldown = 8;
      final px = _player.dx * w;
      final py = _player.dy * h;
      _playerBullets
          .add(_Bullet(Offset(px - 7, py - 14), const Offset(0, -10), 4, true));
      _playerBullets
          .add(_Bullet(Offset(px + 7, py - 14), const Offset(0, -10), 4, true));
    }

    // Boss drifts across the top of the screen.
    _enemyX += _enemyDir * 0.0018;
    if (_enemyX > 0.82 || _enemyX < 0.18) _enemyDir *= -1;
    _enemyY = 0.15 + math.sin(_frame / 100) * 0.025;

    _patternTimer++;
    if (_patternTimer % 105 == 0) _pattern = (_pattern + 1) % 3;
    _spawnTimer++;
    if (_spawnTimer % 13 == 0) _firePattern(w, h);

    for (final b in _playerBullets) {
      b.position += b.velocity;
      final ex = _enemyX * w;
      final ey = _enemyY * h;
      if (!b.dead && (b.position - Offset(ex, ey)).distance < 29) {
        b.dead = true;
        _enemyHp -= 1;
        _score += 10;
        if (_enemyHp <= 0) {
          _score += 1000;
          _enemyHp = 100;
          _enemyBullets.clear();
          _burst(Offset(ex, ey), const Color(0xffffc857), 34);
        }
      }
      if (b.position.dy < -20) b.dead = true;
    }

    for (final b in _enemyBullets) {
      b.position += b.velocity;
      if (!b.dead &&
          _invulnerable <= 0 &&
          (b.position - Offset(_player.dx * w, _player.dy * h)).distance <
              (slow ? 8 : 12) + b.radius) {
        b.dead = true;
        _lives--;
        _invulnerable = 100;
        _burst(Offset(_player.dx * w, _player.dy * h), const Color(0xff70e1ff),
            16);
        if (_lives <= 0) _gameOver = true;
      }
      if (b.position.dx < -40 ||
          b.position.dx > w + 40 ||
          b.position.dy < -40 ||
          b.position.dy > h + 40) b.dead = true;
    }
    _playerBullets.removeWhere((b) => b.dead);
    _enemyBullets.removeWhere((b) => b.dead);
    for (final p in _particles) {
      p.position += p.velocity;
      p.life--;
    }
    _particles.removeWhere((p) => p.life <= 0);
    if (_invulnerable > 0) _invulnerable--;
    setState(() {});
  }

  void _firePattern(double w, double h) {
    final ex = _enemyX * w;
    final ey = _enemyY * h + 20;
    if (_pattern == 0) {
      // Aimed fan.
      final target = Offset(_player.dx * w, _player.dy * h);
      final base = math.atan2(target.dy - ey, target.dx - ex);
      for (int i = -2; i <= 2; i++) {
        final a = base + i * 0.17;
        _enemyBullets.add(_Bullet(Offset(ex, ey),
            Offset(math.cos(a) * 3.0, math.sin(a) * 3.0), 5, false));
      }
    } else if (_pattern == 1) {
      // Rotating flower spiral.
      final a = _frame * 0.09;
      for (int i = 0; i < 3; i++) {
        final angle = a + i * math.pi * 2 / 3;
        _enemyBullets.add(_Bullet(
            Offset(ex, ey),
            Offset(math.cos(angle) * 2.6, math.sin(angle) * 2.6 + 0.8),
            4.5,
            false));
      }
    } else {
      // Wide curtain.
      for (int i = -4; i <= 4; i++) {
        final a = math.pi / 2 + i * 0.13 + math.sin(_frame / 25) * 0.25;
        _enemyBullets.add(_Bullet(Offset(ex, ey),
            Offset(math.cos(a) * 2.5, math.sin(a) * 2.5), 4, false));
      }
    }
  }

  void _burst(Offset at, Color color, int count) {
    for (int i = 0; i < count; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final s = 1 + _rng.nextDouble() * 3.5;
      _particles.add(_Particle(at, Offset(math.cos(a) * s, math.sin(a) * s),
          color, 24 + _rng.nextInt(18)));
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _keys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          (!_started || _gameOver)) _reset();
      if (event.logicalKey == LogicalKeyboardKey.keyP && _started && !_gameOver)
        _paused = !_paused;
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          _started &&
          !_gameOver) _paused = !_paused;
    } else if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080b1b),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_7, color: Color(0xff70e1ff)),
                      const SizedBox(width: 10),
                      const Text('星屑弾幕',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                      const Spacer(),
                      Text('SCORE  ${_score.toString().padLeft(6, '0')}',
                          style: const TextStyle(
                              color: Color(0xffffd166),
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(width: 20),
                      Text('LIFE  ${'♥ ' * _lives}',
                          style: const TextStyle(color: Color(0xffff6b9a))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _size =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: KeyboardListener(
                            focusNode: _focus,
                            onKeyEvent: (event) => _onKey(_focus, event),
                            child: GestureDetector(
                              onTap: () => _focus.requestFocus(),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                      painter: _GamePainter(
                                    player: _player,
                                    enemyX: _enemyX,
                                    enemyY: _enemyY,
                                    enemyHp: _enemyHp,
                                    enemyBullets: _enemyBullets,
                                    playerBullets: _playerBullets,
                                    particles: _particles,
                                    frame: _frame,
                                    invulnerable: _invulnerable,
                                    slow: _keys.contains(
                                            LogicalKeyboardKey.shiftLeft) ||
                                        _keys.contains(
                                            LogicalKeyboardKey.shiftRight),
                                  )),
                                  if (!_started || _gameOver || _paused)
                                    Container(
                                      color: const Color(0xcc080b1b),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 460),
                                          child: Padding(
                                            padding: const EdgeInsets.all(28),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                    _gameOver
                                                        ? 'GAME OVER'
                                                        : _paused
                                                            ? 'PAUSED'
                                                            : 'STARDUST DANMAKU',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: 30,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color:
                                                            Color(0xff70e1ff),
                                                        letterSpacing: 3)),
                                                const SizedBox(height: 14),
                                                Text(
                                                    _gameOver
                                                        ? 'SCORE  $_score'
                                                        : 'ひとり用・ボス戦弾幕シューティング',
                                                    style: const TextStyle(
                                                        color: Colors.white70),
                                                    textAlign:
                                                        TextAlign.center),
                                                const SizedBox(height: 20),
                                                if (!_paused)
                                                  FilledButton.icon(
                                                    onPressed: _reset,
                                                    icon: const Icon(
                                                        Icons.play_arrow),
                                                    label: Text(_gameOver
                                                        ? 'もう一度遊ぶ  (Enter)'
                                                        : 'ゲームスタート  (Enter)'),
                                                  )
                                                else
                                                  FilledButton.icon(
                                                    onPressed: () {
                                                      setState(() =>
                                                          _paused = false);
                                                      _focus.requestFocus();
                                                    },
                                                    icon: const Icon(
                                                        Icons.play_arrow),
                                                    label: const Text(
                                                        '再開  (P / Esc)'),
                                                  ),
                                                const SizedBox(height: 16),
                                                const Text(
                                                    '移動：WASD / 矢印キー　　低速：Shift\nショット：自動　　ポーズ：P / Esc',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        height: 1.8,
                                                        color: Colors.white60)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('敵の弾を避けながら撃ち続けよう。Shift中は低速移動＆当たり判定が見やすくなる。',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet {
  Offset position;
  final Offset velocity;
  final double radius;
  final bool player;
  bool dead = false;
  _Bullet(this.position, this.velocity, this.radius, this.player);
}

class _Particle {
  Offset position;
  final Offset velocity;
  final Color color;
  int life;
  _Particle(this.position, this.velocity, this.color, this.life);
}

class _GamePainter extends CustomPainter {
  final Offset player;
  final double enemyX, enemyY;
  final int enemyHp, frame, invulnerable;
  final List<_Bullet> enemyBullets, playerBullets;
  final List<_Particle> particles;
  final bool slow;

  _GamePainter({
    required this.player,
    required this.enemyX,
    required this.enemyY,
    required this.enemyHp,
    required this.enemyBullets,
    required this.playerBullets,
    required this.particles,
    required this.frame,
    required this.invulnerable,
    required this.slow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff101b3c), Color(0xff090d22), Color(0xff170d2b)],
          ).createShader(rect));

    // Star field.
    final starPaint = Paint()..color = Colors.white.withOpacity(0.42);
    for (int i = 0; i < 95; i++) {
      final x = ((i * 97 + 31) % 997) / 997 * size.width;
      final y = (((i * 173 + frame * (i % 3 + 1)) % 1200) / 1200) * size.height;
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.5 : 0.7, starPaint);
    }

    // Boss and health bar.
    final ex = enemyX * size.width, ey = enemyY * size.height;
    canvas.drawCircle(Offset(ex, ey), 35,
        Paint()..color = const Color(0xfffd4f9b).withOpacity(0.12));
    canvas.drawCircle(Offset(ex, ey), 26,
        Paint()..color = const Color(0xfffd4f9b).withOpacity(0.22));
    canvas.drawCircle(
        Offset(ex, ey),
        18,
        Paint()
          ..shader = const RadialGradient(
            colors: [Colors.white, Color(0xffff8ad0), Color(0xffb02c91)],
          ).createShader(Rect.fromCircle(center: Offset(ex, ey), radius: 18)));
    canvas.drawCircle(
        Offset(ex, ey),
        26,
        Paint()
          ..color = const Color(0xffff82cb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final bar = Rect.fromLTWH(size.width * .25, 14, size.width * .5, 6);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()..color = Colors.white12);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                bar.left, bar.top, bar.width * enemyHp / 100, bar.height),
            const Radius.circular(4)),
        Paint()..color = const Color(0xffff5d9e));

    // Enemy bullets.
    for (final b in enemyBullets) {
      canvas.drawCircle(b.position, b.radius + 3,
          Paint()..color = const Color(0xffff5c8a).withOpacity(0.18));
      canvas.drawCircle(
          b.position, b.radius, Paint()..color = const Color(0xffff80ad));
      canvas.drawCircle(b.position, b.radius * .42,
          Paint()..color = Colors.white.withOpacity(0.9));
    }
    // Player shots.
    for (final b in playerBullets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: b.position, width: 4, height: 15),
              const Radius.circular(3)),
          Paint()..color = const Color(0xff7bf1ff));
      canvas.drawCircle(b.position, 5,
          Paint()..color = const Color(0xff70e1ff).withOpacity(0.18));
    }

    // Player ship and hitbox.
    final p = Offset(player.dx * size.width, player.dy * size.height);
    if (invulnerable == 0 || frame % 8 < 4) {
      final path = Path()
        ..moveTo(p.dx, p.dy - 15)
        ..lineTo(p.dx + 11, p.dy + 10)
        ..lineTo(p.dx, p.dy + 5)
        ..lineTo(p.dx - 11, p.dy + 10)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xff70e1ff));
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
    }
    if (slow) {
      canvas.drawCircle(
          p,
          8,
          Paint()
            ..color = const Color(0xffffffff)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.drawCircle(
          p,
          17,
          Paint()
            ..color = const Color(0xff70e1ff).withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    for (final particle in particles) {
      canvas.drawCircle(
          particle.position,
          math.max(1, particle.life / 9),
          Paint()
            ..color = particle.color
                .withOpacity((particle.life / 42).clamp(0.0, 1.0).toDouble()));
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
