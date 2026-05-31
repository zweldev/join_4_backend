import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../utils/game_logic.dart';

typedef BroadcastFunction = void Function(
    String roomId, Map<String, dynamic> message);

class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  final Map<String, Room> _rooms = {};
  BroadcastFunction? _broadcast;
  final _uuid = const Uuid();

  static const Duration disconnectTimeout = Duration(seconds: 30);

  void setBroadcastFunction(BroadcastFunction fn) {
    _broadcast = fn;
  }

  String generateRoomId() {
    String id;
    do {
      id = _uuid.v4().substring(0, 8).toUpperCase();
    } while (_rooms.containsKey(id));
    return id;
  }

  String generatePlayerId() {
    return _uuid.v4();
  }

  Map<String, dynamic> createRoom(String playerName) {
    final roomId = generateRoomId();
    final playerId = generatePlayerId();

    final player = Player(
      id: playerId,
      name: playerName,
      symbol: 'X',
      lastActivity: DateTime.now(),
    );

    final room = Room(id: roomId, players: [player]);
    _rooms[roomId] = room;

    return {
      'event': 'room_created',
      'roomId': roomId,
      'player': player.toJson(),
    };
  }

  Map<String, dynamic>? joinRoom(String roomId, String playerName) {
    final room = _rooms[roomId];
    if (room == null) {
      return {'event': 'error', 'message': 'Room not found'};
    }

    if (room.isFull) {
      return {'event': 'error', 'message': 'Room is full'};
    }

    final playerId = generatePlayerId();
    final player = Player(
      id: playerId,
      name: playerName,
      symbol: 'O',
      lastActivity: DateTime.now(),
    );

    room.players.add(player);
    room.status = RoomStatus.ready;

    return {
      'event': 'player_joined',
      'roomId': roomId,
      'player': player.toJson(),
      'players': room.players.map((p) => p.toJson()).toList(),
    };
  }

  Map<String, dynamic>? handlePlayerReady(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) {
      return {'event': 'error', 'message': 'Room not found'};
    }

    final player = room.getPlayerById(playerId);
    if (player == null) {
      return {'event': 'error', 'message': 'Player not found'};
    }

    player.isReady = true;
    player.lastActivity = DateTime.now();

    if (room.canStart) {
      room.status = RoomStatus.playing;
      room.gameState.currentTurn = room.playerX?.id;

      return {
        'event': 'game_started',
        'roomId': roomId,
        'board': room.gameState.board,
        'currentTurn': room.gameState.currentTurn,
        'players': room.players.map((p) => p.toJson()).toList(),
      };
    }

    return {
      'event': 'player_ready',
      'roomId': roomId,
      'playerId': playerId,
      'players': room.players.map((p) => p.toJson()).toList(),
    };
  }

  Map<String, dynamic>? handleMakeMove(
      String roomId, String playerId, int col) {
    final room = _rooms[roomId];
    if (room == null) {
      return {'event': 'error', 'message': 'Room not found'};
    }

    if (room.status != RoomStatus.playing) {
      return {'event': 'error', 'message': 'Game not in progress'};
    }

    final player = room.getPlayerById(playerId);
    if (player == null) {
      return {'event': 'error', 'message': 'Player not found'};
    }

    if (room.gameState.currentTurn != playerId) {
      return {'event': 'error', 'message': 'Not your turn'};
    }

    if (!GameLogic.isValidMove(room.gameState.board, col)) {
      return {'event': 'error', 'message': 'Invalid move'};
    }

    final row = GameLogic.getLowestEmptyRow(room.gameState.board, col)!;
    GameLogic.makeMove(room.gameState.board, col, player.symbol);
    room.gameState.moveCount++;
    player.lastActivity = DateTime.now();

    final winnerPattern = GameLogic.checkWinner(
      room.gameState.board,
      row,
      col,
      player.symbol,
    );

    if (winnerPattern != null) {
      room.status = RoomStatus.finished;
      room.gameState.winnerId = playerId;
      room.gameState.winningPattern = winnerPattern;
      player.score++;

      return {
        'event': 'game_over',
        'roomId': roomId,
        'winnerId': playerId,
        'winnerName': player.name,
        'winningPattern': winnerPattern,
        'board': room.gameState.board,
        'scores': {
          room.playerX!.id: room.playerX!.score,
          room.playerO!.id: room.playerO!.score,
        },
      };
    }

    if (GameLogic.isBoardFull(room.gameState.board)) {
      room.status = RoomStatus.finished;
      room.gameState.isDraw = true;

      return {
        'event': 'game_over',
        'roomId': roomId,
        'isDraw': true,
        'board': room.gameState.board,
        'scores': {
          room.playerX!.id: room.playerX!.score,
          room.playerO!.id: room.playerO!.score,
        },
      };
    }

    final opponent = room.opponentOf(playerId);
    room.gameState.currentTurn = opponent?.id;

    return {
      'event': 'move_made',
      'roomId': roomId,
      'playerId': playerId,
      'column': col,
      'row': row,
      'board': room.gameState.board,
      'currentTurn': room.gameState.currentTurn,
    };
  }

  Map<String, dynamic>? handleRestartGame(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) {
      return {'event': 'error', 'message': 'Room not found'};
    }

    final player = room.getPlayerById(playerId);
    if (player == null) {
      return {'event': 'error', 'message': 'Player not found'};
    }

    room.resetForNewGame();

    return {
      'event': 'game_restarted',
      'roomId': roomId,
      'board': room.gameState.board,
      'players': room.players.map((p) => p.toJson()).toList(),
    };
  }

  Map<String, dynamic>? handleLeaveRoom(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) return null;

    room.players.removeWhere((p) => p.id == playerId);

    if (room.players.isEmpty) {
      room.dispose();
      _rooms.remove(roomId);
      return {'event': 'room_closed', 'roomId': roomId};
    }

    room.status = RoomStatus.waiting;
    room.gameState.reset();

    return {
      'event': 'player_left',
      'roomId': roomId,
      'remainingPlayer': room.players.first.toJson(),
    };
  }

  void startDisconnectTimer(String roomId, String disconnectedPlayerId) {
    final room = _rooms[roomId];
    if (room == null) return;

    room.disconnectTimer?.cancel();
    room.disconnectTimer = Timer(disconnectTimeout, () {
      final remainingPlayer = room.opponentOf(disconnectedPlayerId);
      if (remainingPlayer != null) {
        remainingPlayer.score += 2;
        _broadcast?.call(roomId, {
          'event': 'game_over',
          'roomId': roomId,
          'winnerId': remainingPlayer.id,
          'winnerName': remainingPlayer.name,
          'reason': 'opponent_disconnected',
          'scores': {
            room.playerX!.id: room.playerX!.score,
            room.playerO!.id: room.playerO!.score,
          },
        });
      }

      room.dispose();
      _rooms.remove(roomId);
    });
  }

  void cancelDisconnectTimer(String roomId) {
    final room = _rooms[roomId];
    room?.disconnectTimer?.cancel();
  }

  Map<String, dynamic>? handleReconnect(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) {
      return {'event': 'error', 'message': 'Room not found'};
    }

    final player = room.getPlayerById(playerId);
    if (player == null) {
      return {'event': 'error', 'message': 'Player not found in room'};
    }

    cancelDisconnectTimer(roomId);

    return {
      'event': 'reconnected',
      'roomId': roomId,
      'room': room.toJson(),
    };
  }

  Room? getRoom(String roomId) => _rooms[roomId];

  Map<String, dynamic>? processEvent(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    if (event == null) {
      return {'event': 'error', 'message': 'No event specified'};
    }

    switch (event) {
      case 'create_room':
        return createRoom(data['name'] as String? ?? 'Player');

      case 'join_room':
        return joinRoom(
          data['roomId'] as String? ?? '',
          data['name'] as String? ?? 'Player',
        );

      case 'player_ready':
        return handlePlayerReady(
          data['roomId'] as String? ?? '',
          data['playerId'] as String? ?? '',
        );

      case 'make_move':
        return handleMakeMove(
          data['roomId'] as String? ?? '',
          data['playerId'] as String? ?? '',
          data['column'] as int? ?? 0,
        );

      case 'restart_game':
        return handleRestartGame(
          data['roomId'] as String? ?? '',
          data['playerId'] as String? ?? '',
        );

      case 'leave_room':
        return handleLeaveRoom(
          data['roomId'] as String? ?? '',
          data['playerId'] as String? ?? '',
        );

      case 'reconnect':
        return handleReconnect(
          data['roomId'] as String? ?? '',
          data['playerId'] as String? ?? '',
        );

      default:
        return {'event': 'error', 'message': 'Unknown event: $event'};
    }
  }
}
