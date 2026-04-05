class GameLogic {
  static const int rows = 6;
  static const int cols = 7;
  static const int winLength = 4;

  static List<List<int>>? checkWinner(
    List<List<String?>> board,
    int row,
    int col,
    String symbol,
  ) {
    final directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (var dir in directions) {
      final pattern = _checkDirection(board, row, col, dir[0], dir[1], symbol);
      if (pattern != null) return pattern;
    }
    return null;
  }

  static List<List<int>>? _checkDirection(
    List<List<String?>> board,
    int row,
    int col,
    int dRow,
    int dCol,
    String symbol,
  ) {
    List<List<int>> pattern = [
      [row, col]
    ];

    for (int i = 1; i < winLength; i++) {
      int newRow = row + (dRow * i);
      int newCol = col + (dCol * i);
      if (_isValidCell(newRow, newCol) && board[newRow][newCol] == symbol) {
        pattern.add([newRow, newCol]);
      } else {
        break;
      }
    }

    for (int i = 1; i < winLength; i++) {
      int newRow = row - (dRow * i);
      int newCol = col - (dCol * i);
      if (_isValidCell(newRow, newCol) && board[newRow][newCol] == symbol) {
        pattern.insert(0, [newRow, newCol]);
      } else {
        break;
      }
    }

    if (pattern.length >= winLength) {
      return pattern;
    }
    return null;
  }

  static bool _isValidCell(int row, int col) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
  }

  static int? getLowestEmptyRow(List<List<String?>> board, int col) {
    for (int row = rows - 1; row >= 0; row--) {
      if (board[row][col] == null) {
        return row;
      }
    }
    return null;
  }

  static bool isValidMove(List<List<String?>> board, int col) {
    return col >= 0 && col < cols && board[0][col] == null;
  }

  static bool isBoardFull(List<List<String?>> board) {
    return board[0].every((cell) => cell != null);
  }

  static bool makeMove(
    List<List<String?>> board,
    int col,
    String symbol,
  ) {
    final row = getLowestEmptyRow(board, col);
    if (row == null) return false;

    board[row][col] = symbol;
    return true;
  }
}
