import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/management_proposal_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';
import 'package:mcp_field/core/sync/management_proposal_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';

http.Response jsonResponse(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

class MemoryMutationQueueStore implements MutationQueueStore {
  final Map<String, QueuedMutation> items = {};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = items.values.toList(growable: false);
    if (operations == null || operations.isEmpty) return values;
    return values
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    items.remove(idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    items[mutation.idempotencyKey] = mutation;
  }
}

class RetryProposalClient implements ManagementProposalClient {
  bool offline = true;
  final keys = <String>[];

  @override
  Future<List<ManagementProposal>> load() async => const [];

  @override
  Future<ManagementProposal> create({
    required ManagementProposalDraft draft,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (offline) {
      throw const ManagementProposalFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng tạm thời gián đoạn.',
        retryable: true,
      );
    }
    return ManagementProposal(
      id: 'proposal-1',
      title: draft.title,
      content: draft.content,
      entityType: draft.entityType,
      entityId: draft.entityId,
      entityLabel: draft.entityLabel,
      impact: draft.impact,
      reason: draft.reason,
      rule: draft.rule,
      evidence: draft.evidence,
      priority: draft.priority,
      status: 'pending',
      requesterName: 'Nhân viên A',
      createdAt: '2026-09-28T01:00:00.000Z',
      updatedAt: '2026-09-28T01:00:00.000Z',
    );
  }

  @override
  Future<ManagementProposal> resubmit({
    required String proposalId,
    required String content,
    required String reason,
    required List<String> evidence,
    required String idempotencyKey,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  test('proposal client uses MCP source and canonical write contracts', () async {
    final seen = <String>[];
    final client = HttpManagementProposalClient(
      profile: InstallationProfile(
        name: 'Hưng Phát',
        baseUrl: Uri.parse('https://mcp.example.vn'),
      ),
      token: 'mobile-token',
      client: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer mobile-token');

        if (request.method == 'GET') {
          expect(request.url.queryParameters['source'], 'mcp');
          return jsonResponse(
            {
              'data': {
                'proposals': [
                  {
                    'id': 'proposal-1',
                    'title': 'Điều chỉnh trưng bày',
                    'content': 'Cần bổ sung vật dụng trưng bày.',
                    'entityType': 'outlet',
                    'entityId': 'rc-1',
                    'entityLabel': 'Điểm bán A',
                    'impact': 'Tăng nhận diện',
                    'reason': 'Thiếu vật dụng',
                    'rule': '',
                    'evidence': ['Ảnh quầy'],
                    'priority': 'high',
                    'status': 'pending',
                    'requesterName': 'Nhân viên A',
                    'createdAt': '2026-09-28T01:00:00.000Z',
                    'updatedAt': '2026-09-28T01:00:00.000Z',
                  },
                ],
              },
            },
            200,
          );
        }

        expect(
          request.headers['idempotency-key'],
          'mcp-management-proposal-test',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Điều chỉnh trưng bày');
        return jsonResponse(
          {
            'data': {
              'id': 'proposal-2',
              'title': body['title'],
              'content': body['content'],
              'entityType': body['entityType'],
              'entityId': '',
              'entityLabel': '',
              'impact': '',
              'reason': '',
              'rule': '',
              'evidence': [],
              'priority': 'normal',
              'status': 'pending',
              'requesterName': 'Nhân viên A',
              'createdAt': '2026-09-28T02:00:00.000Z',
              'updatedAt': '2026-09-28T02:00:00.000Z',
            },
          },
          201,
        );
      }),
    );

    final proposals = await client.load();
    expect(proposals.single.id, 'proposal-1');
    expect(proposals.single.priority, 'high');

    final created = await client.create(
      draft: const ManagementProposalDraft(
        title: 'Điều chỉnh trưng bày',
        content: 'Cần bổ sung vật dụng trưng bày.',
      ),
      idempotencyKey: 'mcp-management-proposal-test',
    );
    expect(created.id, 'proposal-2');
    expect(seen, [
      'GET /api/management-proposals',
      'POST /api/management-proposals',
    ]);
  });

  test('proposal retry survives restart and reuses the exact key', () async {
    final queue = MemoryMutationQueueStore();
    final client = RetryProposalClient();
    final submit = ManagementProposalSubmissionService(
      client: client,
      queue: queue,
    );

    final result = await submit.create(
      const ManagementProposalDraft(
        title: 'Đề xuất vật dụng',
        content: 'Bổ sung bảng trưng bày cho điểm bán.',
        entityType: 'outlet',
        entityId: 'rc-1',
        entityLabel: 'Điểm bán A',
      ),
    );

    expect(result.status, ManagementProposalSubmitStatus.queued);
    expect(client.keys, hasLength(1));
    final key = client.keys.single;
    expect(CanonicalIdempotencyKey.isValid(key), isTrue);

    client.offline = false;
    final replay = await ManagementProposalSyncService(
      client: client,
      queue: queue,
    ).syncPending();

    expect(replay.sent, 1);
    expect(replay.remaining, 0);
    expect(client.keys, [key, key]);
  });
}
