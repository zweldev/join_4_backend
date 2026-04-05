import 'dart:async';
import 'player.dart';
import 'game_state.dart';

enum RoomStatus { waiting, ready, playing, finished }

class Room {
  final String id;
  final List<Player> players;
  GameState gameState;
  RoomStatus status;
  Timer? disconnectTimer;
  DateTime createdAt;

  Room({
    required this.id,
    List<Player>? players,
    GameState? gameState,
    this.status = RoomStatus.waiting,
    DateTime? createdAt,
  })  : players = players ?? [],
        gameState = gameState ?? GameState(),
        createdAt = createdAt ?? DateTime.now();

  bool get isFull => players.length >= 2;
  bool get canStart => players.length == 2 && players.every((p) => p.isReady);

  Player? get playerX => players.isNotEmpty ? players[0] : null;
  Player? get playerO => players.length > 1 ? players[1] : null;

  Player? getPlayerById(String id) {
    try {
      return players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Player? opponentOf(String playerId) {
    return players.where((p) => p.id != playerId).firstOrNull;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'players': players.map((p) => p.toJson()).toList(),
        'gameState': gameState.toJson(),
        'status': status.name,
      };

  void resetForNewGame() {
    gameState.reset();
    status = RoomStatus.ready;
    for (var player in players) {
      player.isReady = false;
    }
  }

  void dispose() {
    disconnectTimer?.cancel();
  }
}
