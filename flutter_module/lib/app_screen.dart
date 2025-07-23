import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _waveController;
  late AnimationController _floatingController;
  late AnimationController _particleController;
  late AnimationController _explosionController;
  ui.FragmentShader? _waterShader;
  ui.FragmentShader? _flameShader;
  ui.FragmentShader? _skyShader;
  final List<Particle> _particles = [];
  final List<Explosion> _explosions = [];
  int _animationLevel = 0; // Start with minimum level (calm mode)
  final List<String> cities = [
    'Tokyo',
    'New York',
    'London',
    'Paris',
    'Singapore',
    'Dubai',
    'Rome',
    'Barcelona',
    'Sydney',
    'Hong Kong',
    'Berlin',
    'Moscow',
    'Toronto',
    'Amsterdam',
    'Seoul',
    'Mumbai',
    'Bangkok',
    'Istanbul',
    'Rio de Janeiro',
    'Vienna',
    'Prague',
    'Cape Town',
    'Stockholm',
    'Buenos Aires',
    'Madrid',
    'Venice',
    'San Francisco',
    'Vancouver',
    'Copenhagen',
    'Dublin',
    'Davao'
  ];

  List<String> generateRandomCities() {
    List<String> randomCities = [];
    for (int i = 0; i < 1000; i++) {
      randomCities.add('${cities[i % cities.length]} #${i + 1}');
    }
    return randomCities;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _loadWaterShader();
    _loadFlameShader();
    _loadSkyShader();
    _initializeParticles();
  }

  Future<void> _loadWaterShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/water.glsl');
      setState(() {
        _waterShader = program.fragmentShader();
      });
    } catch (e) {
      debugPrint('Failed to load water shader: $e');
    }
  }

  Future<void> _loadFlameShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/flame.glsl');
      setState(() {
        _flameShader = program.fragmentShader();
      });
    } catch (e) {
      debugPrint('Failed to load flame shader: $e');
    }
  }

  Future<void> _loadSkyShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/sky.glsl');
      setState(() {
        _skyShader = program.fragmentShader();
      });
    } catch (e) {
      debugPrint('Failed to load sky shader: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _waveController.dispose();
    _floatingController.dispose();
    _particleController.dispose();
    _explosionController.dispose();
    super.dispose();
  }

  void _initializeParticles() {
    // Create 200 particles for extreme performance test
    for (int i = 0; i < 200; i++) {
      _particles.add(Particle(
        x: math.Random().nextDouble() * 400,
        y: math.Random().nextDouble() * 800,
        dx: (math.Random().nextDouble() - 0.5) * 4,
        dy: (math.Random().nextDouble() - 0.5) * 4,
        color: Color.fromRGBO(
          math.Random().nextInt(255),
          math.Random().nextInt(255),
          math.Random().nextInt(255),
          1.0,
        ),
        size: math.Random().nextDouble() * 6 + 2,
        life: 1.0,
      ));
    }
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.update();
    }
    _particles.removeWhere((particle) => particle.life <= 0);

    // Add new particles to maintain count
    while (_particles.length < 200) {
      _particles.add(Particle(
        x: math.Random().nextDouble() * 400,
        y: 800 + math.Random().nextDouble() * 100,
        dx: (math.Random().nextDouble() - 0.5) * 4,
        dy: -math.Random().nextDouble() * 3 - 1,
        color: Color.fromRGBO(
          math.Random().nextInt(255),
          math.Random().nextInt(255),
          math.Random().nextInt(255),
          1.0,
        ),
        size: math.Random().nextDouble() * 6 + 2,
        life: 1.0,
      ));
    }
  }

  void _triggerExplosion(double x, double y) {
    _explosions.add(Explosion(
      x: x,
      y: y,
      maxRadius: 100 + math.Random().nextDouble() * 50,
      color: Color.fromRGBO(
        200 + math.Random().nextInt(55),
        100 + math.Random().nextInt(155),
        math.Random().nextInt(100),
        1.0,
      ),
    ));
    _explosionController.reset();
    _explosionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final randomCities = generateRandomCities();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAnimationLevelTitle()),
        elevation: 2,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _animationLevel,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                dropdownColor: Theme.of(context).primaryColor,
                style: const TextStyle(color: Colors.white),
                items: List.generate(6, (index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      _getDropdownItemText(index),
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _animationLevel = newValue;
                    });
                    HapticFeedback.mediumImpact();
                  }
                },
              ),
            ),
          ),
        ],
        flexibleSpace: _animationLevel > 0
            ? AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  final intensity = _animationLevel / 5.0;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.withOpacity(0.8 * intensity),
                          Colors.teal.withOpacity(0.6 * intensity),
                        ],
                        stops: [
                          (math.sin(_waveController.value * 2 * math.pi) * 0.1 +
                                  0.4)
                              .clamp(0.0, 0.8),
                          (math.cos(_waveController.value * 2 * math.pi) * 0.1 +
                                  0.6)
                              .clamp(0.2, 1.0),
                        ],
                      ),
                    ),
                  );
                },
              )
            : null,
      ),
      body: _buildBodyWithAnimationLevel(randomCities),
    );
  }

  String _getAnimationLevelTitle() {
    switch (_animationLevel) {
      case 0:
        return 'Plain ListView 📋';
      case 1:
        return 'Basic Animation 🌟';
      case 2:
        return 'Enhanced Effects ✨';
      case 3:
        return 'Advanced Animation 🎭';
      case 4:
        return 'High Performance 🚀';
      case 5:
        return 'Crazy Performance Mode 🔥';
      default:
        return 'Animation Level $_animationLevel';
    }
  }

  String _getDropdownItemText(int level) {
    switch (level) {
      case 0:
        return 'Level 0 - Plain';
      case 1:
        return 'Level 1 - Basic';
      case 2:
        return 'Level 2 - Enhanced';
      case 3:
        return 'Level 3 - Advanced';
      case 4:
        return 'Level 4 - High Perf';
      case 5:
        return 'Level 5 - Crazy';
      default:
        return 'Level $level';
    }
  }

  Widget _buildBodyWithAnimationLevel(List<String> randomCities) {
    if (_animationLevel == 0) {
      return _buildPlainMode(randomCities);
    } else {
      return _buildAnimatedMode(randomCities);
    }
  }

  Widget _buildPlainMode(List<String> randomCities) {
    return Container(
      color: Colors.grey[50],
      child: ListView.builder(
        itemCount: randomCities.length,
        itemExtent: 60.0,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: Colors.grey[400],
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Text(
                randomCities[index],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
              onTap: () => _showCityDetails(randomCities[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedMode(List<String> randomCities) {
    final intensity =
        _animationLevel / 5.0; // Calculate intensity based on level

    return Stack(
      children: [
        // Split screen background: Sky on top half, Water on bottom half
        Positioned.fill(
          child: Row(
            children: [
              // Left half - Sky shader
              Expanded(
                child: _skyShader != null
                    ? AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: SkyShaderPainter(
                              shader: _skyShader!,
                              time: _animationController.value,
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF87CEEB), // Sky blue
                              Color(0xFFB0E0E6), // Powder blue
                            ],
                          ),
                        ),
                      ),
              ),
              // Right half - Water shader
              Expanded(
                child: _waterShader != null
                    ? AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: WaterShaderPainter(
                              shader: _waterShader!,
                              time: _animationController.value,
                              index: 0,
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF4682B4), // Steel blue
                              Color(0xFF191970), // Midnight blue
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Background effects only for levels 3 and above (flame overlay)
        if (_animationLevel >= 3 && _flameShader != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: (intensity * 0.3)
                      .clamp(0.0, 1.0), // Reduced opacity to see sky/water
                  child: CustomPaint(
                    painter: FlameShaderPainter(
                      shader: _flameShader!,
                      time: _animationController.value,
                    ),
                  ),
                );
              },
            ),
          ),

        // Particle system for levels 4 and above
        if (_animationLevel >= 4)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                _updateParticles();
                return Opacity(
                  opacity: (intensity * 0.6).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: ParticleSystemPainter(particles: _particles),
                  ),
                );
              },
            ),
          ),

        // Explosion effects for level 5
        if (_animationLevel >= 5)
          ...(_explosions.map((explosion) => Positioned.fill(
                child: AnimatedBuilder(
                  animation: _explosionController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ExplosionPainter(
                        explosion: explosion,
                        progress: _explosionController.value,
                      ),
                    );
                  },
                ),
              ))),

        // Matrix rain effect for level 5
        if (_animationLevel >= 5)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.3,
                  child: CustomPaint(
                    painter:
                        MatrixRainPainter(time: _animationController.value),
                  ),
                );
              },
            ),
          ),

        // ListView with varying animation intensity
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              decoration: _animationLevel >= 2
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(
                              0.05 * intensity), // Reduced to see background
                        ],
                      ),
                    )
                  : null,
              child: ListView.builder(
                itemCount: randomCities.length,
                itemExtent: 60.0 +
                    (_animationLevel * 12.0), // Increase height with level
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildAnimatedListItem(
                      context, index, randomCities[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedListItem(
      BuildContext context, int index, String cityName) {
    final intensity = _animationLevel / 5.0;
    final delay = (index % 10) * 0.1;
    final animationValue = (_animationController.value + delay) % 1.0;
    final floatingValue = (_floatingController.value + delay * 0.5) % 1.0;

    // Base container for all levels
    Widget itemWidget = Container(
      margin: EdgeInsets.symmetric(
          horizontal: 12 + (_animationLevel * 2.0),
          vertical: 2 + (_animationLevel * 1.0)),
      child: _buildCardForLevel(index, cityName, animationValue, intensity),
    );

    // Add transforms based on animation level
    if (_animationLevel >= 2) {
      itemWidget = AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              math.sin(floatingValue * 2 * math.pi) * (2.0 * intensity) +
                  math.cos(animationValue * 4 * math.pi) * (1.0 * intensity),
              math.cos(floatingValue * 2 * math.pi) * (1.5 * intensity) +
                  math.sin(animationValue * 3 * math.pi) * (0.5 * intensity),
            ),
            child: child,
          );
        },
        child: itemWidget,
      );
    }

    if (_animationLevel >= 3) {
      itemWidget = Transform.rotate(
        angle: math.sin(animationValue * math.pi) * (0.05 * intensity),
        child: itemWidget,
      );
    }

    if (_animationLevel >= 1) {
      itemWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 800 + (index % 7) * 100),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.7 +
                (value.clamp(0.0, 1.0) * 0.3) +
                math.sin(animationValue * 4 * math.pi) * (0.03 * intensity),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: itemWidget,
      );
    }

    return itemWidget;
  }

  Widget _buildCardForLevel(
      int index, String cityName, double animationValue, double intensity) {
    if (_animationLevel == 0) {
      // This shouldn't be called for level 0, but just in case
      return _buildSimpleCard(index, cityName);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 + (_animationLevel * 3.0)),
        boxShadow: _animationLevel >= 2
            ? [
                BoxShadow(
                  color: _getGradientColor(index, 0.3 * intensity),
                  blurRadius: 5 + (_animationLevel * 3.0),
                  offset: Offset(0, 2 + (_animationLevel * 1.0)),
                  spreadRadius: 1,
                ),
                if (_animationLevel >= 4)
                  BoxShadow(
                    color: _getGradientColor(index + 1, 0.2 * intensity),
                    blurRadius: 15 + math.sin(animationValue * 2 * math.pi) * 8,
                    offset: Offset(
                      math.cos(animationValue * 2 * math.pi) * 4,
                      4 + math.sin(animationValue * 2 * math.pi) * 2,
                    ),
                    spreadRadius: 2,
                  ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8 + (_animationLevel * 3.0)),
        child: _animationLevel >= 3
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(
                    sigmaX: 1.0 * intensity, sigmaY: 1.0 * intensity),
                child: _buildCardContent(
                    index, cityName, animationValue, intensity),
              )
            : _buildCardContent(index, cityName, animationValue, intensity),
      ),
    );
  }

  Widget _buildCardContent(
      int index, String cityName, double animationValue, double intensity) {
    return Container(
      decoration: BoxDecoration(
        gradient: _animationLevel >= 2
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getGradientColor(index, 0.2 + (0.2 * intensity)),
                  _getGradientColor(index + 1, 0.1 + (0.2 * intensity)),
                  if (_animationLevel >= 4)
                    _getGradientColor(index + 2, 0.1 + (0.1 * intensity)),
                ],
                stops: _animationLevel >= 4
                    ? [
                        0.0,
                        0.5 + math.sin(animationValue * 2 * math.pi) * 0.2,
                        1.0,
                      ]
                    : [0.0, 1.0],
              )
            : null,
        color: _animationLevel < 2 ? Colors.white : null,
        border: _animationLevel >= 3
            ? Border.all(
                color: Colors.white.withOpacity(0.2 +
                    math.sin(animationValue * 4 * math.pi) * (0.1 * intensity)),
                width: 1 + (_animationLevel * 0.2),
              )
            : null,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16 + (_animationLevel * 2.0),
            vertical: 8 + (_animationLevel * 1.0)),
        leading: _buildAnimatedAvatar(index, animationValue, intensity),
        title: _animationLevel >= 5
            ? _buildGlitchText(cityName, animationValue)
            : _buildRegularText(cityName, animationValue, intensity),
        trailing: _animationLevel >= 3
            ? _buildAnimatedTrailing(index, animationValue, intensity)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showCityDetails(cityName);
          if (_animationLevel >= 4) {
            // Trigger explosion for high levels
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final position = box.localToGlobal(Offset.zero);
              _triggerExplosion(position.dx + 200, position.dy + 60);
            }
          }
        },
      ),
    );
  }

  Widget _buildSimpleCard(int index, String cityName) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getGradientColor(index, 1.0),
          child:
              Text('${index + 1}', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(cityName),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showCityDetails(cityName),
      ),
    );
  }

  Widget _buildAnimatedAvatar(
      int index, double animationValue, double intensity) {
    if (_animationLevel == 1) {
      return CircleAvatar(
        backgroundColor: _getGradientColor(index, 1.0),
        child: Text(
          '${index + 1}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Hero(
      tag: 'avatar_$index',
      child: Container(
        width: 50 + (_animationLevel * 2.0),
        height: 50 + (_animationLevel * 2.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _animationLevel >= 2
              ? RadialGradient(
                  colors: [
                    _getGradientColor(index, 1.0),
                    _getGradientColor(index + 2, 0.8),
                    if (_animationLevel >= 4) _getGradientColor(index + 4, 0.6),
                  ],
                  stops: _animationLevel >= 4
                      ? [
                          0.0,
                          (0.4 + math.sin(animationValue * 3 * math.pi) * 0.3)
                              .clamp(0.1, 0.7),
                          1.0,
                        ]
                      : [0.0, 1.0],
                )
              : null,
          color: _animationLevel < 2 ? _getGradientColor(index, 1.0) : null,
          boxShadow: _animationLevel >= 3
              ? [
                  BoxShadow(
                    color: _getGradientColor(index, 0.6 * intensity),
                    blurRadius: 8 + math.sin(animationValue * 4 * math.pi) * 4,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: _animationLevel >= 4
              ? Transform.rotate(
                  angle: animationValue * 2 * math.pi +
                      math.sin(animationValue * 6 * math.pi),
                  child: Transform.scale(
                    scale: 1.0 + math.sin(animationValue * 8 * math.pi) * 0.1,
                    child: _buildAvatarText(index, animationValue, intensity),
                  ),
                )
              : _buildAvatarText(index, animationValue, intensity),
        ),
      ),
    );
  }

  Widget _buildAvatarText(int index, double animationValue, double intensity) {
    return Text(
      '${index + 1}',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14 +
            (_animationLevel * 0.8) +
            (_animationLevel >= 4
                ? math.sin(animationValue * 5 * math.pi) * 2
                : 0),
        shadows: _animationLevel >= 3
            ? [
                Shadow(
                  blurRadius: 5,
                  color: _getGradientColor(index, 0.8 * intensity),
                  offset: const Offset(1, 1),
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildRegularText(
      String text, double animationValue, double intensity) {
    return ShaderMask(
      shaderCallback: _animationLevel >= 3
          ? (bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [Colors.white, Colors.cyan, Colors.white],
                stops: [
                  (_animationController.value - 0.3).clamp(0.0, 1.0),
                  _animationController.value,
                  (_animationController.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            }
          : (bounds) =>
              const LinearGradient(colors: [Colors.black, Colors.black])
                  .createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16 + (_animationLevel * 0.4),
          fontWeight: FontWeight.w500,
          color: _animationLevel >= 3 ? Colors.white : Colors.black87,
          shadows: _animationLevel >= 4
              ? [
                  Shadow(
                    blurRadius: 3,
                    color: Colors.cyan.withOpacity(0.5 * intensity),
                    offset: const Offset(0.5, 0.5),
                  ),
                ]
              : [],
        ),
      ),
    );
  }

  Widget _buildAnimatedTrailing(
      int index, double animationValue, double intensity) {
    if (_animationLevel >= 5 && _waterShader != null) {
      return _buildExplosiveWaterButton(index);
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 +
              math.sin(_animationController.value * 6 * math.pi) *
                  (0.05 * intensity),
          child: Container(
            width: 40 + (_animationLevel * 4.0),
            height: 30 + (_animationLevel * 2.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [
                  _getGradientColor(index, 0.8 * intensity),
                  _getGradientColor(index + 1, 0.6 * intensity),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getGradientColor(index, 0.4 * intensity),
                  blurRadius: 4 + (_animationLevel * 1.0),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: _animationLevel >= 4
                    ? _animationController.value * 2 * math.pi
                    : 0,
                child: Icon(
                  _animationLevel >= 4
                      ? Icons.auto_awesome
                      : Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16 + (_animationLevel * 1.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlitchText(String text, double animationValue) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Create glitch effect
        final glitchOffset = math.sin(animationValue * 20 * math.pi) * 2;
        return Stack(
          children: [
            // Red channel
            Transform.translate(
              offset: Offset(glitchOffset, 0),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [Colors.red, Colors.red.withOpacity(0.5)],
                  ).createShader(bounds);
                },
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18 + math.sin(animationValue * 10 * math.pi) * 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Green channel
            Transform.translate(
              offset: Offset(-glitchOffset * 0.5, glitchOffset * 0.3),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [Colors.green, Colors.green.withOpacity(0.5)],
                  ).createShader(bounds);
                },
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18 + math.sin(animationValue * 10 * math.pi) * 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Main text
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Colors.white,
                    Colors.cyan,
                    Colors.white,
                  ],
                  stops: [
                    (_animationController.value - 0.3).clamp(0.0, 1.0),
                    _animationController.value,
                    (_animationController.value + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 18 + math.sin(animationValue * 10 * math.pi) * 2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 5,
                      color: Colors.cyan.withOpacity(0.8),
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExplosiveWaterButton(int index) {
    if (_waterShader == null) {
      return _buildExplosiveFallbackButton(index);
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            _triggerRippleEffect(index);
            // Trigger explosion at button location
            _triggerExplosion(
              300 + math.Random().nextDouble() * 100,
              200 + math.Random().nextDouble() * 400,
            );
          },
          child: Transform.scale(
            scale:
                1.0 + math.sin(_animationController.value * 8 * math.pi) * 0.1,
            child: Container(
              width: 50,
              height: 35,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: WaterShaderPainter(
                    shader: _waterShader!,
                    time: _animationController.value,
                    index: index,
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: _animationController.value * 4 * math.pi,
                      child: const Icon(
                        Icons.waves,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExplosiveFallbackButton(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + math.sin(_animationController.value * 8 * math.pi) * 0.1,
          child: Container(
            width: 50,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.9),
                  Colors.cyan.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getGradientColor(int index, double opacity) {
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length].withOpacity(opacity);
  }

  void _triggerRippleEffect(int index) {
    // Trigger haptic feedback
    HapticFeedback.lightImpact();

    // Show ripple animation
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => const RippleEffect(),
    );
  }

  void _showCityDetails(String cityName) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.9),
              Colors.purple.withOpacity(0.7),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cityName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This is a demonstration of Flutter\'s powerful rendering capabilities with smooth animations and shader effects.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaterShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final int index;

  WaterShaderPainter({
    required this.shader,
    required this.time,
    required this.index,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time * 2.0 + index * 0.5);
    shader.setFloat(3, 0.1 + math.sin(time * math.pi) * 0.05);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FlameShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  FlameShaderPainter({
    required this.shader,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time * 5.0); // Speed up the flame animation

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SkyShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  SkyShaderPainter({
    required this.shader,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time * 2.0); // Slower animation for sky

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ParticleSystemPainter extends CustomPainter {
  final List<Particle> particles;

  ParticleSystemPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.life)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * particle.life,
        paint,
      );

      // Add glow effect
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(particle.life * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * particle.life * 2,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ExplosionPainter extends CustomPainter {
  final Explosion explosion;
  final double progress;

  ExplosionPainter({required this.explosion, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = explosion.maxRadius * progress;
    final opacity = (1.0 - progress) * 0.8;

    // Multiple rings for explosion effect
    for (int i = 0; i < 5; i++) {
      final ringRadius = radius * (1.0 - i * 0.2);
      final ringOpacity = opacity * (1.0 - i * 0.2);

      final paint = Paint()
        ..color = explosion.color.withOpacity(ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 * (1.0 - i * 0.15);

      canvas.drawCircle(
        Offset(explosion.x, explosion.y),
        ringRadius,
        paint,
      );
    }

    // Inner bright core
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(explosion.x, explosion.y),
      radius * 0.3,
      corePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MatrixRainPainter extends CustomPainter {
  final double time;

  MatrixRainPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Create matrix-like falling characters
    for (int x = 0; x < size.width; x += 20) {
      for (int y = 0; y < size.height + 100; y += 15) {
        final offset = ((time * 200 + x * 0.1) % (size.height + 100));
        final charY = y - offset;

        if (charY > -20 && charY < size.height + 20) {
          final opacity = (1.0 - (charY / size.height).clamp(0.0, 1.0)) * 0.2;
          paint.color = Colors.green.withOpacity(opacity);

          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), charY, 2, 10),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  double x, y, dx, dy, size, life;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.color,
    required this.size,
    required this.life,
  });

  void update() {
    x += dx;
    y += dy;
    life -= 0.01;
    dy += 0.1; // Gravity
    dx *= 0.99; // Air resistance
  }
}

class Explosion {
  double x, y, maxRadius;
  Color color;

  Explosion({
    required this.x,
    required this.y,
    required this.maxRadius,
    required this.color,
  });
}

class RippleEffect extends StatefulWidget {
  const RippleEffect({super.key});

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _controller.forward().then((_) => Navigator.pop(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 200 * _controller.value,
            height: 200 * _controller.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue.withOpacity(1 - _controller.value),
                width: 3,
              ),
            ),
          ),
        );
      },
    );
  }
}
