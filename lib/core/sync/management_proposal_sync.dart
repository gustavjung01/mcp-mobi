import '../data/management_proposal_client.dart';
import '../idempotency/canonical_idempotency.dart';
import 'mutation_queue.dart';

const managementProposalCreateOperation = 'mcp-management-proposal';
const managementProposalResubmitOperation = 'mcp-management-proposal-resubmit';

enum ManagementProposalSubmitStatus {
  completed,
  queued,
}

class ManagementProposalSubmitResult {
  const ManagementProposalSubmitResult({
    required this.status,
    this.proposal,
  });

  final ManagementProposalSubmitStatus status;
  final ManagementProposal? proposal;
}

class ManagementProposalSubmissionService {
  const ManagementProposalSubmissionService({
    required this.client,
    required this.queue,
  });

  final ManagementProposalClient client;
  final MutationQueueStore queue;

  Future<ManagementProposalSubmitResult> create(
    ManagementProposalDraft draft, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ??
        CanonicalIdempotencyKey.create(managementProposalCreateOperation);
    final mutation = QueuedMutation(
      idempotencyKey: key,
      operation: managementProposalCreateOperation,
      entityType: 'management_proposal',
      entityLabel: draft.title.trim(),
      payload: draft.toJson(),
      createdAt: DateTime.now().toUtc(),
    );
    await _saveInitial(mutation);

    try {
      final proposal = await client.create(
        draft: draft,
        idempotencyKey: key,
      );
      await _acknowledgeBestEffort(mutation, proposal.id);
      return ManagementProposalSubmitResult(
        status: ManagementProposalSubmitStatus.completed,
        proposal: proposal,
      );
    } on ManagementProposalFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<ManagementProposalSubmitResult> resubmit({
    required String proposalId,
    required String content,
    required String reason,
    required List<String> evidence,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ??
        CanonicalIdempotencyKey.create(managementProposalResubmitOperation);
    final mutation = QueuedMutation(
      idempotencyKey: key,
      operation: managementProposalResubmitOperation,
      entityType: 'management_proposal',
      entityLabel: 'Bổ sung Đề xuất',
      payload: {
        'proposalId': proposalId.trim(),
        'content': content.trim(),
        'reason': reason.trim(),
        'evidence': evidence,
      },
      createdAt: DateTime.now().toUtc(),
    );
    await _saveInitial(mutation);

    try {
      final proposal = await client.resubmit(
        proposalId: proposalId,
        content: content,
        reason: reason,
        evidence: evidence,
        idempotencyKey: key,
      );
      await _acknowledgeBestEffort(mutation, proposal.id);
      return ManagementProposalSubmitResult(
        status: ManagementProposalSubmitStatus.completed,
        proposal: proposal,
      );
    } on ManagementProposalFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<void> _saveInitial(QueuedMutation mutation) async {
    try {
      await queue.save(mutation);
    } catch (_) {
      throw const ManagementProposalFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không lưu được Đề xuất trên thiết bị. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _acknowledgeBestEffort(
    QueuedMutation mutation,
    String reference,
  ) async {
    try {
      await queue.save(mutation.acknowledged(reference));
    } catch (_) {
      // Máy chủ đã nhận thao tác; gửi lại cùng key vẫn an toàn.
    }
  }

  Future<ManagementProposalSubmitResult> _handleFailure(
    QueuedMutation mutation,
    ManagementProposalFailure failure,
  ) async {
    if (!failure.retryable) {
      try {
        await queue.remove(mutation.idempotencyKey);
      } catch (_) {
        // Không thay đổi quyết định từ chối của máy chủ.
      }
      throw failure;
    }

    try {
      await queue.save(
        mutation.failed(
          code: failure.code,
          message: failure.message,
          retryable: true,
        ),
      );
    } catch (_) {
      throw const ManagementProposalFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Chưa lưu được Đề xuất chờ gửi. Vui lòng thử lại.',
      );
    }
    return const ManagementProposalSubmitResult(
      status: ManagementProposalSubmitStatus.queued,
    );
  }
}

class ManagementProposalSyncResult {
  const ManagementProposalSyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int remaining;
}

class ManagementProposalSyncService {
  const ManagementProposalSyncService({
    required this.client,
    required this.queue,
  });

  final ManagementProposalClient client;
  final MutationQueueStore queue;

  static const operations = <String>{
    managementProposalCreateOperation,
    managementProposalResubmitOperation,
  };

  Future<ManagementProposalSyncResult> syncPending() async {
    final rows = await queue.load(operations: operations);
    var sent = 0;
    var failed = 0;

    for (final mutation in rows) {
      if (!mutation.isOutstanding) continue;
      if (mutation.state == MutationQueueState.failed && !mutation.retryable) {
        continue;
      }

      try {
        final reference = await _replay(mutation);
        await queue.save(mutation.acknowledged(reference));
        sent += 1;
      } on ManagementProposalFailure catch (failure) {
        await queue.save(
          mutation.failed(
            code: failure.code,
            message: failure.message,
            retryable: failure.retryable,
          ),
        );
        failed += 1;
      }
    }

    final remaining = (await queue.load(operations: operations))
        .where((item) => item.isOutstanding)
        .length;
    return ManagementProposalSyncResult(
      sent: sent,
      failed: failed,
      remaining: remaining,
    );
  }

  Future<String> _replay(QueuedMutation mutation) async {
    final payload = mutation.payload;
    switch (mutation.operation) {
      case managementProposalCreateOperation:
        final proposal = await client.create(
          draft: ManagementProposalDraft(
            title: _requiredText(payload['title']),
            content: _requiredText(payload['content']),
            entityType: _text(payload['entityType']).isEmpty
                ? 'other'
                : _text(payload['entityType']),
            entityId: _text(payload['entityId']),
            entityLabel: _text(payload['entityLabel']),
            impact: _text(payload['impact']),
            reason: _text(payload['reason']),
            rule: _text(payload['rule']),
            evidence: _strings(payload['evidence']),
            priority: _text(payload['priority']).isEmpty
                ? 'normal'
                : _text(payload['priority']),
          ),
          idempotencyKey: mutation.idempotencyKey,
        );
        return proposal.id;
      case managementProposalResubmitOperation:
        final proposal = await client.resubmit(
          proposalId: _requiredText(payload['proposalId']),
          content: _requiredText(payload['content']),
          reason: _text(payload['reason']),
          evidence: _strings(payload['evidence']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return proposal.id;
      default:
        throw const ManagementProposalFailure(
          code: 'LOCAL_QUEUE_INVALID',
          message: 'Đề xuất chờ gửi không hợp lệ.',
        );
    }
  }
}

String _text(Object? value) => (value ?? '').toString().trim();

String _requiredText(Object? value) {
  final normalized = _text(value);
  if (normalized.isEmpty) {
    throw const ManagementProposalFailure(
      code: 'LOCAL_QUEUE_INVALID',
      message: 'Đề xuất chờ gửi chưa đủ thông tin.',
    );
  }
  return normalized;
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => _text(item))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
