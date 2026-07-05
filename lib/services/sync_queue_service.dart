import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipos de operações que podem ser enfileiradas para retry offline.
enum SyncOpType { syncWorkoutLog, deleteWorkoutLog, syncRoutine, deleteRoutine }

/// Uma operação pendente de sincronização com o Firebase.
class SyncOp {
  final SyncOpType type;
  final String userId;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;

  const SyncOp({
    required this.type,
    required this.userId,
    required this.payload,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'userId': userId,
        'payload': payload,
        'enqueuedAt': enqueuedAt.toUtc().toIso8601String(),
      };

  factory SyncOp.fromJson(Map<String, dynamic> json) => SyncOp(
        type: SyncOpType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => SyncOpType.syncWorkoutLog,
        ),
        userId: json['userId'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      );
}

/// Fila persistente de operações de sincronização para suporte offline.
///
/// Quando o Firebase falha (sem rede), as operações são salvas localmente em
/// SharedPreferences. Quando a conectividade retorna e [drain] é chamado,
/// as operações pendentes são reenviadas ao Firebase em ordem FIFO.
class SyncQueueService {
  static const _prefsKey = 'los_mooscles_sync_queue';
  static const _maxQueueSize = 500; // Limite de segurança

  Future<List<SyncOp>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => SyncOp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SyncQueue] Load error: $e');
      return [];
    }
  }

  Future<void> _save(List<SyncOp> ops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(ops.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[SyncQueue] Save error: $e');
    }
  }

  /// Enfileira uma nova operação para retry. Operações duplicadas (mesmo type +
  /// mesmo id no payload) são deduplicadas — a mais recente substitui a anterior.
  Future<void> enqueue(SyncOp op) async {
    final ops = await _load();

    // Deduplicar: remover operação anterior do mesmo tipo + id
    final idField = _idFieldFor(op.type);
    if (idField != null && op.payload.containsKey(idField)) {
      final id = op.payload[idField];
      ops.removeWhere((o) => o.type == op.type && o.userId == op.userId && o.payload[idField] == id);
    }

    ops.add(op);

    // Limitar tamanho máximo — descarta as mais antigas
    if (ops.length > _maxQueueSize) {
      ops.removeRange(0, ops.length - _maxQueueSize);
    }

    await _save(ops);
    debugPrint('[SyncQueue] Enqueued ${op.type.name} for user ${op.userId}. Queue size: ${ops.length}');
  }

  /// Retorna todas as operações pendentes para o usuário especificado.
  Future<List<SyncOp>> pendingFor(String userId) async {
    final ops = await _load();
    return ops.where((o) => o.userId == userId).toList();
  }

  /// Remove operações específicas (após execução bem-sucedida).
  Future<void> removeCompleted(List<SyncOp> completed) async {
    if (completed.isEmpty) return;
    final ops = await _load();
    // Remover por enqueuedAt como chave de identificação única
    final completedKeys = completed.map((o) => '${o.type.name}|${o.userId}|${o.enqueuedAt.toIso8601String()}').toSet();
    ops.removeWhere((o) => completedKeys.contains('${o.type.name}|${o.userId}|${o.enqueuedAt.toIso8601String()}'));
    await _save(ops);
  }

  /// Limpa toda a fila para um usuário (ex: logout).
  Future<void> clearFor(String userId) async {
    final ops = await _load();
    ops.removeWhere((o) => o.userId == userId);
    await _save(ops);
  }

  /// Retorna o total de operações pendentes na fila.
  Future<int> get queueSize async => (await _load()).length;

  String? _idFieldFor(SyncOpType type) {
    switch (type) {
      case SyncOpType.syncWorkoutLog:
      case SyncOpType.deleteWorkoutLog:
        return 'id';
      case SyncOpType.syncRoutine:
      case SyncOpType.deleteRoutine:
        return 'id';
    }
  }
}
