import 'dart:convert';

class GameState {
  List<List<String?>> board;
  String? currentTurn;
  String? winnerId;
  List<List<int>>? winningPattern;
  bool isDraw;
  int moveCount;

  GameState({
    List<List<String?>>? board,
    this.currentTurn,
    this.winnerId,
    this.winningPattern,
    this.isDraw = false,
    this.moveCount = 0,
  }) : board = board ?? _createEmptyBoard();

  static List<List<String?>> _createEmptyBoard() {
    return List.generate(6, (_) => List.generate(7, (_) => null));
  }

  Map<String, dynamic> toJson() => {
        'board': board.map((row) => row.map((cell) => cell).toList()).toList(),
        'currentTurn': currentTurn,
        'winnerId': winnerId,
        'winningPattern': winningPattern,
        'isDraw': isDraw,
        'moveCount': moveCount,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final boardData = json['board'] as List<dynamic>?;
    List<List<String?>> board;
    if (boardData != null) {
      board = boardData
          .map((row) =>
              (row as List<dynamic>).map((cell) => cell as String?).toList())
          .toList();
    } else {
      board = _createEmptyBoard();
    }

    return GameState(
      board: board,
      currentTurn: json['currentTurn'] as String?,
      winnerId: json['winnerId'] as String?,
      winningPattern: (json['winningPattern'] as List<dynamic>?)
          ?.map((p) => (p as List<dynamic>).map((e) => e as int).toList())
          .toList(),
      isDraw: json['isDraw'] as bool? ?? false,
      moveCount: json['moveCount'] as int? ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());

  static GameState decode(String source) =>
      GameState.fromJson(jsonDecode(source) as Map<String, dynamic>);

  GameState copyWith({
    List<List<String?>>? board,
    String? currentTurn,
    String? winnerId,
    List<List<int>>? winningPattern,
    bool? isDraw,
    int? moveCount,
  }) =>
      GameState(
        board:
            board ?? this.board.map((row) => List<String?>.from(row)).toList(),
        currentTurn: currentTurn ?? this.currentTurn,
        winnerId: winnerId ?? this.winnerId,
        winningPattern: winningPattern ?? this.winningPattern,
        isDraw: isDraw ?? this.isDraw,
        moveCount: moveCount ?? this.moveCount,
      );

  void reset() {
    board = _createEmptyBoard();
    currentTurn = null;
    winnerId = null;
    winningPattern = null;
    isDraw = false;
    moveCount = 0;
  }
}
