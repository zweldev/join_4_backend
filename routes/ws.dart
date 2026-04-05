import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../lib/services/room_service.dart';

final Map<String, WebSocketChannel> _playerChannels = {};
final Map<String, List<String>> _roomPlayers = {};

void broadcastToRoom(String roomId, Map<String, dynamic> message,
    {String? excludePlayerId}) {
  final players = _roomPlayers[roomId] ?? [];
  final messageStr = jsonEncode(message);

  for (final playerId in players) {
    if (excludePlayerId != null && playerId == excludePlayerId) continue;

    final channel = _playerChannels[playerId];
    if (channel != null) {
      try {
        channel.sink.add(messageStr);
      } catch (_) {}
    }
  }
}

Handler get onRequest {
  return webSocketHandler(
    (channel, protocol) {
      String? playerId;
      String? roomId;
      final roomService = RoomService();
      roomService.setBroadcastFunction(broadcastToRoom);

      channel.stream.listen(
        (data) async {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            final event = message['event'] as String?;

            switch (event) {
              case 'create_room':
                {
                  final result = roomService
                      .createRoom(message['name'] as String? ?? 'Player');
                  playerId = result['player']['id'] as String;
                  roomId = result['roomId'] as String;

                  _playerChannels[playerId!] = channel;
                  _roomPlayers.putIfAbsent(roomId!, () => []).add(playerId!);

                  channel.sink.add(jsonEncode(result));
                  break;
                }

              case 'join_room':
                {
                  final joinRoomId = message['roomId'] as String? ?? '';
                  final name = message['name'] as String? ?? 'Player';

                  final result = roomService.joinRoom(joinRoomId, name);
                  if (result != null && result['event'] == 'player_joined') {
                    playerId = result['player']['id'] as String;
                    roomId = joinRoomId;

                    _playerChannels[playerId!] = channel;
                    _roomPlayers.putIfAbsent(roomId!, () => []).add(playerId!);

                    channel.sink.add(jsonEncode(result));
                    broadcastToRoom(
                        roomId!,
                        {
                          'event': 'opponent_joined',
                          'player': result['player'],
                          'players': result['players'],
                        },
                        excludePlayerId: playerId);
                  } else {
                    channel.sink.add(jsonEncode(result ??
                        {'event': 'error', 'message': 'Failed to join room'}));
                  }
                  break;
                }

              case 'player_ready':
              case 'make_move':
              case 'restart_game':
              case 'reconnect':
                {
                  if (playerId == null || roomId == null) {
                    channel.sink.add(jsonEncode(
                        {'event': 'error', 'message': 'Not in a room'}));
                    break;
                  }
                  final newMessage = Map<String, dynamic>.from(message);
                  newMessage['roomId'] = roomId;
                  newMessage['playerId'] = playerId;

                  final result = roomService.processEvent(newMessage);
                  if (result != null) {
                    channel.sink.add(jsonEncode(result));
                    broadcastToRoom(roomId!, result, excludePlayerId: playerId);
                  }
                  break;
                }

              case 'leave_room':
                {
                  if (playerId == null || roomId == null) break;

                  final newMessage = <String, dynamic>{
                    'event': 'leave_room',
                    'roomId': roomId,
                    'playerId': playerId,
                  };
                  final result = roomService.processEvent(newMessage);

                  if (result != null && result['event'] == 'player_left') {
                    channel.sink.add(jsonEncode(result));
                    broadcastToRoom(roomId!, result, excludePlayerId: playerId);
                  }

                  _roomPlayers[roomId!]?.remove(playerId);
                  _playerChannels.remove(playerId);
                  playerId = null;
                  roomId = null;
                  break;
                }

              case 'disconnect':
                {
                  final disconnectRoomId = message['roomId'] as String?;
                  final disconnectPlayerId = message['playerId'] as String?;
                  if (disconnectRoomId != null && disconnectPlayerId != null) {
                    roomService.startDisconnectTimer(
                        disconnectRoomId, disconnectPlayerId);
                  }
                  break;
                }

              default:
                channel.sink.add(
                    jsonEncode({'event': 'error', 'message': 'Unknown event'}));
            }
          } catch (e) {
            channel.sink.add(jsonEncode(
                {'event': 'error', 'message': 'Invalid message format'}));
          }
        },
        onError: (error) {
          if (playerId != null && roomId != null) {
            _handleDisconnect(playerId!, roomId!);
          }
        },
        onDone: () {
          if (playerId != null && roomId != null) {
            _handleDisconnect(playerId!, roomId!);
          }
        },
      );
    },
  );
}

void _handleDisconnect(String playerId, String roomId) {
  _roomPlayers[roomId]?.remove(playerId);
  _playerChannels.remove(playerId);

  final roomService = RoomService();
  roomService.startDisconnectTimer(roomId, playerId);
}
