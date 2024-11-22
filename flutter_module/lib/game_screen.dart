import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_module/action_button.dart';
import 'package:flutter_module/rain_particle.dart';
import 'package:flutter_module/sprite_sheet.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late RainEffect game;

  @override
  void initState() {
    super.initState();
    game = RainEffect();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text("Flame with game"),
          ),
          body: Column(
            children: [
              Expanded(
                  child: GameWidget<RainEffect>(game: game, overlayBuilderMap: {
                'userArea': (ctx, game) {
                  return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 80),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Username')),
                            TextField(
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Password'))
                          ]));
                },
                'container1': (ctx, game) {
                  return ActionButtonWidget(
                      Colors.blueAccent, "Sign in", Alignment.bottomCenter, () {
                    print(
                        "=== This is Flutter widget inside Flutter Flame ===");
                  });
                },
              }, initialActiveOverlays: const [
                'userArea',
                'container1'
              ])),
            ],
          ),
        ),
        SizedBox(
            width: 100,
            height: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                  alignment: Alignment.topCenter,
                  child: GameWidget(game: SpriteSheetWidget())),
            )),
      ],
    );
  }
}
