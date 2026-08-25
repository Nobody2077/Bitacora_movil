import 'dart:async';

import 'package:bitacora_rpg_personal/features/access/domain/access_clock.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_store.dart';
import 'package:bitacora_rpg_personal/features/access/domain/random_byte_source.dart';

final class DeterministicRandomByteSource implements RandomByteSource {
  DeterministicRandomByteSource([this._next = 0]);

  int _next;

  @override
  List<int> nextBytes(int length) => List<int>.generate(length, (_) {
    final value = _next & 0xff;
    _next += 1;
    return value;
  }, growable: false);
}

final class FakeAccessClock implements AccessClock {
  FakeAccessClock(this.now);

  int now;

  @override
  int nowEpochMillis() => now;
}

final class MemoryAccessCredentialStore implements AccessCredentialStore {
  MemoryAccessCredentialStore([this.record]);

  AccessCredentialRecord? record;
  final List<AccessCredentialRecord> writes = <AccessCredentialRecord>[];
  Completer<void>? nextWriteBarrier;
  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<AccessCredentialRecord?> read() async => record;

  @override
  Future<void> write(AccessCredentialRecord value) async {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    final barrier = nextWriteBarrier;
    if (barrier != null) {
      await barrier.future;
      nextWriteBarrier = null;
    }
    record = value;
    writes.add(value);
  }
}
